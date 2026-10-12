part of '../weather.dart';

/// The weather's own state: where the storm is heading, the gust noise,
/// and the lightning clock.
final class Weather {
  /// 0 calm .. 1 storm, the night's target the wind eases toward.
  double stormGoal = 0;

  /// Where the wind is veering toward (yaw).
  double headingGoal = 0.4;
  double heading = 0.4;

  double time = 0;

  /// Seconds to the next strike, the flash left, and thunder pending.
  double nextBolt = 8;
  double flash = 0;
  double thunderIn = -1;

  /// Particles owed (fractional), carried between frames.
  double rainDebt = 0;
  double fogTimer = 0;

  final math.Random rng = math.Random(11);
}
