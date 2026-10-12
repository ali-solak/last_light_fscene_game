part of '../keeper.dart';

void installKeeperAnimation(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _dressKeeper,
      reads: {Keeper},
      inSet: GameSets.dress,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.update,
      _animateKeeper,
      writes: {Clips, KeeperModel},
      reads: {KeeperBrain, KeeperBody, Harpoon, Lantern, Interactable, HitPause},
      inSet: GameSets.animation,
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.startup,
      _spawnPrompt,
      reads: const {},
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.update,
      _promptKeeper,
      writes: {InteractPromptView},
      reads: {KeeperBrain, Interactable, SceneTransform, Keeper},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>(),
    );
}

/// Visual: the keeper's model, with the oil lamp in his left hand and the
/// harpoon gun in his right, and a kinematic capsule for the physics.
void _dressKeeper(World world) {
  final lib = world.resource<ModelLibrary>();
  world.entitiesWith<Keeper>().without<KeeperModel>().each((entity) {
    final model = lib.instance('keeper');
    final clips = bindClips(lib, 'keeper', model, start: 'Idle_A');
    // Held poses hold: they loop instead of ending and restarting.
    for (final name in const ['Ranged_2H_Aiming', 'Running_HoldingRifle']) {
      clips.byName[name]?.loop = true;
    }
    if (!clips.byName.containsKey('Lamp_Hold')) {
      debugPrint('last_light: keeper.glb has no lamp/aim clips; '
          'export them from keeper.blend');
    }
    Node? attach(String socket, String asset) {
      final at = lib.find(model, socket);
      if (at == null || !lib.has(asset)) return null;
      final node = lib.instance(asset);
      at.add(node);
      return node;
    }

    final lamp = attach('socket_hand_l', 'oil_lamp');
    final gun = attach('socket_hand_r', 'harpoon_gun');
    final flame = lamp == null ? null : lib.find(lamp, 'lamp_flame');
    final materials = world.tryResource<Materials>();
    final flameMaterial = materials?['flame'];
    if (flame != null && flameMaterial != null) {
      assignNode(flame, flameMaterial);
    }
    final glass = lamp == null ? null : lib.find(lamp, 'lamp_glass');
    final glassMaterial = glass == null ? null : materials?.take('lamp_glass');
    if (glass != null && glassMaterial != null) {
      assignNode(glass, glassMaterial);
    }
    if (world.hasResource<PhysicsWorld>()) {
      model
        ..addComponent(RigidBody(type: BodyType.kinematic))
        ..addComponent(
          Collider(
            shape: CapsuleShape(
              radius: keeperRadius,
              halfHeight: keeperHalfHeight,
            ),
            collisionLayer: Layers.keeper,
            collisionMask: Layers.prop | Layers.crab | Layers.ground,
            localPose: Matrix4.translationValues(
              0,
              keeperHalfHeight + keeperRadius,
              0,
            ),
          ),
        );
    }
    setRenderLayer(model, RenderLayers.actors);
    world
      ..add(entity, NodeRef(model))
      ..add(entity, clips)
      ..add(entity, KeeperModel(model, lamp, gun, flame, glassMaterial));
  });
}

