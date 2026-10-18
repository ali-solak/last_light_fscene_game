part of '../motes.dart';

void installMoteDrift(GameBuilder game) {
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _shedMotes,
      reads: const {},
      inSet: GameSets.motes,
      runIf: inState(GameStatus.night).and(hasEvents<CrabKilled>()),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _driftMotes,
      writes: {Mote, SceneTransform},
      reads: {Lantern, KeeperBrain, Keeper},
      inSet: GameSets.motes,
      after: [_shedMotes],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _gatherMotes,
      writes: {Lantern},
      reads: {Mote, SceneTransform, Keeper},
      inSet: GameSets.motes,
      after: [_driftMotes],
      runIf: inState(GameStatus.night),
    );
}

/// Each kill throws its motes up and out of the body.
void _shedMotes(World world) {
  for (final killed in world.events<CrabKilled>()) {
    final rng = math.Random(killed.entity.hashCode);
    final n = killed.type == CrabType.tideMother ? moteBossCount : moteCount;
    final p = killed.position;
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final s = moteBurst * (0.5 + rng.nextDouble() * 0.5);
      world.spawn([
        Mote(Vector3(math.cos(a) * s, s * 0.8, math.sin(a) * s)),
        SceneTransform(p.x, p.y + 0.6, p.z),
        DespawnAfter(moteSeconds),
        const DespawnOnExit(GameStatus.night),
      ]);
    }
  }
}

/// Motes slow and hang over the ground; once settled, the lamp pulls the
/// ones in reach, unless it is full or the keeper is down.
void _driftMotes(World world) {
  final dt = world.dt;
  final grid = world.tryResource<HeightGrid>();
  final keeper = world.query3<SceneTransform, Lantern, KeeperBrain>()
      .having<Keeper>()
      .firstOrNull;
  final hungry = keeper != null &&
      keeper.$3.oil < lanternOilMax &&
      keeper.$4.mode.state != KeeperMode.downed;
  final lamp = hungry
      ? Vector3(keeper.$2.x, keeper.$2.y + moteLampHeight, keeper.$2.z)
      : null;
  world.query2<Mote, SceneTransform>().each((_, mote, t) {
    mote.age += dt;
    final v = mote.velocity;
    final at = t.translation;
    if (lamp != null &&
        mote.age >= moteSettle &&
        at.distanceToSquared(lamp) <= motePull * motePull) {
      v.add(Steering.seek(at, v, lamp,
              maxSpeed: motePullSpeed, maxForce: motePullForce) *
          dt);
    } else {
      v.scale(math.max(0, 1 - moteDrag * dt));
      // Bob toward the hover height over the ground.
      final rest = (grid?.sample(at.x, at.z) ?? 0) + moteHover;
      v.y += ((rest - at.y) * 2 + math.sin(mote.age * 3) * 0.3) * dt;
    }
    at.add(v * dt);
  });
}

/// A mote that reaches the lamp is oil in it.
void _gatherMotes(World world) {
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;
  if (keeper == null) return;
  final (k, kt) = keeper;
  final lantern = world.tryGet<Lantern>(k);
  if (lantern == null) return;
  final lamp = Vector3(kt.x, kt.y + moteLampHeight, kt.z);
  world.query<SceneTransform>().having<Mote>().each((entity, t) {
    if (lantern.oil >= lanternOilMax) return;
    if (t.translation.distanceToSquared(lamp) > moteReach * moteReach) return;
    lantern.oil = math.min(lanternOilMax, lantern.oil + moteOil);
    world
      ..despawn(entity)
      ..emit(MoteGathered(t.translation.clone()));
  });
}
