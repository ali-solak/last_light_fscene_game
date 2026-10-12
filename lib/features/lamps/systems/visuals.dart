part of '../lamps.dart';

void installLampVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _dressLamps,
      reads: {LampPost, LampModel},
      inSet: GameSets.dress,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.startup,
      _spawnLampIcons,
      reads: const {},
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.update,
      _placeLampIcons,
      reads: {LampPost, SceneTransform},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.update,
      _animateLamps,
      writes: {LampModel, Clips},
      reads: {LampPost},
      inSet: GameSets.lampAnimation,
      runIf: hasResource<Scene>(),
    );
}

/// Visual: the post, its glass and a warm light.
void _dressLamps(World world) {
  final lib = world.resource<ModelLibrary>();
  final materials = world.tryResource<Materials>();
  world.query<LampPost>().without<LampModel>().each((entity, _) {
    if (!lib.has('lamp_post')) return;
    final node = lib.instance('lamp_post');
    final on = lib.find(node, 'lantern_glass');
    final off = lib.find(node, 'lantern_glass_off');
    final glass = materials?.take('lamp_glass');
    if (on != null && glass != null) assignNode(on, glass);
    final light = PointLight(
      color: Vector3(1, 0.78, 0.45),
      intensity: lampLightIntensity,
      range: lampLightRange,
    );
    node.add(Node(name: 'lamp_light')
      ..localTransform = Matrix4.translationValues(0, lampLightHeight, 0)
      ..addComponent(PointLightComponent(light)));
    final clips = lib.animations('lamp_post').isEmpty
        ? null
        : bindClips(lib, 'lamp_post', node, start: 'Hit');
    clips?.byName['Hit']
      ?..weight = 0
      ..pause();
    world
      ..add(entity, NodeRef(node))
      ..add(entity, LampModel(node, on, off, light, clips));
    if (clips != null) world.add(entity, clips);
  });
}

/// Swap the lit and dark glass, play `Hit` when snuffed, dim the light.
void _animateLamps(World world) {
  final dt = world.delta;
  world.query2<LampPost, LampModel>().each((_, lamp, model) {
    model.glassOn?.visible = lamp.lit;
    model.glassOff?.visible = !lamp.lit;
    model.light.intensity = lamp.lit ? lampLightIntensity : 0;
    if (model.glassOn?.mesh?.primitives.firstOrNull?.material
        case final PreprocessedMaterial m) {
      setParam(m.parameters, 'lit', lamp.lit ? 1 : 0);
      setParam(m.parameters, 'intensity', 1);
    }
    if (model.clips case final clips?) {
      final snuffed = model.wasLit && !lamp.lit;
      fadeTo(clips, 'Hit', dt, restart: snuffed);
    }
    model.wasLit = lamp.lit;
  });
}

/// Startup, visual: a pool of lamp-out icons (widgets mount outside a frame).
void _spawnLampIcons(World world) {
  final nodes = [
    for (var i = 0; i < lampIconPool; i++)
      Node(name: 'lamp_alert')
        ..layers = RenderLayers.actors
        ..visible = false
        ..addComponent(
          WidgetComponent(
            child: const LampOutIcon(),
            size: const Size(120, 70),
            worldHeight: 0.55,
            pixelRatio: 2,
          ),
        ),
  ];
  for (final node in nodes) {
    world.spawn([NodeRef(node), const Billboard()]);
  }
  world.insert(LampIcons(nodes));
}

/// Visual: an icon over each snuffed lamp.
void _placeLampIcons(World world) {
  final icons = world.tryResource<LampIcons>();
  if (icons == null) return;
  var used = 0;
  world.query2<LampPost, SceneTransform>().each((_, lamp, t) {
    if (lamp.lit || used >= icons.nodes.length) return;
    icons.nodes[used++]
      ..visible = true
      ..position = Vector3(t.x, t.y + lampAlertHeight, t.z);
  });
  for (var i = used; i < icons.nodes.length; i++) {
    icons.nodes[i].visible = false;
  }
}