/// Mode → clip (§4's keeper table), fitted to gameplay windows.
void _animateKeeper(World world) {
  final dt = world.delta;
  final lib = world.resource<ModelLibrary>();
  final status = world.state<GameStatus>();
  world.query4<KeeperModel, Clips, KeeperBrain, KeeperBody>().each((
    entity,
    model,
    clips,
    brain,
    body,
  ) {
    // Through his eyes the body is a shadow only (the hands are drawn up
    // close by the viewmodel).
    final fp = world.tryResource<CameraRig>()?.firstPerson ?? false;
    if (fp != model.shadowOnly) {
      model.shadowOnly = fp;
      _castShadowOnly(model.node, fp);
    }
    final mode = brain.mode;
    final harpoon = world.tryGet<Harpoon>(entity);
    final lantern = world.tryGet<Lantern>(entity);
    final speed = math.sqrt(
      body.velocity.x * body.velocity.x + body.velocity.z * body.velocity.z,
    );
    double fit(String clip, double window) =>
        lib.seconds('keeper', clip) / math.max(window, 0.05);

    // Which way he moves relative to where he faces, for the stances.
    final stance = _stance(body, speed, model);

    var playback = 1.0;
    var restart = false;
    final landing = body.sinceLanding < keeperLandSeconds;

    // Letting go: the lamp comes down, the harpoon comes off the shoulder.
    if (mode.justExited(KeeperMode.focusing)) {
      model.lowering = lib.seconds('keeper', 'Lamp_Lower', fallback: 0);
    }
    if (mode.justExited(KeeperMode.aiming)) {
      model.aimingOut = lib.seconds('keeper', 'Aim_Out', fallback: 0);
    }
    model
      ..lowering = math.max(0, model.lowering - dt)
      ..aimingOut = math.max(0, model.aimingOut - dt);
    final settling = mode.state == KeeperMode.idle ||
        (mode.state == KeeperMode.moving && speed < keeperWalkBelow);
    // He keeps the lamp in his off hand while he aims, unless it is away.
    final lamp = (lantern?.lit ?? false) ? '_Lamp' : '';
    final walking = speed < keeperWalkBelow;
    // Reloading the harpoon takes over whenever his hands are free.
    final reloading = harpoon?.mode.state == HarpoonMode.reloading &&
        (mode.state == KeeperMode.idle ||
            mode.state == KeeperMode.moving ||
            mode.state == KeeperMode.aiming);
    final name = switch (mode.state) {
      _ when reloading => 'Ranged_2H_Reload',
      KeeperMode.idle || KeeperMode.moving when landing => 'Jump_Land',
      _ when settling && model.lowering > 0 => 'Lamp_Lower',
      _ when settling && model.aimingOut > 0 => 'Aim_Out',
      KeeperMode.idle when (lantern?.throwing ?? false) => 'Throw',
      KeeperMode.idle when status == GameStatus.dawnBoons => 'Waving',
      KeeperMode.idle when mode.elapsed < lib.seconds('keeper', 'Spawn_Ground') &&
          model.respawning => 'Spawn_Ground',
      KeeperMode.idle => 'Idle_A',
      KeeperMode.moving => speed < keeperWalkBelow ? 'Walking_A' : 'Running_A',
      KeeperMode.jumping => body.rise > 0 &&
              mode.elapsed < lib.seconds('keeper', 'Jump_Start')
          ? 'Jump_Start'
          : 'Jump_Idle',
      // Holding the lamp up: raises it, holds it steady, walks or runs
      // with it held out (backing off plays the walk in reverse).
      KeeperMode.focusing
          when mode.elapsed < lib.seconds('keeper', 'Lamp_Raise', fallback: 0) =>
        'Lamp_Raise',
      KeeperMode.focusing => switch (stance) {
        _Stance.still => 'Lamp_Hold',
        _Stance.back => 'Walk_Lamp_Hold',
        _ => walking ? 'Walk_Lamp_Hold' : 'Run_Lamp_Hold',
      },
      // The harpoon: up to the shoulder, held, walked with, fired.
      KeeperMode.aiming when harpoon?.mode.state == HarpoonMode.flying =>
        'Fire_Harpoon$lamp',
      KeeperMode.aiming
          when mode.elapsed < lib.seconds('keeper', 'Aim_In', fallback: 0) =>
        'Aim_In',
      KeeperMode.aiming => stance == _Stance.still
          ? 'Aim_Harpoon$lamp'
          : 'Walk_Aim_Harpoon$lamp',
      KeeperMode.reeling => 'Fishing_Reeling',
      KeeperMode.interacting => world.tryGet<Interactable>(
                brain.interacting ?? entity)?.kind == InteractKind.mirror
          ? 'Interact'
          : 'Use_Item',
      KeeperMode.hit => 'Hit_A',
      KeeperMode.downed => 'Death_A',
    };
    switch (mode.state) {
      case _ when reloading:
        playback = fit(name, lib.seconds('keeper', 'Ranged_2H_Reload',
            fallback: harpoonReloadFallback));
        restart = harpoon!.mode.justEntered(HarpoonMode.reloading);
      case KeeperMode.moving:
        playback = (speed / keeperStride * lib.seconds('keeper', name))
            .clamp(0.6, 1.6);
      case KeeperMode.jumping:
        restart = mode.justEntered(KeeperMode.jumping);
      case KeeperMode.idle || KeeperMode.moving when landing:
        playback = fit(name, keeperLandSeconds);
      case KeeperMode.focusing || KeeperMode.aiming
          when stance != _Stance.still &&
              (name.startsWith('Walk_') || name.startsWith('Run_')):
        playback = (speed / keeperStride * lib.seconds('keeper', name))
                .clamp(0.6, 1.4) *
            (stance == _Stance.back ? -1 : 1);
      case KeeperMode.aiming when name.startsWith('Fire_Harpoon'):
        restart = harpoon!.mode.justEntered(HarpoonMode.flying);
      case KeeperMode.interacting:
        playback = fit(name, brain.interactSeconds);
        restart = mode.justEntered(KeeperMode.interacting);
      case KeeperMode.hit:
        playback = fit(name, keeperHitStagger);
        restart = mode.justEntered(KeeperMode.hit);
      default:
        break;
    }
    if (mode.justExited(KeeperMode.downed)) model.respawning = true;
    if (mode.state != KeeperMode.idle) model.respawning = false;
    fadeTo(clips, name, dt, restart: restart, speed: playback);

    // Hit pause holds the current clip.
    final current = clips.byName[clips.current];
    if (world.has<HitPause>(entity)) {
      current?.playing = false;
      model.paused = true;
    } else if (model.paused) {
      current?.playing = true;
      model.paused = false;
    }

    // The lamp drops while he is down or while it is thrown.
    model.lamp?.visible =
        mode.state != KeeperMode.downed && (lantern?.lit ?? true);
  });
}

