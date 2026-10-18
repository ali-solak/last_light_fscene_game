part of '../gulls.dart';

void installGullVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _rackGulls,
      reads: const {},
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.update,
      _dressGulls,
      reads: {Gull, Pooled},
      inSet: GameSets.dress,
      runIf: hasResource<GullRack>(),
    )
    ..addSystem(
      Schedules.update,
      _flapGulls,
      writes: {GullParts},
      reads: {Gull},
      inSet: GameSets.animation,
      runIf: hasResource<GullRack>(),
    );
}

/// Startup, visual: the flock, built once from primitives.
void _rackGulls(World world) {
  world.insert(GullRack(mountRack(world, 'gulls', _gull, size: gullCount)));
}

PhysicallyBasedMaterial _matte(double r, double g, double b) =>
    PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(r, g, b, 1)
      ..roughnessFactor = 0.9
      ..metallicFactor = 0;

/// A gull facing −Z, about half a metre long: a white body and head, a
/// yellow beak, a grey tail, and grey wings on shoulder pivots.
Node _gull() {
  final white = _matte(0.9, 0.9, 0.88);
  final grey = _matte(0.6, 0.63, 0.68);
  final yellow = _matte(0.95, 0.72, 0.22);
  Node part(MeshGeometry shape, Material m, Vector3 at, [Vector3? scale]) =>
      Node(mesh: Mesh(shape, m))
        ..position = at
        ..scale = scale ?? Vector3.all(1);
  Node wing(double side) => Node(
    name: side > 0 ? 'wing_l' : 'wing_r',
    localTransform: Matrix4.translationValues(0.07 * side, 0.05, -0.02),
  )..add(part(CuboidGeometry(Vector3(0.5, 0.02, 0.16)), grey,
      Vector3(0.26 * side, 0, 0)));
  final body = Node(name: 'gull_body')
    ..add(part(SphereGeometry(radius: 0.5, segments: 12, rings: 8), white,
        Vector3.zero(), Vector3(0.17, 0.15, 0.36)))
    ..add(part(SphereGeometry(radius: 0.5, segments: 10, rings: 6), white,
        Vector3(0, 0.1, -0.2), Vector3(0.13, 0.13, 0.14)))
    ..add(part(CuboidGeometry(Vector3(0.03, 0.03, 0.1)), yellow,
        Vector3(0, 0.09, -0.31)))
    ..add(part(WedgeGeometry(Vector3(0.12, 0.03, 0.14)), grey,
        Vector3(0, 0.02, 0.22)))
    ..add(wing(1))
    ..add(wing(-1));
  final node = Node(name: 'gull')..add(body);
  setRenderLayer(node, RenderLayers.actors);
  return node;
}

/// A bird on each new gull, and its moving parts found once.
void _dressGulls(World world) {
  final rack = world.resource<GullRack>().rack;
  world.query<Gull>().without<Pooled>().each((entity, _) {
    final node = rack.take();
    final body = node?.getChildByName('gull_body');
    final left = node?.getChildByName('wing_l');
    final right = node?.getChildByName('wing_r');
    if (node == null || body == null || left == null || right == null) return;
    world
      ..add(entity, NodeRef(node))
      ..add(entity, Pooled(rack, node))
      ..add(entity, GullParts(body, left, right));
  });
}

/// Wings beat in flight (harder fleeing, still in a glide down), fold
/// back on the sand; a landed bird dips to peck now and then.
void _flapGulls(World world) {
  final dt = world.delta;
  world.query2<Gull, GullParts>().each((entity, gull, parts) {
    parts.time += dt;
    final t = parts.time + entity.index * 0.37;
    final state = gull.mode.state;
    if (state == GullMode.landed) {
      final peck = math.pow(math.max(0, math.sin(t * 1.3)), 8).toDouble();
      parts.body.rotation = Quaternion.axisAngle(Vector3(1, 0, 0), -0.6 * peck);
      parts.left.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), -1.35);
      parts.right.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), 1.35);
      return;
    }
    final gliding = state == GullMode.flying && gull.velocity.y < -0.6;
    final hz = state == GullMode.fleeing ? 4.5 : 3.2;
    final beat = gliding ? 0.12 : 0.6 * math.sin(t * math.pi * 2 * hz);
    parts.body.rotation = Quaternion.identity();
    parts.left.rotation = Quaternion.axisAngle(Vector3(0, 0, 1), beat);
    parts.right.rotation = Quaternion.axisAngle(Vector3(0, 0, 1), -beat);
  });
}
