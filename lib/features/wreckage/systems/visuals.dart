part of '../wreckage.dart';

void installWreckVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _rackPickups,
      reads: const {},
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.update,
      _dressWrecks,
      reads: {Wreck, Pickup, NodeRef},
      inSet: GameSets.dress,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.update,
      _dressFlotsam,
      reads: {Tideway, FlotsamRack, Flotsam, Pooled},
      inSet: GameSets.dress,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.update,
      _bobFlotsam,
      reads: {Flotsam, Pooled},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>(),
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

  final racks = world.tryResource<PickupRacks>();
  if (racks == null) return;
  world.query<Pickup>().without<NodeRef>().each((entity, pickup) {
    final rack = racks[pickup.kind];
    // A spill nobody can see is worse than a hitch: grow if a night runs
    // the rack dry.
    final node = rack.take(grow: true)!;
    world
      ..add(entity, NodeRef(node))
      ..add(entity, Pooled(rack, node))
      ..add(entity, PickupVisual(node, node.getComponent<PointLightComponent>()!.light));
  });
}

/// Startup, visual: the spill glows, built once. Oil is a warm lamp in a
/// glow, a heart a red glow.
void _rackPickups(World world) {
  final lib = world.resource<ModelLibrary>();
  final dot = world.tryResource<FxTextures>()?.dot;
  Node glow(PickupKind kind) {
    final heart = kind == PickupKind.heart;
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
    return node;
  }

  world.insert(PickupRacks({
    for (final kind in PickupKind.values)
      kind: mountRack(world, 'pickups_${kind.name}', () => glow(kind),
          size: pickupRack),
  }));
}

/// The tideway keeps its own floats; each new flotsam borrows one.
void _dressFlotsam(World world) {
  final lib = world.resource<ModelLibrary>();
  world.entitiesWith<Tideway>().without<FlotsamRack>().each((entity) {
    world.add(entity, FlotsamRack({
      for (final kind in WreckKind.values)
        kind: mountRack(world, 'flotsam_${kind.name}', () => _float(lib, kind),
            size: flotsamMax + 1),
    }));
  });
  final racks = world.query<FlotsamRack>().firstOrNull?.$2;
  if (racks == null) return;
  world.query<Flotsam>().without<Pooled>().each((entity, flotsam) {
    final rack = racks[flotsam.kind];
    final node = rack.take();
    if (node == null) return;
    world
      ..add(entity, NodeRef(node))
      ..add(entity, Pooled(rack, node));
  });
}

/// A float: the crate or barrel riding a child node that bobs, with a
/// ship's lamp still burning on it so it reads on the dark sea.
Node _float(ModelLibrary lib, WreckKind kind) {
  final asset = kind == WreckKind.crate ? 'crate' : 'barrel';
  final ride = Node(name: 'float')
    ..add(Node(name: 'float_lamp', localTransform: Matrix4.translationValues(0, 1.1, 0))
      ..addComponent(PointLightComponent(PointLight(
        color: Vector3(1.0, 0.82, 0.5),
        intensity: 0,
        range: 4.5,
      ))));
  if (lib.has(asset)) ride.add(lib.instance(asset));
  final node = Node(name: 'flotsam')..add(ride);
  setRenderLayer(node, RenderLayers.actors);
  return node;
}

/// Floats rock on the swell and their lamps blink like a buoy's; one on
/// the line is dragged nose-down through the water.
void _bobFlotsam(World world) {
  final t = world.tryResource<IslandScenery>()?.time ?? 0;
  world.query2<Flotsam, Pooled>().each((entity, flotsam, pooled) {
    final ride = pooled.node.children.firstOrNull;
    if (ride == null) return;
    final phase = t * 1.3 + entity.index * 1.7;
    final hauled = world.has<Hooked>(entity);
    ride.localTransform = Matrix4.compose(
      Vector3(0, -0.15 + 0.18 * math.sin(phase), 0),
      Quaternion.axisAngle(Vector3(1, 0, 0),
              hauled ? -0.35 : 0.12 * math.sin(phase * 0.8)) *
          Quaternion.axisAngle(Vector3(0, 0, 1), 0.1 * math.cos(phase * 0.6)),
      Vector3.all(1),
    );
    final blink = math.pow(0.5 + 0.5 * math.sin(t * 3 + entity.index), 4);
    ride.children.firstOrNull?.getComponent<PointLightComponent>()?.light
        .intensity = 0.4 + 2.0 * blink;
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
  for (final landed in world.events<FlotsamLanded>()) {
    final p = landed.position + Vector3(0, 0.3, 0);
    fx
      ..burst(FxKind.droplet, p, count: 24, spread: 1.0, speed: 0.9,
          tint: Vector3(0.45, 0.6, 0.75))
      ..burst(FxKind.dust, p, count: 5, spread: 0.8, size: 0.6);
  }
  world.query2<Wreck, SceneTransform>().each((_, wreck, t) {
    if (wreck.fuse < 0) return;
    fx.burst(FxKind.spark, Vector3(t.x, t.y + 1.0, t.z), count: 2,
        spread: 1.4, speed: 0.5);
  });
}
