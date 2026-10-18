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

/// Wreckage still at sea: it drifts along the shore ([drift] is which way
/// round) until the harpoon hauls it in, or it sinks.
final class Flotsam(final WreckKind kind, var double drift) {
  double age = 0;

  @override
  String toString() => 'flotsam ${kind.name}';
}

/// The tide that brings flotsam in, and when it next does.
final class Tideway {
  double next = flotsamFirst;
  final math.Random rng = math.Random(31);
}

/// The floats the tideway shows its flotsam with, one rack per kind: a
/// crate or barrel riding a blinking lamp so it reads on the dark sea.
final class FlotsamRack(final Map<WreckKind, NodeRack> racks) {
  NodeRack operator [](WreckKind kind) => racks[kind]!;
}

/// Where a hooked bolt bites a float, and how big a mark it is.
Vector3 flotsamCentre(SceneTransform t) => Vector3(t.x, t.y + 0.3, t.z);
const double flotsamHookRadius = 0.9;

enum PickupKind { oil, heart }

/// Something spilled from a smashed crate, waiting to be walked over.
final class Pickup(final PickupKind kind) {
  double age = 0;
}

/// A pickup's glow, bobbing.
final class PickupVisual(final Node node, final PointLight light) {
  double time = 0;
}

/// The spill glows, one rack per kind.
final class PickupRacks(final Map<PickupKind, NodeRack> racks) {
  NodeRack operator [](PickupKind kind) => racks[kind]!;
}
