part of '../nights.dart';

/// One run: the seed and its RNG, the night, boons taken, supplies, stats.
final class Run(final int seed) {
  final math.Random rng = math.Random(seed);
  int night = 1;

  /// True from the start of a run until its first night begins.
  bool fresh = true;

  /// Seconds into the current night.
  double nightTime = 0;

  final List<String> boons = [];
  int kills = 0;
  int damageTaken = 0;
  int mirrorsOwned = nightStartMirrors;
  int lampsOwned = nightStartLamps;

  /// Salt lines and barricades to lay out each dawn (fresh every night).
  int saltOwned = nightStartSalt;
  int barricadesOwned = nightStartBarricades;
  int prisms = 0;
}

/// Where new runs take their seed from (tests pin it).
final class RunSeed(final int? fixed);

/// The night's plan, as a routine.
final class NightDirector {
  Routine<NightStep>? routine;
}

final class DuskTimer {
  double left = 0;
}
