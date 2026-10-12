part of '../fire.dart';

void installFireSpread(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.night), _quenchFire, reads: const {})
    ..addSystem(OnEnter(GameStatus.dawnBoons), _quenchFire, reads: const {})
    ..addSystem(
      Schedules.fixedUpdate,
      _igniteFire,
      reads: const {},
      inSet: GameSets.lantern,
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _spreadFire,
      reads: const {},
      inSet: GameSets.lantern,
      after: [_igniteFire],
      runIf: inState(GameStatus.night),
    );
}

/// A new night (or the dawn) starts with no fire and the grass grown back.
void _quenchFire(World world) => world.resource<FireField>().reset();

/// What sets the grass alight: burning oil where it lands and a moth's
/// blast (and a powder barrel going up, from the wreckage).
void _igniteFire(World world) {
  final grid = world.tryResource<HeightGrid>();
  if (grid == null) return;
  final fire = world.resource<FireField>();
  // Spilled lamp oil burns wherever it lands, sand and rock included.
  for (final burst in world.events<LampShattered>()) {
    fire.igniteDisc(burst.position.x, burst.position.z, burst.radius, grid,
        oil: true);
  }
  for (final boom in world.events<MothExploded>()) {
    fire.igniteDisc(boom.position.x, boom.position.z, fireMothRadius, grid);
  }
}

/// Burning cells heat their grassy neighbours (more downwind), burn down,
/// and go out to scorched earth.
void _spreadFire(World world) {
  final grid = world.tryResource<HeightGrid>();
  if (grid == null) return;
  final fire = world.resource<FireField>();
  if (fire.count == 0) return;
  final wind = world.tryResource<Wind>();
  final dt = world.dt;
  final damp = 1 - fireStormDamp * (wind?.storm ?? 0);
  final heat = fireSpreadHeat * dt * damp;
  final wx = wind?.x ?? 0, wz = wind?.z ?? 0;

  var n = fire.count;
  for (var k = 0; k < n; k++) {
    final i = fire.active[k];
    final gx = i % gridCells, gz = i ~/ gridCells;
    for (var dz = -1; dz <= 1; dz++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dz == 0) continue;
        final nx = gx + dx, nz = gz + dz;
        if (!gridInside(nx, nz)) continue;
        final j = nz * gridCells + nx;
        if (grid.grass[j] == 0 || fire.scorched[j] == 1 || fire.burn[j] > 0) {
          continue;
        }
        final len = (dx != 0 && dz != 0) ? math.sqrt2 : 1.0;
        final along = (dx * wx + dz * wz) / len;
        final bias = (1 + along * fireWindBias).clamp(0.15, 1 + fireWindBias);
        if ((fire.heat[j] += heat * bias / len) >= 1) fire.ignite(j, grid);
      }
    }
  }

  // Burn down; compact the active list as cells go out.
  final burnDown = dt * (1 + fireStormDamp * (wind?.storm ?? 0));
  n = fire.count;
  var live = 0;
  for (var k = 0; k < n; k++) {
    final i = fire.active[k];
    fire.burn[i] -= burnDown;
    if (fire.burn[i] <= 0) {
      fire
        ..burn[i] = 0
        ..scorched[i] = 1;
      continue;
    }
    fire.active[live++] = i;
  }
  fire.count = live;
}
