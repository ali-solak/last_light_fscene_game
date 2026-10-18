part of '../wreckage.dart';

void installWreckTide(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      (world) => world.spawn([Tideway()]),
      reads: const {},
    )
    ..addSystem(OnEnter(GameStatus.night), _turnTide, writes: {Tideway})
    ..addSystem(
      Schedules.fixedUpdate,
      _bringFlotsam,
      writes: {Tideway},
      reads: {Flotsam},
      inSet: GameSets.flotsam,
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _driftFlotsam,
      writes: {Flotsam, SceneTransform},
      reads: {Hooked},
      inSet: GameSets.flotsam,
      after: [_bringFlotsam],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _beachFlotsam,
      reads: {Flotsam, SceneTransform},
      inSet: GameSets.flotsam,
      after: [_driftFlotsam],
      runIf: inState(GameStatus.night),
    );
}

/// A new night: the first flotsam comes in soon.
void _turnTide(World world) {
  world.query<Tideway>().each((_, tide) => tide.next = flotsamFirst);
}

/// Every so often the sea carries a crate or a barrel in off a landing
/// beach, never more than a few at once.
void _bringFlotsam(World world) {
  final row = world.query<Tideway>().firstOrNull;
  if (row == null) return;
  final tide = row.$2..next -= world.dt;
  if (tide.next > 0) return;
  tide.next = flotsamEvery;
  if (world.query<Flotsam>().count() >= flotsamMax) return;
  final rng = tide.rng;
  final at = _offshore(world, rng);
  if (at == null) return;
  final kind = rng.nextDouble() < flotsamBarrelShare
      ? WreckKind.barrel
      : WreckKind.crate;
  world.spawn([
    Flotsam(kind, rng.nextBool() ? 1 : -1),
    SceneTransform(at.x, _seaLevel(world), at.y)
      ..setRotationY(rng.nextDouble() * math.pi * 2),
    const DespawnOnExit(GameStatus.night),
  ]);
}

/// Open water off a random landing beach: out from the island past the
/// wading depth, as (x, z).
Vector2? _offshore(World world, math.Random rng) {
  final grid = world.tryResource<HeightGrid>();
  final anchors = world.tryResource<IslandAnchors>();
  final points = world.tryResource<SpawnPoints>()?.points ?? const [];
  if (grid == null || anchors == null || points.isEmpty) return null;
  final p = points[rng.nextInt(points.length)];
  final out = Vector2(p.x - anchors.lighthouse.x, p.z - anchors.lighthouse.z);
  if (out.length2 < 1e-6) return null;
  out.normalize();
  for (var d = flotsamOffshore; d <= flotsamOffshore + 10; d += 1) {
    final x = p.x + out.x * d, z = p.z + out.y * d;
    if (grid.sample(x, z) < flotsamDepth) return Vector2(x, z);
  }
  return null;
}

/// The sea's mean height under the swell (the tide drops it).
double _seaLevel(World world) =>
    world.tryResource<TideLevel>()?.low ?? false ? -islandTideShift : 0;

/// Loose flotsam drifts along the shore, turning back before it grounds,
/// riding the tide; left alone long enough, it sinks.
void _driftFlotsam(World world) {
  final dt = world.dt;
  final grid = world.tryResource<HeightGrid>();
  final centre = world.tryResource<IslandAnchors>()?.lighthouse;
  final sea = _seaLevel(world);
  world.query2<Flotsam, SceneTransform>().each((entity, flotsam, t) {
    t.y = sea;
    // On the line it is hauled, not drifting (nor sinking).
    if (world.has<Hooked>(entity)) return;
    flotsam.age += dt;
    if (flotsam.age >= flotsamSeconds) {
      world.despawn(entity);
      return;
    }
    if (centre == null) return;
    final rx = t.x - centre.x, rz = t.z - centre.z;
    final r = math.sqrt(rx * rx + rz * rz);
    if (r < 1e-3) return;
    final step = flotsamDriftSpeed * dt * flotsam.drift;
    final x = t.x - rz / r * step, z = t.z + rx / r * step;
    if ((grid?.sample(x, z) ?? -10) >= flotsamDepth) {
      flotsam.drift = -flotsam.drift;
      return;
    }
    t
      ..x = x
      ..z = z;
  });
}

/// Flotsam hauled up onto the sand is wreckage like any other: a crate to
/// break open, a barrel to set off where the horde walks.
void _beachFlotsam(World world) {
  final grid = world.tryResource<HeightGrid>();
  if (grid == null) return;
  final lowTide = world.tryResource<TideLevel>()?.low ?? false;
  world.query2<Flotsam, SceneTransform>().each((entity, flotsam, t) {
    final h = grid.sample(t.x, t.z);
    if (h < flotsamBeachHeight || !grid.walkableXZ(t.x, t.z, lowTide: lowTide)) {
      return;
    }
    final at = Vector3(t.x, h, t.z);
    world
      ..despawn(entity)
      ..spawn([
        Wreck(flotsam.kind),
        SceneTransform(at.x, at.y, at.z)..rotation.setFrom(t.rotation),
        const DespawnOnExit(GameStatus.night),
      ])
      ..emit(FlotsamLanded(flotsam.kind == WreckKind.barrel, at));
  });
}
