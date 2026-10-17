part of '../crabs.dart';

void installCrabVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _warmCrabPool,
      reads: const {},
      inSet: GameSets.keeper,
      runIf: _visual,
    )
    ..addSystem(
      Schedules.update,
      _dressCrabs,
      reads: {Crab, TarSplat, CrabModel},
      inSet: GameSets.dress,
      runIf: _visual,
    )
    ..addSystem(
      Schedules.update,
      _animateCrabs,
      writes: {Clips, CrabModel},
      reads: {
        CrabBrain,
        CrabBody,
        Crab,
        LightExposure,
        Underground,
        HitPause,
        HitFlash,
        TarShell,
        BossBrain,
        Shroud,
        Exposed,
      },
      inSet: GameSets.crabAnimation,
      runIf: _visual,
    )
    ..observe<CrabModel>(onRemove: _releaseModel);
}

/// Model parts the visuals touch, looked up once per pooled model.
const List<String> _crabParts = [
  'crab_root',
  'tar_shell',
  'glass_shell',
  'boat_shell_0',
  'boat_shell_1',
  'boat_shell_2',
];

/// Startup, visual: pre-warm every crab model with its clips and materials.
void _warmCrabPool(World world) {
  final lib = world.resource<ModelLibrary>();
  final pool = world.resource<CrabPool>();
  final materials = world.tryResource<Materials>();
  final shell = materials?['crab_shell'];
  for (final MapEntry(key: type, value: count) in crabPoolSizes.entries) {
    final asset = crabStats[type]!.asset;
    if (!lib.has(asset)) continue;
    for (var i = 0; i < count; i++) {
      final node = lib.instance(asset);
      if (shell != null) _shade(node, shell);
      if (node.getChildByName('tar_shell') case final tar?) {
        if (materials?.take('tar') case final m?) assignNode(tar, m);
      }
      if (node.getChildByName('glass_shell') case final glass?) {
        if (materials?.take('crystal') case final m?) assignNode(glass, m);
      }
      final mound = type == CrabType.burrower && lib.has('sand_mound')
          ? lib.instance('sand_mound')
          : null;
      setRenderLayer(node, RenderLayers.actors);
      if (mound != null) setRenderLayer(mound, RenderLayers.actors);
      final clips = bindClips(lib, asset, node, start: 'Idle');
      pool.give(type, node, clips, mound);
    }
  }
}

/// The shared crab shell on every rigid part but the special shells.
void _shade(Node node, Material shell) {
  if (node.mesh != null &&
      !const {'tar_shell', 'glass_shell', 'belly_glow', 'water_sac'}
          .contains(node.name)) {
    assignNode(node, shell);
  }
  for (final child in node.children) {
    _shade(child, shell);
  }
}

/// Puts a pooled model on every crab without one (and a decal on splats).
void _dressCrabs(World world) {
  final lib = world.resource<ModelLibrary>();
  final pool = world.resource<CrabPool>();
  world.query<Crab>().without<CrabModel>().each((entity, crab) {
    final taken = pool.take(crab.type);
    if (taken == null) return; // never instantiate mid-night; wait for one
    final (node, clips, mound) = taken;
    if (mound != null && mound.parent == null) node.add(mound);
    mound?.visible = false;
    final parts = {
      for (final name in _crabParts) name: ?node.getChildByName(name),
    };
    for (final part in parts.values) {
      part.visible = true;
    }
    world
      ..add(entity, NodeRef(node))
      ..add(entity, clips)
      ..add(entity, CrabModel(crab.type, node, clips, mound, parts));
  });
  world.entitiesWith<TarSplat>().without<NodeRef>().each((entity) {
    if (!lib.has('tar_splat')) return;
    final splat = lib.instance('tar_splat')
      ..shadowCastingMode = ShadowCastingMode.off;
    setRenderLayer(splat, RenderLayers.actors);
    world.add(entity, NodeRef(splat));
  });
}

