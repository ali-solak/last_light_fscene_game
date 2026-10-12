part of '../nights.dart';

void installRun(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _startRun,
      reads: const {},
      inSet: GameSets.feedback,
      runIf: hasEvents<GameStarted>().or(hasEvents<RestartRequested>()),
    )
    ..addSystem(
      Schedules.update,
      _quitRun,
      reads: const {},
      inSet: GameSets.feedback,
      runIf: hasEvents<QuitRequested>(),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _countStats,
      reads: const {},
      inSet: GameSets.nights,
      after: [_directNight],
      runIf: hasEvents<CrabKilled>().or(hasEvents<KeeperHit>()),
    )
    ..addSystem(OnEnter(GameStatus.lost), _recordBest, reads: const {})
    ..addSystem(OnEnter(GameStatus.won), _recordBest, reads: const {});
}

/// Start (or restart) a run: a fresh `Run`, then the first dawn offer.
void _startRun(World world) {
  world
    ..consumeAny<GameStarted>()
    ..consumeAny<RestartRequested>();
  final seed =
      world.tryResource<RunSeed>()?.fixed ??
      DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  world
    ..insert(Run(seed))
    ..resource<NightDirector>().routine = null
    ..setState(Pause.running)
    ..setState(GameStatus.dawnBoons);
}

void _quitRun(World world) {
  world
    ..consumeAny<QuitRequested>()
    ..setState(Pause.running)
    ..setState(GameStatus.title);
}

void _countStats(World world) {
  final run = world.resource<Run>();
  for (final _ in world.events<CrabKilled>()) {
    run.kills++;
  }
  for (final hit in world.events<KeeperHit>()) {
    run.damageTaken += hit.amount;
  }
}

/// The best night reached, saved when a run ends.
void _recordBest(World world) {
  final settings = world.tryResource<Settings>();
  final run = world.resource<Run>();
  if (settings == null) return;
  final reached = world.state<GameStatus>() == GameStatus.won
      ? nightCount
      : run.night;
  if (reached > settings.bestNight) {
    settings.bestNight = reached;
    world.tryResource<SaveStore>()?.save(settings);
  }
}
