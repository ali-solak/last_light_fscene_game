part of '../crabs.dart';

void installCrabNavigation(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.night), _rebuildFlowField, reads: const {})
    ..addSystem(
      Schedules.fixedUpdate,
      _rebuildFlowField,
      reads: const {},
      inSet: GameSets.navigation,
      runIf: _night.and(every(0.25).or(_obstaclesMoved)),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _rebuildSpatialGrid,
      reads: {CrabBody, SceneTransform, Dead},
      inSet: GameSets.navigation,
      runIf: _night,
    );
}

/// Every 0.25 s (and on entering the night): Dijkstra from the lighthouse
/// base over terrain and light.
void _rebuildFlowField(World world) {
  final grid = world.tryResource<HeightGrid>();
  final anchors = world.tryResource<IslandAnchors>();
  if (grid == null || anchors == null) return;
  world.resource<FlowField>().rebuild(
    grid,
    world.tryResource<LightMap>(),
    centreX: anchors.lighthouse.x,
    centreZ: anchors.lighthouse.z,
    lowTide: world.resource<TideLevel>().low,
    obstacles: world.resource<FlowObstacles>()..dirty = false,
  );
}

/// Every step: live crabs bucketed for separation.
void _rebuildSpatialGrid(World world) {
  final grid = world.resource<SpatialGrid>()..clear();
  world
      .query2<CrabBody, SceneTransform>()
      .without<Dead>()
      .each((entity, body, t) => grid.add(
            entity,
            t.x,
            t.z,
            body.size,
            body.velocity.x,
            body.velocity.z,
          ));
}

/// The defenses changed: rebuild the flow at once.
bool _obstaclesMoved(World world) =>
    world.tryResource<FlowObstacles>()?.dirty ?? false;
