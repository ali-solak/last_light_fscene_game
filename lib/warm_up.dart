import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import 'assets/model_library.dart';
import 'features/fx/fx.dart' show FxTextures;
import 'features/island/island.dart' show Materials, assignNode;

/// Compiles every render pipeline play can reach while the loading screen
/// is up, so nothing stalls the first time it is drawn (a mirror placed, a
/// crab landed, grass catching fire). One of every model with its own
/// materials, every `.fmat` material on a static and a skinned body, and
/// the instanced, decal and sprite kinds, drawn once offscreen under both
/// lit shading tiers by [Scene.warmUp], then taken away again.
Future<void> warmUpPipelines(
  Scene scene,
  ModelLibrary lib,
  Materials materials,
  FxTextures textures,
) async {
  final rack = Node(name: 'warm_up');
  for (final asset in lib.assets) {
    rack.add(lib.instance(asset));
  }

  final everyMaterial = <PreprocessedMaterial>{
    ...materials.shared.values,
    for (final pool in materials.pools.values) ?pool.firstOrNull,
  };
  final bodies = [
    for (final asset in const ['mirror', 'scuttler']) if (lib.has(asset)) asset,
  ];
  for (final material in everyMaterial) {
    for (final body in bodies) {
      final node = lib.instance(body);
      _assignAll(node, material);
      rack.add(node);
    }
    // Instanced (the fire sheets, scatter) and decal (scorch, beam
    // stripes) draws build their own pipelines.
    final instanced = InstancedMesh(geometry: _quad(), material: material)
      ..addInstance(Matrix4.identity());
    rack
      ..add(Node(name: 'warm_instanced')
        ..addComponent(InstancedMeshComponent(instanced)))
      ..add(DecalNode(material: material, name: 'warm_decal'));
  }
  // Camera-facing line ribbons (the mirror's throw preview).
  rack.add(Node(
    name: 'warm_lines',
    mesh: Mesh(
      LineSegmentsGeometry(
        LineSegmentData(positions: Float32List.fromList([0, 0, 0, 0, 0, 1])),
        width: 0.05,
      ),
      UnlitMaterial(),
    ),
  ));
  for (final blend in SpriteBlendMode.values) {
    final sprite = Sprite(texture: textures.dot, width: 1, height: 1, blendMode: blend);
    rack.add(Node(name: 'warm_sprite', mesh: sprite.mesh));
  }

  // The outline passes (an exposed crab's glow) build on first use too.
  if (rack.children.firstOrNull case final outlined?) _outline(outlined);

  scene.add(rack);
  try {
    await scene.warmUp(
      [RenderView(camera: PerspectiveCamera(position: Vector3(0, 30, -30)))],
      includeOffscreen: true,
      allShadingTiers: true,
      sliceBudget: const Duration(milliseconds: 50),
    );
  } finally {
    scene.remove(rack);
  }
}

void _outline(Node node) {
  node.highlightColor = Vector4(1, 1, 1, 1);
  for (final child in node.children) {
    _outline(child);
  }
}

void _assignAll(Node node, Material material) {
  assignNode(node, material);
  for (final child in node.children) {
    _assignAll(child, material);
  }
}

MeshGeometry _quad() => MeshGeometry.fromArrays(
  positions: Float32List.fromList([-1, 0, 0, 1, 0, 0, 1, 2, 0, -1, 2, 0]),
  normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
  texCoords: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
  indices: const [0, 1, 2, 0, 2, 3],
);
