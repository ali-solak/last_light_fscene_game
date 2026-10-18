part of '../lantern.dart';

/// The keeper's oil lamp.
final class Lantern {
  double oil = lanternOilMax;
  bool focusing = false;

  /// Seconds of continuous focus.
  double focusTime = 0;

  /// Seconds until a thrown lamp comes back (Smash).
  double away = 0;

  /// Seconds left of the throw animation.
  double throwTime = 0;

  /// The swing: seconds until it can swing again, and seconds left of the
  /// swing itself (the hands animate it).
  double bashCooldown = 0;
  double bashTime = 0;

  bool get lit => away <= 0;
  bool get throwing => throwTime > 0;

  @override
  String toString() =>
      'oil ${oil.toStringAsFixed(0)}${focusing ? ' focus' : ''}';
}

/// A thrown lamp in flight: from the keeper's hand to where it will burst,
/// arcing over [seconds].
final class ThrownLamp(final Vector3 from, final Vector3 to, final double radius) {
  double age = 0;

  double get t => (age / lanternThrowSeconds).clamp(0.0, 1.0);

  /// Where it is now: along the line, lifted by a parabola.
  Vector3 get position {
    final f = t;
    return from + (to - from) * f + Vector3(0, 4 * lanternThrowArc * f * (1 - f), 0);
  }
}

/// A wisp over a burst lamp (Will-o'-Wisp): crabs near it go to it.
final class const Lure() implements Tag;

/// The wisp glows: a rack of cold lights.
final class LureRack(final NodeRack rack);

/// A wisp's glow and light, and how long it has burned.
final class LureGlow(final Node glow, final PointLight light) {
  double age = 0;
}

/// Burning oil from a thrown lamp: light and damage in a disc.
final class BurnPuddle(final double x, final double z, final double radius) {
  double age = 0;
}

/// The lantern's light in the world: a real spot light that carves the
/// dark and throws shadows, and the lamp's own warm glow. No geometry but
/// the [spares]: lit lamps ready to throw.
final class LanternVisual(
  final SpotLight spot,
  final Node spotNode,
  final PointLight glow,
  final Node glowNode,
  final Node? beam,
  final PreprocessedMaterial? beamMaterial,
  final NodeRack spares,
) {
  double time = 0;
  double sparks = 0;

  /// 1 on a flare, fading: the lamp blazes for a moment.
  double flare = 0;

  /// 0 wide .. 1 focused, eased.
  double focus = 0;
  double embers = 0;

  /// 0 burning .. 1 dry and smouldering, eased.
  double dry = 0;
}
