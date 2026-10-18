part of '../motes.dart';

void installMoteVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _rackMotes,
      reads: const {},
      runIf: hasResource<Scene>().and(hasResource<FxTextures>()),
    )
    ..addSystem(
      Schedules.update,
      _dressMotes,
      reads: {Mote, SceneTransform, Pooled},
      inSet: GameSets.dress,
      runIf: hasResource<MoteRack>(),
    )
    ..addSystem(
      Schedules.update,
      _fadeMotes,
      reads: {Mote, Pooled},
      inSet: GameSets.feedback,
      runIf: hasResource<MoteRack>(),
    );
}

/// Startup, visual: small amber glows with a short trail, built once.
void _rackMotes(World world) {
  final dot = world.resource<FxTextures>().dot;
  world.insert(MoteRack(mountRack(world, 'motes', () {
    final glow = Sprite(
      texture: dot,
      width: 0.3,
      height: 0.3,
      color: moteColour,
      blendMode: SpriteBlendMode.additive,
    );
    final node = Node(name: 'mote')
      ..addComponent(TrailComponent(width: 0.06, lifetime: 0.25))
      ..add(Node(name: 'mote_glow', mesh: glow.mesh));
    setRenderLayer(node, RenderLayers.actors);
    return node;
  }, size: moteRackSize)));
}

/// Amber, a little over the bloom threshold: a spark, not a lamp.
final Vector4 moteColour = Vector4(2.2, 1.3, 0.45, 1);

/// A glow on each new mote, placed before its trail forgets the last one.
void _dressMotes(World world) {
  final rack = world.resource<MoteRack>().rack;
  world.query2<Mote, SceneTransform>().without<Pooled>().each((entity, _, t) {
    final node = rack.take();
    if (node == null) return;
    node.position = t.translation;
    node.getComponent<TrailComponent>()?.clear();
    world
      ..add(entity, NodeRef(node))
      ..add(entity, Pooled(rack, node));
  });
}

/// Motes twinkle, and shrink away over their last second; a taken one
/// flickers in the lamp.
void _fadeMotes(World world) {
  world.query2<Mote, Pooled>().each((_, mote, pooled) {
    final glow = pooled.node.children.firstOrNull;
    if (glow == null) return;
    final fade = (moteSeconds - mote.age).clamp(0.0, 1.0);
    final twinkle = 0.85 + 0.15 * math.sin(mote.age * 17);
    glow.scale = Vector3.all(fade * twinkle);
  });
  final fx = world.tryResource<Fx>();
  if (fx == null) return;
  for (final gathered in world.events<MoteGathered>()) {
    fx.burst(FxKind.ember, gathered.position, count: 4, spread: 1.2,
        speed: 0.6, size: 0.8);
  }
}
