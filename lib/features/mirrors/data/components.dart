part of '../mirrors.dart';

/// A placed mirror. Its normal is its facing: (−sin yaw, −cos yaw).
///
/// The player never sets the facing directly: they choose [throwYaw], the
/// way the light should go, and the mirror turns itself to bisect the
/// light coming in and that direction, so it throws exactly there. A
/// mirror without one keeps the facing it was given.
final class Mirror(var double yaw, {double? throwYaw}) {
  late double targetYaw = yaw;
  double? throwYaw = throwYaw;
  bool upright = true;

  @override
  String toString() =>
      'mirror ${(yaw * radians2Degrees).round()}°${upright ? '' : ' down'}';
}

/// The aiming aids: the outlined mirror and the throw preview line.
final class MirrorAim(final Node line, final UnlitMaterial material) {
  Entity? outlined;
  bool aiming = false;
}

/// The Prism boon: this mirror splits the beam in three.
final class const PrismMirror() implements Tag;

/// The mirror's model: the code-turned pivot and the tilt the clips drive.
final class MirrorModel(
  final Node node,
  final Node? pivot,
  final Node? surface,
  final Clips? clips,
  final Sprite? flare,
) {
  bool wasUpright = true;
  bool wasLit = false;
  double glint = 0;
  double time = 0;
}

/// Which mirror a dawn drag holds.
final class MirrorGrab {
  Entity? held;
}

/// The toppled-mirror icons, mounted once and placed over toppled mirrors.
final class MirrorIcons(final List<Node> nodes);
