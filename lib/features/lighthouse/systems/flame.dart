part of '../lighthouse.dart';

void installFlame(GameBuilder game) {
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _drainFlame,
      reads: {Crab, CrabBrain, BroodSpawn, Dead},
      inSet: GameSets.rules,
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      OnEnter(GameStatus.dawnBoons),
      _restoreFlame,
      reads: {Preserves},
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _feedFlame,
      reads: const {},
      inSet: GameSets.rules,
      after: [_drainFlame],
      runIf: hasEvents<BrazierLit>(),
    );
}

/// Every signal fire kindled feeds the lamp a little.
void _feedFlame(World world) {
  final flame = world.resource<Flame>();
  for (final _ in world.events<BrazierLit>()) {
    flame.current = math.min(flame.max, flame.current + brazierFlameGift);
  }
}

/// Climbing crabs drain the Flame; at 0 the run is lost.
void _drainFlame(World world) {
  var rate = 0.0;
  world.query2<Crab, CrabBrain>().without<Dead>().each((entity, crab, brain) {
    if (brain.mode.state != CrabMode.climbing) return;
    rate += world.has<BroodSpawn>(entity)
        ? flameDrainBrood
        : switch (crab.type) {
            .scuttler => flameDrainScuttler,
            .tarback => flameDrainTarback,
            _ => flameDrainOther,
          };
  });
  if (rate <= 0) return;
  final flame = world.resource<Flame>();
  final amount = math.min(rate * world.dt, flame.current);
  flame.current -= amount;
  world.emit(FlameDrained(amount));
  if (!flame.lowWarned && flame.current < flameLowMark) {
    flame.lowWarned = true;
    world.emit(const FlameLow());
  }
  if (flame.current <= 0) world.setState(GameStatus.lost);
}

/// Dawn restores the Flame; a fresh run lights it full.
void _restoreFlame(World world) {
  final flame = world.resource<Flame>();
  final run = world.tryResource<Run>();
  if (run == null || run.fresh) {
    flame.current = flame.max;
  } else {
    final preserves = !world.entitiesWith<Preserves>().isEmpty;
    flame.current = math.min(
      flame.max,
      flame.current + (preserves ? flamePreservesRestore : flameDawnRestore),
    );
  }
  if (flame.current >= flameLowMark) flame.lowWarned = false;
}
