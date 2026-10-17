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
      writes: {Hearts, KeeperBrain, KeeperBody},
      reads: {Keeper, SceneTransform},
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
    hearts
      ..current = hearts.max
      ..nibbles = 0;
    brain
      ..invulnerable = 0
      ..interacting = null
      ..mode.go(KeeperMode.idle);
    if (fresh && spawn != null) t.setTranslationFrom(spawn);
  });
}

/// Crab attacks (and blasts) cost a heart unless jump i-frames or the
/// post-hit window cover him; a swarmling's only nibbles toward one. Every
/// bite that gets through shoves him off the crab. At 0 hearts he is
/// downed.
void _takeHits(World world) {
  final row = world.query4<Hearts, KeeperBrain, KeeperBody, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (_, hearts, brain, body, t) = row;
  final hits = [
    for (final hit in world.events<CrabAttackLanded>())
      (hit.hearts, hit.nibble, world.tryGet<SceneTransform>(hit.crab)),
    for (final hit in world.events<KeeperStruck>()) (hit.hearts, false, null),
  ];
  for (final (amount, nibble, from) in hits) {
    if (brain.mode.state == KeeperMode.downed ||
        brain.iFramed ||
        brain.invulnerable > 0) {
      continue;
    }
    var lost = amount;
    if (nibble) {
      hearts.nibbles++;
      lost = 0;
      if (hearts.nibbles >= keeperNibblesPerHeart) {
        hearts.nibbles = 0;
        lost = amount;
      }
    }
    if (from != null) {
      final dx = t.x - from.x, dz = t.z - from.z;
      final d = math.max(math.sqrt(dx * dx + dz * dz), 1e-3);
      final shove = lost > 0 ? keeperHitShove : keeperNibbleShove;
      body.velocity
        ..x += dx / d * shove
        ..z += dz / d * shove;
      world.emit(KeeperBitten(from.x, from.z, lost > 0));
    }
    if (lost == 0) continue;
    hearts.current = math.max(0, hearts.current - lost);
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
