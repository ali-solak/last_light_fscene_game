part of '../island.dart';

void installIslandBuild(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _buildIsland,
      reads: const {},
      inSet: GameSets.input,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _resolveAim,
      reads: const {},
      inSet: GameSets.input,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _resolveBuildPointer,
      reads: const {},
      inSet: GameSets.input,
      runIf: inState(GameStatus.dawnBuild).and(hasEvents<BuildPointer>()),
    );
}

/// Startup, headless: everything gameplay needs from `island.glb`.
void _buildIsland(World world) {
  final doc = world.resource<IslandAsset>().document;
  final grid = HeightGrid.fromTriangles(doc.triangles('collision'))
    ..paintGround(doc.triangles('ground'), doc.triangleUs('ground'));
  world.insert(grid);

  Vector3 at(String name) => doc.position(name) ?? Vector3.zero();

  final anchors = IslandAnchors();
  anchors.keeperSpawn.setFrom(at('keeper_spawn'));
  anchors.lighthouse.setFrom(at('lighthouse_anchor'));
  anchors.cottage.setFrom(at('cottage_anchor'));
  anchors.cottageYaw = doc.yaw('cottage_anchor');
  anchors.dock.setFrom(at('dock_anchor'));
  anchors.dockYaw = doc.yaw('dock_anchor');
  // The bell stands beside the cottage, in the cottage's own frame.
  final yaw = anchors.cottageYaw;
  final bx = anchors.cottage.x +
      yawRightX(yaw) * islandBellOffsetX +
      yawDirX(yaw) * islandBellOffsetZ;
  final bz = anchors.cottage.z +
      yawRightZ(yaw) * islandBellOffsetX +
      yawDirZ(yaw) * islandBellOffsetZ;
  anchors.bell.setValues(bx, grid.sample(bx, bz), bz);
  anchors.bellYaw = yaw;
  world.insert(anchors);

  world.insert(SpawnPoints([
    for (var i = 0; doc.hasNode('crab_spawn_$i'); i++) at('crab_spawn_$i'),
  ]));

  final occluders = Occluders([
    for (final piece in islandLayout)
      if (piece.kind == .rock) Occluder(piece.x, piece.z, piece.radius),
    Occluder(anchors.cottage.x, anchors.cottage.z, islandCottageRadius),
    Occluder(
      anchors.lighthouse.x,
      anchors.lighthouse.z,
      islandLighthouseRadius,
    ),
  ]);
  world.insert(occluders);
  // Rocks and buildings are solid: nothing walks through them.
  for (final o in occluders.circles) {
    grid.block(o.x, o.z, o.radius * islandSolidFraction);
  }

  for (var i = 1; doc.hasNode('mirror_pedestal_$i'); i++) {
    world.spawn(brazierStandBundle(i, at('mirror_pedestal_$i')));
  }
}

/// Resolves the controls' aim ray onto the ground.
void _resolveAim(World world) {
  final aim = world.resource<AimInput>();
  if (!aim.rayPending) return;
  aim.rayPending = false;
  final grid = world.tryResource<HeightGrid>();
  if (grid == null) return;
  final out = Vector3.zero();
  if (grid.raycast(aim.rayOrigin, aim.rayDirection, out)) {
    aim.setGroundPoint(out.x, out.y, out.z);
  }
}

/// Turns dawn-build pointer rays into ground positions.
void _resolveBuildPointer(World world) {
  final grid = world.resource<HeightGrid>();
  final out = Vector3.zero();
  for (final p in world.events<BuildPointer>()) {
    if (grid.raycast(p.origin, p.direction, out)) {
      world.emit(BuildAt(out.x, out.z, p.phase, fine: p.fine));
    }
  }
}
