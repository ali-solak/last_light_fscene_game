import 'package:flutter_scene/physics.dart';
import 'package:vector_math/vector_math.dart';

/// Collision layers. Debris collides with ground and props only, so the
/// keeper is never tripped by corpses.
abstract final class Layers {
  static const int ground = 1 << 0;
  static const int prop = 1 << 1;
  static const int crab = 1 << 2;
  static const int keeper = 1 << 3;
  static const int debris = 1 << 4;
  static const int mirror = 1 << 5;

  static const int debrisMask = ground | prop;
  static const int propMask = ground | prop | crab | keeper | debris;
}

/// The nearest hit on [mask].
///
/// flutter_scene_rapier 0.5 accepts a query `layerMask` without applying
/// it, so the layer is checked here against each collider.
RaycastHit? raycastLayers(
  PhysicsWorld physics,
  Ray ray,
  double maxDistance,
  int mask, {
  bool includeDynamic = false,
}) {
  RaycastHit? best;
  for (final hit in physics.raycastAll(
    ray,
    maxDistance: maxDistance,
    layerMask: mask,
    includeDynamic: includeDynamic,
  )) {
    final collider = hit.collider;
    if (collider is! Collider || collider.collisionLayer & mask == 0) continue;
    if (best == null || hit.distance < best.distance) best = hit;
  }
  return best;
}
