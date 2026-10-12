part of '../fire.dart';

void installFireVisuals(GameBuilder game) {
  game.addSystem(
    Schedules.renderSync,
    _drawFire,
    writes: {FireVisual},
    runIf: hasResource<Scene>(),
  );
}

/// Render sync: flames, embers and smoke off the burning cells (within a
/// per-frame budget, spread evenly over the fire), and a pool of
/// flickering lights placed over the fire front, a few metres apart.
void _drawFire(World world) {
  final fire = world.resource<FireField>();
  final grid = world.tryResource<HeightGrid>();
  final visual = world.query<FireVisual>().firstOrNull?.$2;
  if (visual == null) {
    _spawnFireLights(world);
    return;
  }
  final dt = world.delta;
  visual.time += dt;
  final fx = world.tryResource<Fx>();

  Vector3 at(int i) => Vector3(
    gridCenterX(i % gridCells),
    math.max(grid?.height[i] ?? 0, 0),
    gridCenterZ(i ~/ gridCells),
  );

  // A sheet of flame per burning cell, facing the eye (the shader turns
  // it), wide enough to merge with its neighbours.
  if (visual.flames case final flames?) {
    flames.clearInstances();
    for (var k = 0; k < fire.count; k++) {
      final i = fire.active[k];
      final p = at(i);
      final h = ((i * 2654435761) & 0xffff) / 0xffff;
      final heat = (fire.burn[i] / fireBurnMin).clamp(0.25, 1.0);
      // Jittered inside the cell so the fire never shows the grid.
      final j = ((i * 40503) & 0xffff) / 0xffff;
      addFlame(
        flames,
        p + Vector3((h - 0.5) * 0.8, -0.3, (j - 0.5) * 0.8),
        fireCardScale * (0.8 + 0.4 * h),
        phase: h,
        heat: heat,
      );
    }
  }

  // Embers and smoke rise off it.
  if (fx != null && fire.count > 0) {
    visual.debt += dt * fireParticlesPerCell * fire.count;
    final n = math.min(visual.debt.floor(), fireParticleBudget);
    visual.debt -= visual.debt.floor();
    final rng = math.Random(visual.time.hashCode);
    for (var k = 0; k < n; k++) {
      final p = at(fire.active[rng.nextInt(fire.count)]);
      if (rng.nextDouble() < 0.7) {
        fx.burst(FxKind.ember, p + Vector3(0, 0.8, 0), count: 1, spread: 0.8);
      } else {
        fx.burst(FxKind.smoke, p + Vector3(0, 1.6, 0), count: 1, size: 1.1,
            spread: 0.3);
      }
    }
  }

  // Lights over the fire, spaced out.
  var used = 0;
  final spacing2 = fireLightSpacing * fireLightSpacing;
  final placed = <Vector3>[];
  for (var k = 0; k < fire.count && used < visual.lights.length; k++) {
    final p = at(fire.active[k]);
    if (placed.any((q) => distSq2(q.x, q.z, p.x, p.z) < spacing2)) continue;
    placed.add(p);
    final (node, light) = visual.lights[used++];
    final flicker = 0.75 +
        0.15 * math.sin(visual.time * 13 + k) +
        0.1 * math.sin(visual.time * 29.3 + k * 2);
    node
      ..visible = true
      ..localTransform = Matrix4.translationValues(p.x, p.y + 1.2, p.z);
    light.intensity = fireLightIntensity3d * flicker;
  }
  for (var i = used; i < visual.lights.length; i++) {
    final (node, light) = visual.lights[i];
    node.visible = false;
    light.intensity = 0;
  }
}

void _spawnFireLights(World world) {
  final root = Node(name: 'fire_lights');
  final lights = <(Node, PointLight)>[];
  for (var i = 0; i < fireLights; i++) {
    final light = PointLight(
      color: Vector3(1.0, 0.55, 0.2),
      intensity: 0,
      range: fireLightRange,
    );
    final node = Node(name: 'fire_light')
      ..visible = false
      ..addComponent(PointLightComponent(light));
    root.add(node);
    lights.add((node, light));
  }
  final flames = flameSheets(world.tryResource<Materials>());
  if (flames != null) {
    root.add(
      Node(name: 'grass_fire')
        ..addComponent(InstancedMeshComponent(flames))
        ..shadowCastingMode = ShadowCastingMode.off,
    );
  }
  setRenderLayer(root, RenderLayers.actors);
  world.spawn([FireVisual(flames, lights), NodeRef(root)]);
}

/// A batch of flame sheets drawn with `grass_fire.fmat` (one draw for the
/// lot), or null without the material. Fill it with [addFlame].
InstancedMesh? flameSheets(Materials? materials) {
  final material = materials?['grass_fire'];
  if (material == null) return null;
  setParam(material.parameters, 'brightness', fireBrightness);
  return InstancedMesh(
    geometry: _flameSheet(),
    material: material,
    sortTransparentInstances: true,
  );
}

/// One flame sheet rooted at [at], [scale] times 2 m by 2.4 m, with its
/// own flicker [phase] (0..1) and [heat] (0..1: low guttering .. roaring).
void addFlame(
  InstancedMesh flames,
  Vector3 at,
  double scale, {
  required double phase,
  required double heat,
}) {
  final index = flames.addInstance(
    Matrix4.compose(at, Quaternion.identity(), Vector3.all(scale)),
  );
  flames
    ..setInstanceAttribute(index, 'phase', phase)
    ..setInstanceAttribute(index, 'heat', heat);
}

/// One upright sheet, 2 m wide and 2.4 m tall, rooted at y = 0, UV y
/// running up the flame (the shader billboards it).
MeshGeometry _flameSheet() {
  const w = 1.0, h = 2.4;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([-w, 0, 0, w, 0, 0, w, h, 0, -w, h, 0]),
    normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
    texCoords: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
    indices: const [0, 1, 2, 0, 2, 3],
  );
}
