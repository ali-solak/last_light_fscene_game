part of '../gulls.dart';

void installGullFlock(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.dawnBoons), _flockIn, reads: {Keeper})
    ..addSystem(
      Schedules.fixedUpdate,
      _spookGulls,
      writes: {Gull},
      reads: {SceneTransform, Keeper},
      inSet: GameSets.gulls,
      runIf: atDawn,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _flyGulls,
      writes: {Gull, SceneTransform},
      reads: {Keeper},
      inSet: GameSets.gulls,
      after: [_spookGulls],
      runIf: atDawn,
    );
}

final math.Random _rng = math.Random(53);

/// Dawn: the flock comes in off the sea, each bird to its own patch of sand.
void _flockIn(World world) {
  final anchors = world.tryResource<IslandAnchors>();
  if (anchors == null) return;
  final centre = anchors.lighthouse;
  for (var i = 0; i < gullCount; i++) {
    final landing = _landingSpot(world);
    if (landing == null) return;
    final out = Vector3(landing.x - centre.x, 0, landing.z - centre.z);
    if (out.length2 < 1e-6) out.setValues(1, 0, 0);
    out.normalize();
    final from = landing + out * gullFromSea + Vector3(0, gullFromHeight, 0);
    world.spawn([
      Gull(landing),
      SceneTransform(from.x, from.y, from.z),
      const DespawnOnExit(GameStatus.dawnBuild),
    ]);
  }
}

/// A patch of low dry sand, clear of the tower and the keeper.
Vector3? _landingSpot(World world) {
  final grid = world.tryResource<HeightGrid>();
  final tower = world.tryResource<IslandAnchors>()?.lighthouse;
  if (grid == null || tower == null) return null;
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
  for (var tries = 0; tries < 60; tries++) {
    final x = gridCenterX(_rng.nextInt(gridCells));
    final z = gridCenterZ(_rng.nextInt(gridCells));
    final h = grid.sample(x, z);
    if (h < gullLandMin || h > gullLandMax || !grid.walkableXZ(x, z)) continue;
    if (grid.grass[gridIndexAt(x, z)] == 1) continue;
    if (distSq2(x, z, tower.x, tower.z) <
        gullTowerClearance * gullTowerClearance) {
      continue;
    }
    if (keeper != null &&
        distSq2(x, z, keeper.x, keeper.z) <
            gullKeeperClearance * gullKeeperClearance) {
      continue;
    }
    return Vector3(x, h, z);
  }
  return null;
}

/// The keeper walking up scatters a landed gull and the ones beside it;
/// a scattered gull, once clear, picks somewhere else to land.
void _spookGulls(World world) {
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
  final gulls = world.query2<Gull, SceneTransform>().snapshot();
  for (final (_, gull, t) in gulls) {
    gull.mode.tick(world.dt);
    if (gull.mode.state == GullMode.fleeing &&
        gull.mode.elapsed >= gullFleeSeconds) {
      if (_landingSpot(world) case final spot?) gull.landing.setFrom(spot);
      gull.mode.go(GullMode.flying);
    }
    if (keeper == null || gull.mode.state != GullMode.landed) continue;
    if (distSq2(t.x, t.z, keeper.x, keeper.z) > gullSpook * gullSpook) continue;
    for (final (_, other, o) in gulls) {
      if (other.mode.state == GullMode.landed &&
          distSq2(o.x, o.z, t.x, t.z) <= gullSpookSpread * gullSpookSpread) {
        other.mode.go(GullMode.fleeing);
      }
    }
  }
}

/// Flying birds arrive at their patch and keep apart; fleeing ones climb
/// away from the keeper; landed ones stand.
void _flyGulls(World world) {
  final dt = world.dt;
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
  final flying = [
    for (final (_, g, t) in world.query2<Gull, SceneTransform>().snapshot())
      if (g.mode.state != GullMode.landed) t.translation,
  ];
  world.query2<Gull, SceneTransform>().each((_, gull, t) {
    final at = t.translation;
    final v = gull.velocity;
    switch (gull.mode.state) {
      case GullMode.landed:
        v.setZero();
        return;
      case GullMode.flying:
        v.add(Steering.arrive(at, v, gull.landing,
                slowingRadius: gullSlowing,
                maxSpeed: gullSpeed,
                maxForce: gullForce) *
            dt);
        if (at.distanceTo(gull.landing) <= gullTouchdown) {
          at.setFrom(gull.landing);
          gull.mode.go(GullMode.landed);
          return;
        }
      case GullMode.fleeing:
        final threat = keeper?.translation ?? gull.landing;
        v
          ..add(Steering.flee(at, v, threat,
                  maxSpeed: gullSpeed, maxForce: gullForce) *
              dt)
          ..y = gullClimb;
    }
    final neighbours = [
      for (final p in flying)
        if (!identical(p, at)) p,
    ];
    v.add(Steering.separation(at, v, neighbours,
            desiredDistance: gullSpacing) *
        dt);
    at.add(v * dt);
    final flat = v.x * v.x + v.z * v.z;
    if (flat > 0.01) t.setRotationY(yawToward(v.x, v.z));
  });
}
