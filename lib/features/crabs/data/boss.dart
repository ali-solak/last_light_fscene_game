part of '../crabs.dart';

/// The Tide Mother's steps.
sealed class BossStep extends Step<BossStep> {
  const BossStep();
}

final class const Roar() extends BossStep;

final class const Advance(final double metres) extends BossStep;

final class const BossSlam() extends BossStep;

final class const BroodRelease(final int count) extends BossStep;

/// `Roar`, then forever: advance 8 m, slam, release a brood.
const Step<BossStep> tideMotherPlan = Sequence([
  Roar(),
  Repeat(
    Sequence([Advance(8), BossSlam(), BroodRelease(tideMotherBrood)]),
  ),
]);
