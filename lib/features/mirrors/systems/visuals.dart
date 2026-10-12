part of '../mirrors.dart';

void installMirrorVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _dressMirrors,
      reads: {Mirror, PrismMirror, MirrorModel},
      inSet: GameSets.dress,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.update,
      _showMirrorAim,
      writes: {MirrorAim},
      reads: {KeeperBrain, Keeper, Mirror, MirrorModel, SceneTransform},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.startup,
      _spawnMirrorIcons,
      reads: const {},
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.update,
      _placeMirrorIcons,
      reads: {Mirror, SceneTransform},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.update,
      _animateMirrors,
      writes: {MirrorModel, Clips},
      reads: {Mirror, CaughtLight, SceneTransform},
      inSet: GameSets.mirrorAnimation,
      runIf: hasResource<Scene>(),
    );
}

/// Visual: a mirror (or prism) model on each placed mirror.
void _dressMirrors(World world) {
  final lib = world.resource<ModelLibrary>();
  final materials = world.tryResource<Materials>();
  world.query<Mirror>().without<MirrorModel>().each((entity, _) {
    final prism = world.has<PrismMirror>(entity);
    final asset = prism ? 'prism' : 'mirror';
    if (!lib.has(asset)) return;
    final node = lib.instance(asset);
    final pivot = lib.find(node, prism ? 'prism_pivot' : 'mirror_pivot');
    final surface = lib.find(node, prism ? 'crystal' : 'mirror_surface');
    final shine = materials?.take(prism ? 'crystal' : 'mirror');
    if (surface != null && shine != null) {
      assignNode(surface, shine);
      // The glass truly reflects the island (the face looks along local -Z).
      if (!prism && mirrorLiveReflections) {
        surface.addComponent(
          PlanarReflectorComponent(
            resolutionScale: mirrorReflectionScale,
            localNormal: Vector3(0, 0, -1),
          ),
        );
      }
    }
    // The toppled frame only shows once it falls.
    lib.find(node, 'frame_toppled')?.visible = false;
    final clips = prism ? null : bindClips(lib, 'mirror', node, start: 'Raise');
    // A glare on the face while it holds light.
    final dot = world.tryResource<FxTextures>()?.dot;
    final flare = dot == null
        ? null
        : Sprite(
            texture: dot,
            width: mirrorFlareSize,
            height: mirrorFlareSize,
            color: Vector4(0, 0, 0, 0),
            blendMode: SpriteBlendMode.additive,
          );
    if (flare != null) {
      node.add(
        Node(name: 'mirror_flare', mesh: flare.mesh)
          ..position = Vector3(0, mirrorFlareHeight, 0)
          ..shadowCastingMode = ShadowCastingMode.off,
      );
    }

    world
      ..add(entity, NodeRef(node))
      ..add(entity, MirrorModel(node, pivot, surface, clips, flare));
    if (clips != null) world.add(entity, clips);
  });
}

/// Code turns the pivot; the clips only ever move `mirror_tilt`. The glint
/// and the flare follow the light the mirror holds, and catching the beam
/// throws a spray of sparks off the glass.
void _animateMirrors(World world) {
  final dt = world.delta;
  final fx = world.tryResource<Fx>();
  world.query2<Mirror, MirrorModel>().each((entity, mirror, model) {
    model.time += dt;
    final caught = world.tryGet<CaughtLight>(entity);
    final lit = caught != null && caught.lit;
    final held = lit ? caught.fade : 0.0;
    if (lit && !model.wasLit && caught.live) {
      if (world.tryGet<SceneTransform>(entity) case final t?) {
        fx?.burst(
          FxKind.spark,
          Vector3(t.x, t.y + mirrorFlareHeight, t.z),
          count: mirrorCatchSparks,
          dir: Vector3(yawDirX(mirror.yaw), 0.4, yawDirZ(mirror.yaw)),
          spread: 0.8,
          tint: Vector3(3.2, 2.8, 2.2),
        );
        fx?.burst(FxKind.flash, Vector3(t.x, t.y + mirrorFlareHeight, t.z),
            count: 1, size: 1.6);
      }
    }
    model.wasLit = lit;
    if (model.flare case final flare?) {
      final pulse = 0.85 + 0.15 * math.sin(model.time * 9);
      final glow = held * pulse * (caught?.live ?? false ? 1.0 : 0.6);
      flare
        ..color = Vector4(2.2 * glow, 1.9 * glow, 1.5 * glow, glow)
        ..width = mirrorFlareSize * (0.6 + 0.4 * held)
        ..height = mirrorFlareSize * (0.6 + 0.4 * held);
    }
    model.pivot?.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), mirror.yaw);
    if (model.clips case final clips?) {
      if (mirror.upright != model.wasUpright) {
        fadeTo(clips, mirror.upright ? 'Raise' : 'Topple', dt, restart: true);
        model.wasUpright = mirror.upright;
      } else {
        fadeTo(clips, clips.current, dt);
      }
    }
    model.glint = smoothTo(model.glint, held, dt, 0.1);
    if (model.surface?.mesh?.primitives.firstOrNull?.material
        case final PreprocessedMaterial m) {
      setParam(m.parameters, 'glint', model.glint);
      setParam(m.parameters, 'charge', held);
    }
  });
}

