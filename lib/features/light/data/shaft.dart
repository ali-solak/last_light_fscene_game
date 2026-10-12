part of '../light.dart';

/// A light shaft: an open cylinder whose node origin is the source and
/// whose local +Y runs one metre to the far end, widening from
/// [startRadius] to 1. [aimShaft] stretches it between two points. Drawn
/// with `beam.fmat`, which reads local Y as the distance along it.
Node lightShaft(Material material, {double startRadius = 0.3}) {
  final mesh = Node(
    name: 'shaft_mesh',
    mesh: Mesh(
      CylinderGeometry(
        bottomRadius: startRadius,
        topRadius: 1,
        height: 1,
        radialSegments: 28,
        heightSegments: 8,
        bottomCap: false,
        topCap: false,
      ),
      material,
    ),
  )
    ..localTransform = Matrix4.translationValues(0, 0.5, 0)
    ..shadowCastingMode = ShadowCastingMode.off;
  return Node(name: 'shaft')..add(mesh);
}

/// Stretches [shaft] from [from] to [to], [radius] wide at the far end.
/// Hides it when the two points meet.
void aimShaft(Node shaft, Vector3 from, Vector3 to, double radius) {
  final dir = to - from;
  final length = dir.length;
  if (length < 0.05) {
    shaft.visible = false;
    return;
  }
  shaft
    ..visible = true
    ..localTransform = Matrix4.compose(
      from,
      Quaternion.fromTwoVectors(Vector3(0, 1, 0), dir / length),
      Vector3(radius, length, radius),
    );
}
