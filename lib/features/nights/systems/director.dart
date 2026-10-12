part of '../nights.dart';

void installNightDirector(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.dusk), _beginDusk, reads: const {})
    ..addSystem(
      Schedules.fixedUpdate,
      _tickDusk,
      reads: const {},
      inSet: GameSets.nights,
      runIf: inState(GameStatus.dusk),
    )
    ..addSystem(OnEnter(GameStatus.night), _beginNight, reads: const {})
    ..addSystem(
      Schedules.fixedUpdate,
      _directNight,
      reads: {Crab, Dead},
      inSet: GameSets.nights,
      runIf: inState(GameStatus.night),
    );
}

void _beginDusk(World world) =>
    world.resource<DuskTimer>().left = nightDuskSeconds;

void _tickDusk(World world) {
  final dusk = world.resource<DuskTimer>()..left -= world.dt;
  if (dusk.left <= 0) world.setState(GameStatus.night);
}

/// The night begins: build its plan and announce it.
void _beginNight(World world) {
  final run = world.resource<Run>()
    ..fresh = false
    ..nightTime = 0;
  world.resource<TideLevel>().state = .high;
  world.resource<NightDirector>().routine = Routine(
    nightPlan(run.night, run.rng),
  );
  world.emit(NightStarted(run.night));
}

/// Drives the night's routine; clears the night when the plan is done and
/// no crab is left.
void _directNight(World world) {
  final run = world.resource<Run>()..nightTime += world.dt;
  final director = world.resource<NightDirector>();
  final routine = director.routine;
  if (routine == null) return;
  final alive = world.query<Crab>().without<Dead>().count();

  routine.advance(world.dt, (step) => switch (step) {
    Land(:final beach, :final crabs) => _land(world, run, beach, crabs),
    Wait(:final seconds) =>
      routine.elapsed >= seconds ? StepResult.success : StepResult.running,
    UntilCleared() =>
      routine.elapsed >= nightClearGrace && alive == 0
          ? StepResult.success
          : StepResult.running,
    Tide(:final level) => () {
      world.resource<TideLevel>().state = level;
      return StepResult.success;
    }(),
  });

  if (routine.finished && alive == 0) {
    director.routine = null;
    world.emit(NightCleared(run.night));
    if (run.night >= nightCount) {
      world.setState(GameStatus.won);
    } else {
      run.night++;
      if (run.night % nightLampEvery == 1) run.lampsOwned++;
      world.setState(GameStatus.dawnBoons);
    }
  }
}

/// Spawns a landing a metre under the water at the beach's spawn points.
StepResult _land(
  World world,
  Run run,
  Beach beach,
  Map<CrabType, int> crabs,
) {
  final points = world.resource<SpawnPoints>().of(beach);
  if (points.isEmpty) return StepResult.success;
  var count = 0;
  for (final MapEntry(key: type, value: n) in crabs.entries) {
    for (var i = 0; i < n; i++) {
      final base = points[count % points.length];
      final a = run.rng.nextDouble() * math.pi * 2;
      final r = run.rng.nextDouble() * nightLandingSpread;
      world.spawn(crabBundle(
        type,
        Vector3(base.x + math.cos(a) * r, base.y, base.z + math.sin(a) * r),
      ));
      count++;
    }
  }
  world.emit(WaveLanded(beach, count));
  return StepResult.success;
}
