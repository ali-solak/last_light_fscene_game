import 'dart:math' as math;

/// The wind over the island: a steady breeze plus gusts, stronger on storm
/// nights. Grass, sea, fog, beam dust, particles, rain and fire spread all
/// read it; the weather feature drives it.
final class Wind {
  /// Unit direction the wind blows toward, on the ground plane.
  double dirX = 0.94, dirZ = 0.34;

  /// Steady strength, 0 calm .. 1 gale.
  double strength = 0.3;

  /// Gust on top, 0..1, eased by the weather.
  double gust = 0;

  /// 0 clear .. 1 full storm (rain, lightning, cloud).
  double storm = 0;

  double get force => strength + gust * 0.6;
  double get x => dirX * force;
  double get z => dirZ * force;

  void blowToward(double yawRadians) {
    dirX = -math.sin(yawRadians);
    dirZ = -math.cos(yawRadians);
  }
}
