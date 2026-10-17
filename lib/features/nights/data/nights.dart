part of '../nights.dart';

/// A night is a plan of these steps.
sealed class NightStep extends Step<NightStep> {
  const NightStep();
}

/// Crabs land on [beach].
final class const Land(final Beach beach, final Map<CrabType, int> crabs)
    extends NightStep;

final class const Wait(final double seconds) extends NightStep;

/// Until every crab is gone.
final class const UntilCleared() extends NightStep;

final class const Tide(final TideState level) extends NightStep;

/// The plan for [night]. Counts scale with the night and draw on [rng].
Step<NightStep> nightPlan(int night, math.Random rng) =>
    Sequence<NightStep>(nightSteps(night, rng)..add(const UntilCleared()));

/// The beach the first wave of [night] lands on (where the keeper should
/// be looking when it starts).
Beach nightFirstBeach(int night) =>
    nightSteps(night, math.Random(0)).whereType<Land>().first.beach;

/// The steps of [night]'s plan, in order.
List<NightStep> nightSteps(int night, math.Random rng) {
  final scale = 1 + nightHordeGrowth * (night - 1);
  int n(int min, int max) =>
      ((min + rng.nextInt(max - min + 1)) * scale).round();

  // Scuttlers come ashore as a horde, swelling night by night.
  Land scuttlers(Beach beach, [Map<CrabType, int> extra = const {}]) =>
      Land(beach, {.scuttler: n(12, 16), ...extra});

  return switch (night) {
    1 => [
      const Wait(4),
      scuttlers(.north),
      const Wait(18),
      scuttlers(.north),
      const Wait(18),
      scuttlers(.north),
    ],
    2 => [
      const Wait(4),
      scuttlers(.north),
      const Wait(16),
      scuttlers(.east),
      const Wait(16),
      scuttlers(.north, {.tarback: 1}),
      const Wait(14),
      scuttlers(.east),
    ],
    3 => [
      const Wait(4),
      scuttlers(.south, {.snuffer: 1}),
      const Wait(15),
      scuttlers(.north, {.snuffer: 1}),
      const Wait(15),
      scuttlers(.east, {.snuffer: 1, .tarback: 1}),
      const Wait(14),
      scuttlers(.north),
    ],
    4 => [
      const Wait(4),
      scuttlers(.east, {.snuffer: 1}),
      const Wait(14),
      scuttlers(.north, {.basher: 1}),
      const Wait(14),
      scuttlers(.south, {.tarback: 1, .snuffer: 1}),
      const Wait(14),
      scuttlers(.east, {.snuffer: 1}),
    ],
    5 => [
      const Tide(.low),
      const Wait(4),
      scuttlers(.north, {.burrower: 2}),
      const Wait(14),
      scuttlers(.south, {.burrower: 2, .snuffer: 1}),
      const Wait(14),
      scuttlers(.east, {.basher: 1, .tarback: 1}),
      const Wait(14),
      scuttlers(.north, {.snuffer: 1}),
    ],
    6 => [
      const Wait(4),
      scuttlers(.east, {.mothCrab: 2}),
      const Wait(13),
      scuttlers(.north, {.mothCrab: 2, .tarback: 1}),
      const Wait(13),
      scuttlers(.south, {.mothCrab: 2, .basher: 1}),
      const Wait(13),
      scuttlers(.east, {.burrower: 2, .snuffer: 1}),
    ],
    7 => [
      const Wait(4),
      scuttlers(.north, {.tarback: 1}),
      scuttlers(.east, {.snuffer: 1}),
      scuttlers(.south, {.tarback: 1}),
      const Wait(16),
      scuttlers(.north, {.mothCrab: 2, .basher: 1}),
      scuttlers(.south, {.burrower: 2}),
    ],
    8 => [
      const Wait(4),
      scuttlers(.east, {.glassback: 1}),
      const Wait(13),
      scuttlers(.north, {.tarback: 1, .snuffer: 1}),
      const Wait(13),
      scuttlers(.south, {.glassback: 1, .mothCrab: 2}),
      const Wait(13),
      scuttlers(.east, {.basher: 1, .burrower: 2}),
    ],
    9 => [
      const Tide(.low),
      const Wait(3),
      scuttlers(.north, {.tarback: 1, .snuffer: 1}),
      const Wait(9),
      scuttlers(.east, {.glassback: 1, .mothCrab: 2}),
      const Wait(9),
      scuttlers(.south, {.basher: 1, .burrower: 2}),
      const Wait(9),
      scuttlers(.north, {.tarback: 1, .mothCrab: 2}),
      scuttlers(.east, {.snuffer: 2}),
    ],
    _ => [
      const Wait(3),
      const Land(.north, {.tideMother: 1}),
      const Wait(20),
      scuttlers(.east),
      const Wait(20),
      scuttlers(.south, {.mothCrab: 2}),
      const Wait(20),
      scuttlers(.east, {.tarback: 1}),
    ],
  };
}

/// The dusk card's forecast line for [night].
String nightForecast(int night) => switch (night) {
  1 => 'Scuttlers from the north',
  2 => 'Tarbacks from the east',
  3 => 'Snuffers hunt the lamps',
  4 => 'Bashers come for the mirrors',
  5 => 'Low tide. Something burrows',
  6 => 'Moths drawn to the light',
  7 => 'All three beaches at once',
  8 => 'Glassbacks turn the beam',
  9 => 'Short breaths between the waves',
  _ => 'The Tide Mother wakes',
};
