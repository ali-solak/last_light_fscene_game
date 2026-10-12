part of '../wreckage.dart';

void installWreckVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _dressWrecks,
      reads: {Wreck, Pickup, NodeRef},
      inSet: GameSets.dress,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.update,
      _animateWreckage,
      writes: {PickupVisual},
      reads: {Wreck, Pickup, SceneTransform},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>(),
    );
}

/// A crate or barrel model on each wreck, solid to the beam, the harpoon
/// and the keeper; a glow on each spill.
void _dressWrecks(World world) {
  final lib = world.resource<ModelLibrary>();
  final physics = world.hasResource<PhysicsWorld>();
  world.query<Wreck>().without<NodeRef>().each((entity, wreck) {
    final asset = wreck.kind == WreckKind.crate ? 'crate' : 'barrel';
    if (!lib.has(asset)) return;
    final node = lib.instance(asset);
    if (physics) {
      node.addComponent(
        Collider(
          shape: node.extractMeshData().toConvexHullShape(),
          collisionLayer: Layers.prop,
        ),
      );
    }
    setRenderLayer(node, RenderLayers.actors);
    world.add(entity, NodeRef(node));
  });

  final dot = world.tryResource<FxTextures>()?.dot;
  world.query<Pickup>().without<NodeRef>().each((entity, pickup) {
    final heart = pickup.kind == PickupKind.heart;
    final colour = heart ? Vector3(1.0, 0.25, 0.3) : Vector3(1.0, 0.7, 0.3);
    final light = PointLight(color: colour, intensity: 2.5, range: 3.5);
    final node = Node(name: 'pickup')..addComponent(PointLightComponent(light));
    if (dot != null) {
      final glow = Sprite(
        texture: dot,
        width: 0.9,
        height: 0.9,
        color: Vector4(colour.x * 2.5, colour.y * 2.5, colour.z * 2.5, 1),
        blendMode: SpriteBlendMode.additive,
      );
      node.add(Node(mesh: glow.mesh));
    }
    if (!heart && lib.has('oil_lamp')) {
      node.add(lib.instance('oil_lamp')..scale = Vector3.all(1.6));
    }
    setRenderLayer(node, RenderLayers.actors);
    world
      ..add(entity, NodeRef(node))
      ..add(entity, PickupVisual(node, light));
  });
}

/// Spills bob and pulse; a lit fuse spits sparks.
void _animateWreckage(World world) {
  final dt = world.delta;
  final fx = world.tryResource<Fx>();
  world.query3<Pickup, PickupVisual, SceneTransform>().each((
    _,
    pickup,
    visual,
    t,
  ) {
    visual.time += dt;
    final fade = (1 - (pickup.age - pickupSeconds + 3) / 3).clamp(0.0, 1.0);
    visual.node
      ..position = Vector3(t.x, t.y + 0.6 + 0.15 * math.sin(visual.time * 3), t.z)
      ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), visual.time * 1.5);
    visual.light.intensity = (2 + 0.8 * math.sin(visual.time * 5)) * fade;
  });
  if (fx == null) return;
  world.query2<Wreck, SceneTransform>().each((_, wreck, t) {
    if (wreck.fuse < 0) return;
    fx.burst(FxKind.spark, Vector3(t.x, t.y + 1.0, t.z), count: 2,
        spread: 1.4, speed: 0.5);
  });
}
