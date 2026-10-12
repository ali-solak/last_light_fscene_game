part of '../defenses.dart';

void installDefenseBuild(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.dawnBoons), _sweepDefenses, reads: const {})
    ..addSystem(
      Schedules.fixedUpdate,
      _buildDefenses,
      writes: {SaltLine, Barricade},
      reads: {SceneTransform},
      inSet: GameSets.rules,
      runIf: inState(GameStatus.dawnBuild).and(hasEvents<BuildAt>()),
    );
}

/// Each dawn the salt has washed away and the barricades are cleared:
/// the supply is laid out fresh for every night.
void _sweepDefenses(World world) {
  world.entitiesWith<SaltLine>().each(world.despawn);
  world.entitiesWith<Barricade>().each(world.despawn);
}

/// Dawn build, with the salt (3) or barricade (4) tool: tap open ground to
/// lay one across the way to the tower; tap one to take it up; drag one to
/// turn it, 15° snaps.
void _buildDefenses(World world) {
  final run = world.resource<Run>();
  final grid = world.resource<HeightGrid>();
  final tool = world.resource<BuildSelection>().tool;
  final grab = world.resource<DefenseGrab>();
  final tower = world.resource<IslandAnchors>().lighthouse;
  var salts = world.entitiesWith<SaltLine>().count();
  var walls = world.entitiesWith<Barricade>().count();
  final placed = <(double, double)>[];

  Entity? near(double x, double z) => world
      .query<SceneTransform>()
      .having<Barricade>()
      .firstWhere((_, t) =>
          distSq2(t.x, t.z, x, z) <= defensePickRadius * defensePickRadius)
      ?.$1 ??
      world
          .query<SceneTransform>()
          .having<SaltLine>()
          .firstWhere((_, t) =>
              distSq2(t.x, t.z, x, z) <= defensePickRadius * defensePickRadius)
          ?.$1;

  bool open(double x, double z) {
    if (!grid.walkableXZ(x, z) || grid.sample(x, z) <= 0.2) return false;
    if (distSq2(x, z, tower.x, tower.z) <
        defenseTowerClearance * defenseTowerClearance) {
      return false;
    }
    final r2 = defenseSpacing * defenseSpacing;
    return !placed.any((p) => distSq2(p.$1, p.$2, x, z) < r2) &&
        !world.query<SceneTransform>().having<SaltLine>().any(
          (_, t) => distSq2(t.x, t.z, x, z) < r2,
        ) &&
        !world.query<SceneTransform>().having<Barricade>().any(
          (_, t) => distSq2(t.x, t.z, x, z) < r2,
        );
  }

  // Laid across the way to the tower.
  double across(double x, double z) =>
      wrapAngle(yawToward(tower.x - x, tower.z - z) + math.pi / 2);

  for (final at in world.events<BuildAt>()) {
    switch (at.phase) {
      case BuildPhase.tap:
        if (near(at.x, at.z) case final existing?) {
          if (world.has<SaltLine>(existing)) salts--;
          if (world.has<Barricade>(existing)) walls--;
          world.despawn(existing);
          continue;
        }
        if (!open(at.x, at.z)) continue;
        final y = grid.sample(at.x, at.z);
        if (tool == BuildTool.salt && salts < run.saltOwned) {
          salts++;
          placed.add((at.x, at.z));
          world.spawn([SaltLine(across(at.x, at.z)), SceneTransform(at.x, y, at.z)]);
        } else if (tool == BuildTool.barricade && walls < run.barricadesOwned) {
          walls++;
          placed.add((at.x, at.z));
          world.spawn([Barricade(across(at.x, at.z)), SceneTransform(at.x, y, at.z)]);
        }
      case BuildPhase.dragStart:
        grab.held = near(at.x, at.z);
      case BuildPhase.drag:
        final held = grab.held;
        final t = held == null ? null : world.tryGet<SceneTransform>(held);
        if (held == null || t == null) continue;
        final snap = defenseSnapDeg * degrees2Radians;
        final yaw = wrapAngle(
          (yawToward(at.x - t.x, at.z - t.z) / snap).round() * snap,
        );
        world.tryGet<SaltLine>(held)?.yaw = yaw;
        world.tryGet<Barricade>(held)?.yaw = yaw;
      case BuildPhase.dragEnd:
        grab.held = null;
    }
  }
}
