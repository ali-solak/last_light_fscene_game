part of '../defenses.dart';

/// A line of salt across the ground, [length] metres along [yaw] (the
/// direction the line runs). Crossing crabs wear it down.
final class SaltLine(var double yaw, {this.length = saltLength}) {
  final double length;
  double strength = saltStrength;

  bool get spent => strength <= 0;
}

/// A driftwood barricade, [barricadeLength] metres along [yaw]. Crabs chew
/// it down.
final class Barricade(var double yaw) {
  double hp = barricadeHp;

  bool get broken => hp <= 0;
}

/// Which defense a dawn drag is turning.
final class DefenseGrab {
  Entity? held;
}

/// A defense's model (salt grains, the barricade) for the visuals.
final class DefenseModel(final Node node);
