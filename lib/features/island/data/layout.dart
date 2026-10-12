part of '../island.dart';

/// What a layout entry is.
enum PropKind { rock, dynamicProp, staticProp }

/// One placed piece of scenery: model, ground position, yaw, and for rocks
/// the radius it blocks the beam with.
final class const LayoutPiece(
  final String model,
  final double x,
  final double z,
  final PropKind kind, {
  final double yaw = 0,
  final double radius = 0,
  final double mass = 0,
});

/// The hand-placed scenery, in engine space. Rocks sit off the main paths
/// so they shape the beam without walling off a beach.
const List<LayoutPiece> islandLayout = [
  // Rocks: beam occluders.
  LayoutPiece('rocks_c', -22, -8, .rock, yaw: 0.4, radius: 1.6),
  LayoutPiece('rocks_b', 8, -22, .rock, yaw: 1.1, radius: 0.9),
  LayoutPiece('rocks_a', 24, 14, .rock, yaw: 2.0, radius: 0.6),
  LayoutPiece('rocks_c', -14, 26, .rock, yaw: 2.6, radius: 1.6),
  LayoutPiece('rocks_b', 20, -18, .rock, yaw: 0.2, radius: 0.9),
  LayoutPiece('rocks_a', -4, -30, .rock, yaw: 1.7, radius: 0.6),
  LayoutPiece('rocks_b', 28, -4, .rock, yaw: 3.0, radius: 0.9),
  LayoutPiece('rocks_a', 6, 27, .rock, yaw: 0.9, radius: 0.6),
  LayoutPiece('rocks_c', -26, 12, .rock, yaw: 1.3, radius: 1.6),
  // Loose props: light dynamic bodies the keeper and crabs push around.
  LayoutPiece('crate', -4, -17, .dynamicProp, yaw: 0.3, mass: 8),
  LayoutPiece('crate', -3.2, -16, .dynamicProp, yaw: 1.0, mass: 8),
  LayoutPiece('barrel', -12, -14, .dynamicProp, mass: 10),
  LayoutPiece('barrel', 12, 18, .dynamicProp, mass: 10),
  LayoutPiece('driftwood_a', 3, 30, .dynamicProp, yaw: 0.7, mass: 5),
  LayoutPiece('driftwood_b', 31, 6, .dynamicProp, yaw: 2.2, mass: 6),
  LayoutPiece('driftwood_a', -8, -33, .dynamicProp, yaw: 1.4, mass: 5),
  LayoutPiece('buoy', 12, -31, .dynamicProp, yaw: 0.4, mass: 6),
  // Static set dressing.
  LayoutPiece('fishing_net', -5, 28, .staticProp, yaw: 0.5),
  LayoutPiece('fence_section', -14, -22, .staticProp, yaw: 0.6),
  LayoutPiece('fence_section', -12.4, -23.2, .staticProp, yaw: 0.6),
];
