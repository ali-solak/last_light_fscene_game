part of '../lamps.dart';

/// A placed lamp post.
final class LampPost {
  bool lit = true;

  /// Seconds since it was snuffed (Salted Wicks relights at 6).
  double dark = 0;

  @override
  String toString() => lit ? 'lamp lit' : 'lamp out';
}

/// The lamp's model parts and light.
final class LampModel(
  final Node node,
  final Node? glassOn,
  final Node? glassOff,
  final PointLight light,
  final Clips? clips,
) {
  bool wasLit = true;
}

/// Which lamp a dawn drag holds.
final class LampGrab {
  Entity? held;
}

/// The lamp-out icons, mounted once and placed over snuffed lamps.
final class LampIcons(final List<Node> nodes);
