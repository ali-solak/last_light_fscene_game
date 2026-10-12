part of '../keeper.dart';

void installKeeperHearts(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.title), _spawnKeeper, reads: {Keeper})
    ..addSystem(
      OnEnter(GameStatus.dawnBoons),
      _keeperAtDawn,
      reads: {Keeper},
      writes: {Hearts, KeeperBrain, SceneTransform},
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _takeHits,
      writes: {Hearts, KeeperBrain},
      reads: {Keeper},
      inSet: GameSets.keeper,
      after: [_keeperModes],
      runIf: inState(GameStatus.night),
    );
}

/// The keeper exists for the whole session; the title diorama shows him.
void _spawnKeeper(World world) {
  if (!world.entitiesWith<Keeper>().isEmpty) return;
  final spawn = world.tryResource<IslandAnchors>()?.keeperSpawn;
  world.spawn(keeperBundle(spawn?.clone() ?? Vector3.zero()));
}

/// Dawn: full hearts, calm; a fresh run starts him at his cottage.
void _keeperAtDawn(World world) {
  final fresh = world.tryResource<Run>()?.fresh ?? true;
  final spawn = world.tryResource<IslandAnchors>()?.keeperSpawn;
  world.query3<Hearts, KeeperBrain, SceneTransform>().having<Keeper>().each((
    _,
    hearts,
    brain,
    t,
  ) {
    hearts.current = hearts.max;
    brain
      ..invulnerable = 0
      ..interacting = null
      ..mode.go(KeeperMode.idle);
    if (fresh && spawn != null) t.setTranslationFrom(spawn);
  });
}

/// Crab attacks (and blasts) cost a heart unless jump i-frames or the
/// post-hit window cover him. At 0 hearts he is downed.
void _takeHits(World world) {
  final row = world.query2<Hearts, KeeperBrain>().having<Keeper>().firstOrNull;
  if (row == null) return;
  final (_, hearts, brain) = row;
  final hits = [
    for (final hit in world.events<CrabAttackLanded>()) hit.hearts,
    for (final hit in world.events<KeeperStruck>()) hit.hearts,
  ];
  for (final amount in hits) {
    if (brain.mode.state == KeeperMode.downed ||
        brain.iFramed ||
        brain.invulnerable > 0) {
      continue;
    }
    hearts.current = math.max(0, hearts.current - amount);
    brain.invulnerable = keeperHitInvuln;
    world.emit(KeeperHit(amount));
    if (hearts.current == 0) {
      brain
        ..interacting = null
        ..mode.go(KeeperMode.downed);
      world.emit(const KeeperDowned());
    } else {
      brain.mode.go(KeeperMode.hit);
    }
  }
}
