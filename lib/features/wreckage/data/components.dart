part of '../wreckage.dart';

enum WreckKind { crate, barrel }

/// A washed-up crate or powder barrel. A lit [fuse] counts down to the
/// barrel going up.
final class Wreck(final WreckKind kind) {
  double fuse = -1;
  bool broken = false;

  @override
  String toString() => '${kind.name}${fuse >= 0 ? ' fuse' : ''}';
}

enum PickupKind { oil, heart }

/// Something spilled from a smashed crate, waiting to be walked over.
final class Pickup(final PickupKind kind) {
  double age = 0;
}

/// A pickup's glow, bobbing.
final class PickupVisual(final Node node, final PointLight light) {
  double time = 0;
}
