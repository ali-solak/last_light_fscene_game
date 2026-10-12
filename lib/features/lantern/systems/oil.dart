part of '../lantern.dart';

void installLanternOil(GameBuilder game) {
  game
    ..observe<Keeper>(onAdd: (world, entity, _) => world.add(entity, Lantern()))
    ..addSystem(
      Schedules.fixedUpdate,
      _burnOil,
      writes: {Lantern},
      reads: {KeeperBrain, KeeperBody, SceneTransform, Keeper, Flare},
      inSet: GameSets.lantern,
      runIf: inPlay,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _throwLamp,
      writes: {Lantern},
      reads: {KeeperBrain, SceneTransform, Smash, Keeper},
      inSet: GameSets.lantern,
      after: [_burnOil],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _flyLamp,
      writes: {ThrownLamp},
      inSet: GameSets.lantern,
      after: [_throwLamp],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      OnEnter(GameStatus.dawnBoons),
      _refillAtDawn,
      writes: {Lantern},
    );
}

/// Focus burns oil; standing in the lighthouse beam refills it.
void _burnOil(World world) {
  final dt = world.dt;
  final map = world.tryResource<LightMap>();
  final flares = !world.entitiesWith<Flare>().isEmpty;
  world.query3<Lantern, KeeperBrain, SceneTransform>().having<Keeper>().each((
    entity,
    lantern,
    brain,
    t,
  ) {
    lantern
      ..away = math.max(0, lantern.away - dt)
      ..throwTime = math.max(0, lantern.throwTime - dt);
    final focusing =
        brain.mode.state == KeeperMode.focusing && lantern.oil > 0 && lantern.lit;
    // Flare: letting a held focus go spends a gulp of oil in one burst.
    if (flares &&
        lantern.focusing &&
        !focusing &&
        lantern.focusTime >= lanternFlareHold &&
        lantern.oil >= lanternFlareOil) {
      final facing = world.tryGet<KeeperBody>(entity)?.facing ?? 0;
      lantern.oil -= lanternFlareOil;
      world.emit(LampFlare(
        Vector3(t.x, t.y + lanternHandHeight, t.z),
        yawDirX(facing),
        yawDirZ(facing),
      ));
    }
    lantern.focusing = focusing;
    if (focusing) {
      lantern
        ..oil = math.max(0, lantern.oil - lanternFocusDrain * dt)
        ..focusTime += dt;
    } else {
      lantern.focusTime = 0;
    }
    if (map != null && map.beamAt(t.x, t.z)) {
      lantern.oil = math.min(lanternOilMax, lantern.oil + lanternBeamRefill * dt);
    }
  });
}

/// Q: throw the lamp at the aim. It arcs there (see [_flyLamp]); a new
/// one is lit after a while. Smash: a bigger burst, a quicker relight.
void _throwLamp(World world) {
  final buffer = world.buffer<KeeperAction>();
  if (!buffer.has(KeeperAction.throwLamp)) return;
  final row = world.query3<Lantern, KeeperBrain, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (_, lantern, brain, t) = row;
  if (!lantern.lit || !brain.canAct) return;
  buffer.consume(KeeperAction.throwLamp);
  final smash = !world.entitiesWith<Smash>().isEmpty;
  final aim = world.resource<AimInput>();
  var (x, z) = aim.valid ? (aim.point.x, aim.point.z) : (t.x, t.z);
  final dx = x - t.x, dz = z - t.z;
  final d = math.sqrt(dx * dx + dz * dz);
  if (d > lanternThrowRange) {
    (x, z) = (t.x + dx / d * lanternThrowRange, t.z + dz / d * lanternThrowRange);
  }
  final y = math.max(world.tryResource<HeightGrid>()?.sample(x, z) ?? t.y, 0.0);
  lantern
    ..away = smash ? lanternSmashAway : lanternAwaySeconds
    ..throwTime = lanternThrowAnimSeconds;
  world.spawn([
    ThrownLamp(
      Vector3(t.x, t.y + 1.4, t.z),
      Vector3(x, y, z),
      smash ? lanternSmashRadius : lanternPuddleRadius,
    ),
    const DespawnOnExit(GameStatus.night),
  ]);
}

/// The lamp flies its arc; where it lands it bursts into burning oil.
void _flyLamp(World world) {
  final dt = world.dt;
  world.query<ThrownLamp>().each((entity, lamp) {
    lamp.age += dt;
    if (lamp.t < 1) return;
    final at = lamp.to;
    world
      ..despawn(entity)
      ..spawn([
        BurnPuddle(at.x, at.z, lamp.radius),
        SceneTransform(at.x, at.y + 0.03, at.z),
        DespawnAfter(lanternPuddleSeconds),
        const DespawnOnExit(GameStatus.night),
      ])
      ..emit(LampShattered(at.clone(), lamp.radius));
  });
}

/// Dawn tops the oil up; a fresh run fills it.
void _refillAtDawn(World world) {
  final fresh = world.tryResource<Run>()?.fresh ?? true;
  world.query<Lantern>().each((_, lantern) {
    lantern
      ..oil = fresh
          ? lanternOilMax
          : math.min(lanternOilMax, lantern.oil + lanternDawnRefill)
      ..away = 0
      ..focusing = false;
  });
}