/// Startup, visual: the interact prompt, mounted once (a widget mounted
/// mid-frame would rebuild during paint) and moved to whatever is in reach.
void _spawnPrompt(World world) {
  final verb = ValueNotifier<PromptVerb?>(null);
  final node = Node(name: 'interact_prompt')
    ..layers = RenderLayers.actors
    ..visible = false
    ..addComponent(
      WidgetComponent(
        child: InteractPrompt(verb),
        size: const Size(140, 64),
        worldHeight: 0.38,
        pixelRatio: 2,
      ),
    );
  world.spawn([InteractPromptView(node, verb), NodeRef(node), const Billboard()]);
}

/// What the keeper could use right now and the prompt for it: the item
/// in reach, or the one he is holding when it is continuous (aiming a
/// mirror says how to finish). Null when there is nothing to prompt.
(Entity, PromptVerb)? interactPrompt(World world) {
  final brain = world.query<KeeperBrain>().having<Keeper>().firstOrNull?.$2;
  if (brain == null) return null;
  final holding = brain.mode.state == KeeperMode.interacting;
  final target = holding ? brain.interacting : brain.inReach;
  final item = target == null ? null : world.tryGet<Interactable>(target);
  if (target == null || item == null || !item.enabled) return null;
  if (holding && !item.continuous) return null;
  return (
    target,
    holding && item.verb == PromptVerb.aim ? PromptVerb.aiming : item.verb,
  );
}

/// Visual: over the shoulder, the prompt floats above whatever the keeper
/// can use. (Through his eyes it sits under the crosshair instead: the
/// HUD draws it there.)
void _promptKeeper(World world) {
  final prompt = world.query<InteractPromptView>().firstOrNull?.$2;
  if (prompt == null) return;
  final firstPerson = world.tryResource<CameraRig>()?.firstPerson ?? false;
  final shown = firstPerson ? null : interactPrompt(world);
  final at = shown == null ? null : world.tryGet<SceneTransform>(shown.$1);
  prompt.verb.value = at == null ? null : shown!.$2;
  prompt.node.visible = at != null;
  if (at != null) prompt.node.position = Vector3(at.x, at.y + 2.4, at.z);
}

enum _Stance { still, forward, back, left, right }

/// Which way he moves relative to his facing. Starting to move needs a
/// clear speed and stopping needs a clear stop, and the direction bands
/// overlap, so the clip never flickers at a boundary.
_Stance _stance(KeeperBody body, double speed, KeeperModel model) {
  final was = _Stance.values[model.stance];
  if (speed < (was == _Stance.still ? 0.9 : 0.4)) {
    model.stance = _Stance.still.index;
    return _Stance.still;
  }
  final rel = angleDelta(
        body.facing,
        yawToward(body.velocity.x, body.velocity.z),
      ) *
      radians2Degrees;
  // Keep the current band while within 15° past its edge.
  final keep = switch (was) {
    _Stance.forward => rel > -65 && rel < 65,
    _Stance.right => rel >= 35 && rel <= 145,
    _Stance.left => rel <= -35 && rel >= -145,
    _Stance.back => rel.abs() >= 115,
    _Stance.still => false,
  };
  final next = keep
      ? was
      : switch (rel) {
          > -50 && < 50 => _Stance.forward,
          >= 50 && <= 130 => _Stance.right,
          <= -50 && >= -130 => _Stance.left,
          _ => _Stance.back,
        };
  model.stance = next.index;
  return next;
}

/// Sets [root] and everything under it to shadow-only, or back to drawn.
void _castShadowOnly(Node root, bool only) {
  if (root.mesh != null) {
    root.shadowCastingMode =
        only ? ShadowCastingMode.shadowsOnly : ShadowCastingMode.on;
  }
  for (final child in root.children) {
    _castShadowOnly(child, only);
  }
}
