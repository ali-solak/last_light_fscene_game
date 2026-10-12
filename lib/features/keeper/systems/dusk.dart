part of '../keeper.dart';

void installKeeperDusk(GameBuilder game) {
  game.addSystem(
    OnEnter(GameStatus.dusk),
    _keeperAtDusk,
    writes: {SceneTransform, KeeperBody},
    reads: {Keeper},
  );
}

/// Dusk: the keeper takes his post on open ground a few metres out from
/// the tower toward the beach the first wave will land on, looking at it,
/// so the night opens on the sea it comes from, not on a wall.
void _keeperAtDusk(World world) {
  final anchors = world.tryResource<IslandAnchors>();
  final spawns = world.tryResource<SpawnPoints>();
  final grid = world.tryResource<HeightGrid>();
  final run = world.tryResource<Run>();
  if (anchors == null || spawns == null || grid == null || run == null) return;
  final landing = spawns.of(nightFirstBeach(run.night));
  if (landing.isEmpty) return;
  final beach = landing.reduce((a, b) => a + b) / landing.length.toDouble();
  final tower = anchors.lighthouse;
  final out = Vector2(beach.x - tower.x, beach.z - tower.z);
  if (out.length2 < 1e-6) return;
  out.normalize();
  final post = _openGroundNear(
    grid,
    tower.x + out.x * keeperPostDistance,
    tower.z + out.y * keeperPostDistance,
  );
  if (post == null) return;
  final (x, z) = post;
  final look = Vector2(beach.x - x, beach.z - z);

  world.query2<SceneTransform, KeeperBody>().having<Keeper>().each((_, t, body) {
    t.setTranslation(x, grid.sample(x, z), z);
    body
      ..velocity.setZero()
      ..facing = yawToward(look.x, look.y);
  });
  if (world.tryResource<CameraRig>() case final rig?) {
    rig
      ..yaw = math.atan2(look.x, look.y)
      ..yawGoal = rig.yaw;
  }
}

/// The walkable cell nearest (x, z) with walkable ground all round it,
/// searched outward ring by ring; null if there is none close.
(double, double)? _openGroundNear(HeightGrid grid, double x, double z) {
  final cx = gridIndexAt(x, z);
  if (cx < 0) return null;
  final gx = cx % gridCells, gz = cx ~/ gridCells;
  bool open(int ix, int iz) {
    for (var dz = -1; dz <= 1; dz++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = ix + dx, nz = iz + dz;
        if (nx < 0 || nz < 0 || nx >= gridCells || nz >= gridCells) {
          return false;
        }
        if (grid.walkable[nz * gridCells + nx] == 0) return false;
      }
    }
    return true;
  }

  for (var r = 0; r <= keeperPostSearch; r++) {
    for (var dz = -r; dz <= r; dz++) {
      for (var dx = -r; dx <= r; dx++) {
        if (math.max(dx.abs(), dz.abs()) != r) continue;
        if (open(gx + dx, gz + dz)) {
          return (gridCenterX(gx + dx), gridCenterZ(gz + dz));
        }
      }
    }
  }
  return null;
}
