part of '../wreckage.dart';

void installWreckScatter(GameBuilder game) {
  game.addSystem(
    OnEnter(GameStatus.night),
    _washUp,
    reads: {BrazierStand, SceneTransform},
  );
}

/// The tide brings in the night's wreckage: a seeded Poisson-disc scatter
/// over the whole island, kept to low dry ground by the shore.
void _washUp(World world) {
  final grid = world.tryResource<HeightGrid>();
  final anchors = world.tryResource<IslandAnchors>();
  if (grid == null || anchors == null) return;
  final night = world.tryResource<Run>()?.night ?? 1;
  final seed = (world.tryResource<RunSeed>()?.fixed ?? 7) * 97 + night;
  final braziers = [
    for (final (_, _, t) in world.query2<BrazierStand, SceneTransform>().snapshot())
      (t.x, t.z),
  ];
  final points = PoissonDiscSampler.sampleRect(
    gridCells * gridCellSize,
    gridCells * gridCellSize,
    wreckSpacing,
    seed: seed,
  );
  final rng = math.Random(seed);
  final want = wreckBase + night;
  var placed = 0;
  for (final p in points) {
    if (placed >= want) break;
    final x = gridOrigin + p.x, z = gridOrigin + p.y;
    final h = grid.sample(x, z);
    if (!grid.walkableXZ(x, z) || h < wreckMinHeight || h > wreckMaxHeight) {
      continue;
    }
    bool near(Vector3 a, double r) => distSq2(a.x, a.z, x, z) < r * r;
    if (near(anchors.lighthouse, wreckTowerClearance) ||
        near(anchors.keeperSpawn, wreckDoorClearance) ||
        braziers.any((b) =>
            distSq2(b.$1, b.$2, x, z) <
            wreckBrazierClearance * wreckBrazierClearance)) {
      continue;
    }
    final kind = rng.nextDouble() < wreckBarrelShare
        ? WreckKind.barrel
        : WreckKind.crate;
    world.spawn([
      Wreck(kind),
      SceneTransform(x, h, z)..setRotationY(rng.nextDouble() * math.pi * 2),
      const DespawnOnExit(GameStatus.night),
    ]);
    placed++;
  }
}