/// Mode → clip, Scuttle speed-scaled and reversed for −X travel, event
/// crossings as [AnimEvent], hit pause, and the per-type touches (sand
/// mound, cracking tar shell, lost boat-shell pieces).
void _animateCrabs(World world) {
  final dt = world.delta;
  final lib = world.resource<ModelLibrary>();
  world.query4<CrabModel, CrabBrain, CrabBody, Crab>().each((
    entity,
    model,
    brain,
    body,
    crab,
  ) {
    final clips = model.clips;
    final state = brain.mode.state;
    final underground = world.has<Underground>(entity);
    final light = world.tryGet<LightExposure>(entity);
    final moving = body.velocity.length2 > 0.04;
    final scuttle = crab.type == CrabType.basher ? 'Drag' : 'Scuttle';
    final name = switch (state) {
      CrabMode.landing || CrabMode.climbing => scuttle,
      CrabMode.advancing when crab.type == CrabType.glassback &&
          (light?.beam ?? false) => 'Reflect',
      CrabMode.advancing when crab.type == CrabType.mothCrab &&
          brain.target != null => 'Flutter',
      CrabMode.advancing when body.leap > 0 => 'Attack',
      CrabMode.advancing => moving ? scuttle : 'Idle',
      CrabMode.cowering => 'Cower',
      CrabMode.attacking => 'Attack',
      CrabMode.special => brain.special,
      CrabMode.hit => 'Hit',
      CrabMode.dying => 'Death',
    };
    final info = lib.clip(model.type.asset, name);
    final oneShot = !(info?.loop ?? true);
    var speed = 1.0;
    if (name == scuttle && state != CrabMode.climbing) {
      speed = (body.velocity.length / body.speed).clamp(0.3, 2.0) *
          body.scuttleSign;
    }
    fadeTo(
      clips,
      name,
      dt,
      restart: oneShot && brain.mode.justEntered(state),
      speed: speed,
    );
    if (info?.eventAt case final at? when crossed(clips, at)) {
      world.emit(AnimEvent(entity, name, 'impact'));
    }
    // Hit pause holds the current clip; releasing it resumes playback.
    final current = clips.byName[clips.current];
    if (world.has<HitPause>(entity)) {
      current?.playing = false;
      model.paused = true;
    } else if (model.paused) {
      current?.playing = true;
      model.paused = false;
    }

    // The shroud burning (a dull ember edge) and the crab exposed (a
    // white-hot outline that shows through cover): what to shoot.
    final outline = state == CrabMode.dying
        ? 0
        : world.has<Exposed>(entity)
        ? 2
        : (world.tryGet<Shroud>(entity)?.burning ?? false)
        ? 1
        : 0;
    if (outline != model.outline) {
      model.outline = outline;
      final color = switch (outline) {
        1 => crabOutlineBurning,
        2 => crabOutlineExposed,
        _ => null,
      };
      for (final mesh in model.meshes) {
        mesh.highlightColor = color;
      }
    }

    // Burrowers show a sand mound while tunnelling.
    model.mound?.visible = underground;
    model.parts['crab_root']?.visible = !underground;

    // The tar shell glows as it cracks, and falls away once cracked.
    if (world.tryGet<TarShell>(entity) case final shell?) {
      final node = model.parts['tar_shell'];
      if (node?.mesh?.primitives.firstOrNull?.material
          case final PreprocessedMaterial m) {
        setParam(m.parameters, 'crack', shell.progress);
      }
      if (shell.cracked &&
          (state != CrabMode.special || brain.mode.elapsed > 0.5)) {
        node?.visible = false;
      }
    }

    // Glass shells flare in the beam.
    if (model.parts['glass_shell']?.mesh?.primitives.firstOrNull?.material
        case final PreprocessedMaterial m) {
      setParam(m.parameters, 'charge', (light?.beam ?? false) ? 1 : 0);
    }

    // The Tide Mother loses a boat-shell piece at the end of each break.
    if (world.tryGet<BossBrain>(entity) case final boss?) {
      for (var i = 0; i < boss.phase; i++) {
        if (i != boss.breaking) model.parts['boat_shell_$i']?.visible = false;
      }
    }
  });
}

extension on CrabType {
  String get asset => crabStats[this]!.asset;
}

/// The model goes back to the pool when its crab is gone.
void _releaseModel(World world, Entity entity, CrabModel model) {
  final node = model.node;
  for (final body in node.getComponents<RigidBody>().toList()) {
    node.removeComponent(body);
  }
  for (final collider in node.getComponents<Collider>().toList()) {
    node.removeComponent(collider);
  }
  for (final part in model.parts.values) {
    part.visible = true;
  }
  world.resource<CrabPool>().give(model.type, node, model.clips, model.mound);
}
