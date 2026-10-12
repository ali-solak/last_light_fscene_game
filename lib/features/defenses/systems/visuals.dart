part of '../defenses.dart';

void installDefenseVisuals(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _drawDefenses,
    writes: {DefenseModel},
    reads: {SaltLine, Barricade, SceneTransform, NodeRef},
    inSet: GameSets.lampAnimation,
    runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
  );
}

/// Salt lines as a strip of glittering white grains along the ground;
/// barricades as fence sections end to end. Both follow their yaw (turned
/// at dawn), and salt fades as it is worn away.
void _drawDefenses(World world) {
  final lib = world.resource<ModelLibrary>();
  final grid = world.tryResource<HeightGrid>();
  final physics = world.hasResource<PhysicsWorld>();
  final fx = world.tryResource<Fx>();

  world.query2<SaltLine, SceneTransform>().each((entity, salt, t) {
    var model = world.tryGet<DefenseModel>(entity);
    if (model == null) {
      final grains = PhysicallyBasedMaterial()
        ..baseColorFactor = Vector4(0.92, 0.94, 0.97, 1)
        ..roughnessFactor = 0.35
        ..emissiveFactor = Vector4(0.12, 0.16, 0.2, 1);
      final node = Node(name: 'salt_line');
      const pieces = 7;
      for (var i = 0; i < pieces; i++) {
        node.add(
          Node(
            name: 'salt_$i',
            mesh: Mesh(
              CuboidGeometry(Vector3(salt.length / pieces + 0.05, 0.06, saltWidth * 0.55)),
              grains,
            ),
          )..shadowCastingMode = ShadowCastingMode.off,
        );
      }
      setRenderLayer(node, RenderLayers.actors);
      model = DefenseModel(node);
      world
        ..add(entity, model)
        ..add(entity, NodeRef(node));
    }
    // Each piece sits on the ground under it.
    final dirX = yawDirX(salt.yaw), dirZ = yawDirZ(salt.yaw);
    final pieces = model.node.children;
    final worn = (salt.strength / saltStrength).clamp(0.2, 1.0);
    for (var i = 0; i < pieces.length; i++) {
      final f = (i + 0.5) / pieces.length - 0.5;
      final x = t.x + dirX * salt.length * f, z = t.z + dirZ * salt.length * f;
      final y = math.max(grid?.sample(x, z) ?? t.y, 0.0) + 0.03;
      pieces[i]
        ..position = Vector3(x - t.x, y - t.y, z - t.z)
        ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), salt.yaw + math.pi / 2)
        ..scale = Vector3(1, 1, worn);
    }
    model.node.rotation = Quaternion.identity();
  });

  world.query2<Barricade, SceneTransform>().each((entity, wall, t) {
    var model = world.tryGet<DefenseModel>(entity);
    if (model == null) {
      if (!lib.has('fence_section')) return;
      final node = Node(name: 'barricade');
      for (final offset in const [-0.8, 0.8]) {
        final fence = lib.instance('fence_section')
          ..position = Vector3(offset, 0, 0);
        node.add(fence);
      }
      if (physics) {
        node.addComponent(
          Collider(
            shape: BoxShape(
              halfExtents: Vector3(barricadeLength / 2, 0.6, barricadeThickness / 2),
            ),
            collisionLayer: Layers.prop,
            localPose: Matrix4.translationValues(0, 0.6, 0),
          ),
        );
      }
      setRenderLayer(node, RenderLayers.actors);
      model = DefenseModel(node);
      world
        ..add(entity, model)
        ..add(entity, NodeRef(node));
    }
    // A barricade under attack shudders and sheds splinters.
    final damaged = 1 - wall.hp / barricadeHp;
    t.setRotationY(wall.yaw + math.pi / 2);
    model.node.scale = Vector3(1, 1 - 0.25 * damaged, 1);
    if (damaged > 0 && fx != null && math.Random().nextDouble() < 0.02) {
      fx.burst(FxKind.splinter, Vector3(t.x, t.y + 0.8, t.z), count: 1,
          spread: 1.0, size: 0.6);
    }
  });
}