/// Startup, visual: a pool of toppled-mirror icons.
void _spawnMirrorIcons(World world) {
  final nodes = [
    for (var i = 0; i < mirrorIconPool; i++)
      Node(name: 'mirror_alert')
        ..layers = RenderLayers.actors
        ..visible = false
        ..addComponent(
          WidgetComponent(
            child: const MirrorDownIcon(),
            size: const Size(120, 70),
            worldHeight: 0.55,
            pixelRatio: 2,
          ),
        ),
  ];
  for (final node in nodes) {
    world.spawn([NodeRef(node), const Billboard()]);
  }
  world.insert(MirrorIcons(nodes));
}

/// Visual: an icon over each toppled mirror.
void _placeMirrorIcons(World world) {
  final icons = world.tryResource<MirrorIcons>();
  if (icons == null) return;
  var used = 0;
  world.query2<Mirror, SceneTransform>().each((_, mirror, t) {
    if (mirror.upright || used >= icons.nodes.length) return;
    icons.nodes[used++]
      ..visible = true
      ..position = Vector3(t.x, t.y + mirrorAlertHeight, t.z);
  });
  for (var i = used; i < icons.nodes.length; i++) {
    icons.nodes[i].visible = false;
  }
}

/// Visual: the mirror he would use is outlined (brighter while he aims
/// it), and a dashed line of light runs out along where it sends the
/// light, so aiming is a matter of looking.
void _showMirrorAim(World world) {
  var aim = world.query<MirrorAim>().firstOrNull?.$2;
  if (aim == null) {
    aim = _spawnMirrorAim();
    world.spawn([aim, NodeRef(aim.line)]);
  }
  final brain = world.query<KeeperBrain>().having<Keeper>().firstOrNull?.$2;
  final aiming = brain?.mode.state == KeeperMode.interacting;
  final target = aiming ? brain?.interacting : brain?.inReach;
  final mirror = target == null ? null : world.tryGet<Mirror>(target);
  final shown = mirror != null && mirror.upright ? target : null;

  if (shown != aim.outlined || aiming != aim.aiming) {
    if (aim.outlined case final old?) {
      if (world.tryGet<MirrorModel>(old) case final model?) {
        _outline(model.node, null);
      }
    }
    if (shown != null) {
      if (world.tryGet<MirrorModel>(shown) case final model?) {
        _outline(model.node, aiming ? mirrorOutlineAim : mirrorOutlineReach);
      }
    }
    aim
      ..outlined = shown
      ..aiming = aiming;
    aim.material.baseColorFactor = aiming ? mirrorPreviewAim : mirrorPreviewReach;
  }

  final t = shown == null ? null : world.tryGet<SceneTransform>(shown);
  aim.line.visible = t != null;
  if (t != null) {
    aim.line.localTransform =
        Matrix4.translationValues(t.x, t.y + mirrorPreviewHeight, t.z)
          ..rotateY(mirror!.throwYaw ?? mirror.yaw);
  }
}

/// The preview line: dashes along local −Z (a yaw's forward), drawn as
/// camera-facing ribbons by the engine.
MirrorAim _spawnMirrorAim() {
  final points = <double>[];
  for (var z = mirrorPreviewStart;
      z < mirrorPreviewEnd;
      z += mirrorPreviewDash + mirrorPreviewGap) {
    points.addAll([0, 0, -z, 0, 0, -math.min(z + mirrorPreviewDash, mirrorPreviewEnd)]);
  }
  final material = UnlitMaterial()..baseColorFactor = mirrorPreviewReach;
  final line = Node(
    name: 'mirror_preview',
    mesh: Mesh(
      LineSegmentsGeometry(
        LineSegmentData(positions: Float32List.fromList(points)),
        width: mirrorPreviewWidth,
      ),
      material,
    ),
  )
    ..visible = false
    ..shadowCastingMode = ShadowCastingMode.off;
  setRenderLayer(line, RenderLayers.actors);
  return MirrorAim(line, material);
}

/// Outlines the mirror's own geometry (not its flat glare sprite, whose
/// square would be traced too).
void _outline(Node node, Vector4? color) {
  if (node.name == 'mirror_flare') return;
  node.highlightColor = color;
  for (final child in node.children) {
    _outline(child, color);
  }
}
