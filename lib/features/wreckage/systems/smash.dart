part of '../wreckage.dart';

void installWreckSmash(GameBuilder game) {
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _smashWrecks,
      writes: {Wreck, CrabBody},
      reads: {SceneTransform, Crab, Dead, Keeper},
      // Before the crabs move and take damage, so a blast's knockback and
      // burns land this step.
      inSet: GameSets.lantern,
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _collectPickups,
      writes: {Pickup, Lantern, Hearts},
      reads: {SceneTransform, Keeper},
      inSet: GameSets.rules,
      runIf: inState(GameStatus.night),
    );
}

/// Harpoon hits, slams, moth blasts, the keeper's landing and fire break
/// or light wreckage; lit fuses run down; broken crates spill, barrels
/// blow (and set off their neighbours).
void _smashWrecks(World world) {
  final dt = world.dt;
  final wrecks = world.query2<Wreck, SceneTransform>().snapshot();
  if (wrecks.isEmpty) return;
  final fire = world.tryResource<FireField>();

  void hitNear(double x, double z, double radius, {bool cratesOnly = false}) {
    for (final (_, wreck, t) in wrecks) {
      if (wreck.broken) continue;
      if (distSq2(t.x, t.z, x, z) > radius * radius) continue;
      if (wreck.kind == WreckKind.barrel) {
        if (cratesOnly) continue;
        _light(wreck, 0);
      } else {
        wreck.broken = true;
      }
    }
  }

  for (final hit in world.events<HarpoonHit>()) {
    hitNear(hit.point.x, hit.point.z, wreckHitRadius);
  }
  for (final slam in world.events<SlamLanded>()) {
    hitNear(slam.position.x, slam.position.z, slam.damageRadius + 0.5);
  }
  for (final boom in world.events<MothExploded>()) {
    hitNear(boom.position.x, boom.position.z, 2.5);
  }
  for (final landed in world.events<KeeperLanded>()) {
    hitNear(landed.position.x, landed.position.z, wreckStompRadius,
        cratesOnly: true);
  }

  for (final (entity, wreck, t) in wrecks) {
    // A barrel standing in fire catches.
    if (wreck.kind == WreckKind.barrel &&
        wreck.fuse < 0 &&
        (fire?.burningAt(t.x, t.z) ?? false)) {
      _light(wreck, barrelBurnFuse);
    }
    if (wreck.fuse >= 0) {
      wreck.fuse -= dt;
      if (wreck.fuse <= 0) wreck.broken = true;
    }
    if (!wreck.broken) continue;
    world.despawn(entity);
    final at = Vector3(t.x, t.y, t.z);
    world.emit(WreckBroken(wreck.kind == WreckKind.barrel, at));
    if (wreck.kind == WreckKind.crate) {
      _spill(world, entity, at);
    } else {
      _blast(world, at, wrecks);
    }
  }
}

void _light(Wreck wreck, double fuse) {
  if (wreck.fuse < 0 || wreck.fuse > fuse) wreck.fuse = fuse;
}

/// A crate spills lamp oil or, now and then, a heart.
void _spill(World world, Entity crate, Vector3 at) {
  final roll = math.Random(crate.hashCode ^ (at.x * 1000).toInt()).nextDouble();
  final kind = roll < crateHeartChance
      ? PickupKind.heart
      : (roll < crateHeartChance + crateOilChance ? PickupKind.oil : null);
  if (kind == null) return;
  world.spawn([
    Pickup(kind),
    SceneTransform(at.x, at.y, at.z),
    const DespawnOnExit(GameStatus.night),
  ]);
}

/// A barrel goes up: crabs in reach are burned and flung, the keeper too
/// close is hurt, the grass catches, and neighbouring barrels are lit.
void _blast(
  World world,
  Vector3 at,
  List<(Entity, Wreck, SceneTransform)> wrecks,
) {
  final r2 = barrelBlastRadius * barrelBlastRadius;
  world.query2<CrabBody, SceneTransform>().having<Crab>().without<Dead>().each((
    entity,
    body,
    t,
  ) {
    final dx = t.x - at.x, dz = t.z - at.z;
    final d2 = dx * dx + dz * dz;
    if (d2 > r2) return;
    final d = math.max(math.sqrt(d2), 0.3);
    final falloff = 1 - 0.5 * d / barrelBlastRadius;
    world.emit(CrabDamaged(entity, barrelBlastDamage * falloff,
        DamageSource.explosion));
    body
      ..knockX = dx / d * barrelKnock
      ..knockZ = dz / d * barrelKnock
      ..knockTime = barrelKnockSeconds
      ..hitFromX = at.x
      ..hitFromZ = at.z;
  });
  if (world.query<SceneTransform>().having<Keeper>().firstOrNull case (
    _,
    final k,
  )) {
    if (distSq2(k.x, k.z, at.x, at.z) <=
        barrelKeeperRadius * barrelKeeperRadius) {
      world.emit(const KeeperStruck(1));
    }
  }
  if (world.tryResource<HeightGrid>() case final grid?) {
    world.tryResource<FireField>()?.igniteDisc(at.x, at.z, barrelFireRadius, grid);
  }
  for (final (_, wreck, t) in wrecks) {
    if (wreck.broken || wreck.kind != WreckKind.barrel) continue;
    if (distSq2(t.x, t.z, at.x, at.z) <= r2) _light(wreck, barrelChainFuse);
  }
}

/// Walking over a spill takes it: oil tops the lamp up, a heart heals.
void _collectPickups(World world) {
  final keeper = world.query2<Hearts, SceneTransform>().having<Keeper>().firstOrNull;
  final dt = world.dt;
  world.query2<Pickup, SceneTransform>().each((entity, pickup, t) {
    pickup.age += dt;
    if (pickup.age >= pickupSeconds) {
      world.despawn(entity);
      return;
    }
    if (keeper == null) return;
    final (k, hearts, kt) = keeper;
    if (distSq2(kt.x, kt.z, t.x, t.z) > pickupRadius * pickupRadius) return;
    switch (pickup.kind) {
      case PickupKind.oil:
        final lantern = world.tryGet<Lantern>(k);
        if (lantern == null || lantern.oil >= lanternOilMax) return;
        lantern.oil = math.min(lanternOilMax, lantern.oil + pickupOil);
      case PickupKind.heart:
        if (hearts.current >= hearts.max) return;
        hearts.current++;
    }
    world
      ..despawn(entity)
      ..emit(PickedUp(pickup.kind == PickupKind.heart, Vector3(t.x, t.y, t.z)));
  });
}
