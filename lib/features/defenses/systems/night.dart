part of '../defenses.dart';

void installDefenseNight(GameBuilder game) {
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _wearDefenses,
      writes: {SaltLine, Barricade},
      reads: {SceneTransform},
      inSet: GameSets.rules,
      after: [_buildDefenses],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _paintObstacles,
      reads: {SaltLine, Barricade, SceneTransform},
      inSet: GameSets.lantern,
    );
}

/// Every step: the defenses as the horde sees them, cell by cell.
void _paintObstacles(World world) {
  final obstacles = world.resource<FlowObstacles>();
  final placed = !world.entitiesWith<SaltLine>().isEmpty ||
      !world.entitiesWith<Barricade>().isEmpty;
  if (!placed && !obstacles.painted) return;
  final before = obstacles.wall.fold(0, (n, w) => n + w) +
      obstacles.cost.where((c) => c > 0).length;
  obstacles
    ..clear()
    ..painted = placed;
  world.query2<SaltLine, SceneTransform>().each((_, salt, t) {
    if (salt.spent) return;
    _cells(t.x, t.z, salt.yaw, salt.length, saltWidth, (i) {
      obstacles.cost[i] = saltPathCost;
    });
  });
  world.query2<Barricade, SceneTransform>().each((_, wall, t) {
    if (wall.broken) return;
    _cells(t.x, t.z, wall.yaw, barricadeLength, barricadeThickness, (i) {
      obstacles.wall[i] = 1;
    });
  });
  final after = obstacles.wall.fold(0, (n, w) => n + w) +
      obstacles.cost.where((c) => c > 0).length;
  if (after != before) obstacles.dirty = true;
}

/// Calls [mark] for every cell within [width]/2 of the segment [length]
/// long through (x, z) along [yaw].
void _cells(
  double x,
  double z,
  double yaw,
  double length,
  double width,
  void Function(int i) mark,
) {
  final dx = yawDirX(yaw) * length / 2, dz = yawDirZ(yaw) * length / 2;
  final reach = length / 2 + width;
  final half = math.max(width / 2, gridCellSize * 0.5);
  for (var gz = gridZ(z - reach); gz <= gridZ(z + reach); gz++) {
    for (var gx = gridX(x - reach); gx <= gridX(x + reach); gx++) {
      if (!gridInside(gx, gz)) continue;
      final d = distToSegment(
        gridCenterX(gx),
        gridCenterZ(gz),
        x - dx,
        z - dz,
        x + dx,
        z + dz,
      );
      if (d <= half) mark(gz * gridCells + gx);
    }
  }
}

/// Crossing crabs wear salt away; bites chew barricades down; a broken
/// barricade bursts into splinters.
void _wearDefenses(World world) {
  final obstacles = world.resource<FlowObstacles>();
  world.query2<SaltLine, SceneTransform>().each((entity, salt, t) {
    var crossing = 0.0;
    _cells(t.x, t.z, salt.yaw, salt.length, saltWidth, (i) {
      crossing += obstacles.trodden[i];
      obstacles.trodden[i] = 0;
    });
    salt.strength -= crossing;
    if (salt.spent) world.despawn(entity);
  });
  world.query2<Barricade, SceneTransform>().each((entity, wall, t) {
    var bitten = 0.0;
    _cells(t.x, t.z, wall.yaw, barricadeLength, barricadeThickness, (i) {
      bitten += obstacles.chewed[i];
      obstacles.chewed[i] = 0;
    });
    if (bitten <= 0) return;
    wall.hp -= bitten;
    if (wall.broken) {
      world
        ..despawn(entity)
        ..emit(WreckBroken(false, Vector3(t.x, t.y, t.z)));
    }
  });
}
