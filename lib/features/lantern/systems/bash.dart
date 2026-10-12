part of '../lantern.dart';

void installLanternBash(GameBuilder game) {
  final night = inState(GameStatus.night);
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _swingLamp,
      writes: {Lantern},
      reads: {KeeperBrain, KeeperBody, SceneTransform, Keeper},
      inSet: GameSets.lantern,
      after: [_throwLamp],
      runIf: night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _rekindleLamp,
      writes: {Lantern},
      reads: {Keeper},
      // After the crabs take the strike, before pickups touch the oil.
      inSet: GameSets.damage,
      runIf: night.and(hasEvents<CrabBashed>()),
    );
}

/// F (or the wheel): swing the lamp in hand like a club, oil or none. The crabs feature
/// works out what it strikes (`LampBashed`).
void _swingLamp(World world) {
  final dt = world.dt;
  final row = world.query4<Lantern, KeeperBrain, KeeperBody, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (_, lantern, brain, body, t) = row;
  lantern
    ..bashCooldown = math.max(0, lantern.bashCooldown - dt)
    ..bashTime = math.max(0, lantern.bashTime - dt);
  final buffer = world.buffer<KeeperAction>();
  if (!buffer.has(KeeperAction.bash)) return;
  if (!lantern.lit || !brain.canAct || lantern.bashCooldown > 0) return;
  buffer.consume(KeeperAction.bash);
  lantern
    ..bashCooldown = lanternBashCooldown
    ..bashTime = lanternBashSwing;
  world.emit(LampBashed(
    Vector3(t.x, t.y + lanternHandHeight, t.z),
    yawDirX(body.facing),
    yawDirZ(body.facing),
  ));
}

/// Every crab the lamp strikes throws sparks back into it: oil, like a
/// flint catching.
void _rekindleLamp(World world) {
  final hits = world.events<CrabBashed>().length;
  world.query<Lantern>().having<Keeper>().each((_, lantern) {
    lantern.oil = math.min(lanternOilMax, lantern.oil + lanternBashKindle * hits);
  });
}
