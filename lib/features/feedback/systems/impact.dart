part of '../feedback.dart';

void installImpact(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _impacts,
    reads: {Keeper},
    inSet: GameSets.feedback,
  );
}

/// Hitstop and camera trauma for the big moments; hit pause on the keeper.
void _impacts(World world) {
  final state = world.resource<FeedbackState>()
    ..wallTime += world.unscaledDelta;
  final rig = world.resource<CameraRig>();
  final clock = world.clock;

  for (final _ in world.events<HarpoonFired>()) {
    rig
      ..addTrauma(feedbackShotTrauma)
      ..addKick(feedbackShotKick);
  }
  for (final strike in world.events<CrabBashed>()) {
    state.freeze(clock, strike.exposed ? feedbackBashExposedFreeze : feedbackBashFreeze);
    rig
      ..addTrauma(feedbackBashTrauma)
      ..addKick(feedbackBashKick);
  }
  for (final _ in world.events<HarpoonHit>()) {
    state.freeze(clock, feedbackHarpoonFreeze);
    rig.addTrauma(feedbackHarpoonTrauma);
  }
  for (final _ in world.events<ShellCracked>()) {
    state.freeze(clock, feedbackCrackFreeze);
    rig.addTrauma(feedbackCrackTrauma);
  }
  for (final _ in world.events<BossPhase>()) {
    state.freeze(clock, feedbackBossFreeze);
    rig.addTrauma(feedbackBossTrauma);
  }
  for (final _ in world.events<SlamLanded>()) {
    rig.addTrauma(feedbackSlamTrauma);
  }
  for (final _ in world.events<KeeperHit>()) {
    rig.addTrauma(feedbackKeeperTrauma);
    final keeper = world.entitiesWith<Keeper>().firstOrNull;
    if (keeper != null) {
      world.add(keeper, const HitPause(), removeAfter: feedbackKeeperHitPause);
    }
  }
  for (final _ in world.events<CrabKilled>()) {
    state.streak =
        state.wallTime - state.lastKill <= feedbackStreakWindow
            ? state.streak + 1
            : 1;
    state.lastKill = state.wallTime;
  }
}
