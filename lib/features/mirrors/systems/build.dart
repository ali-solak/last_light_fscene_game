part of '../mirrors.dart';

void installMirrorBuild(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.dawnBoons), _resetMirrors, writes: {Mirror})
    ..addSystem(
      Schedules.fixedUpdate,
      _buildMirrors,
      writes: {Mirror},
      reads: {BrazierStand, PrismMirror, SceneTransform},
      inSet: GameSets.rules,
      runIf: inState(GameStatus.dawnBuild).and(hasEvents<BuildAt>()),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _steerMirrors,
      writes: {Mirror},
      reads: {SceneTransform, CaughtLight},
      inSet: GameSets.rules,
      after: [_dragHookedMirror],
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _easeMirrors,
      writes: {Mirror, Interactable},
      inSet: GameSets.rules,
      after: [_steerMirrors],
    );
}

/// A fresh run clears the mirrors.
void _resetMirrors(World world) {
  if (!(world.tryResource<Run>()?.fresh ?? true)) {
    world.query<Mirror>().each((_, mirror) => mirror.upright = true);
    return;
  }
  world.entitiesWith<Mirror>().each(world.despawn);
}

/// Dawn build: with the mirror tool, tap open ground to stand a mirror (up
/// to the run's supply); tap a mirror to pick it back up; drag from one
/// toward where its light should go, 15° snaps (1° with the fine
/// modifier).
void _buildMirrors(World world) {
  final run = world.resource<Run>();
  final grab = world.resource<MirrorGrab>();
  final grid = world.resource<HeightGrid>();
  final tool = world.resource<BuildSelection>().tool;
  // Spawns are deferred, so count this step's placements by hand.
  var standing = world.query<Mirror>().count();
  var prisms = world.entitiesWith<PrismMirror>().count();
  final placed = <(double, double)>[];
  for (final at in world.events<BuildAt>()) {
    switch (at.phase) {
      case BuildPhase.tap:
        if (_mirrorNear(world, at.x, at.z) case final existing?) {
          world.despawn(existing);
          standing--;
        } else if (tool == BuildTool.mirror &&
            standing < run.mirrorsOwned &&
            _openGround(world, grid, at.x, at.z, placed)) {
          standing++;
          placed.add((at.x, at.z));
          final y = grid.sample(at.x, at.z);
          final lighthouse = world.resource<IslandAnchors>().lighthouse;
          final throwYaw = _defaultThrow(
            at.x,
            at.z,
            lighthouse,
            world.tryResource<SpawnPoints>(),
          );
          world.spawn([
            Mirror(
              _facingFor(
                at.x - lighthouse.x,
                at.z - lighthouse.z,
                throwYaw,
              ),
              throwYaw: throwYaw,
            ),
            SceneTransform(at.x, y, at.z),
            Interactable(
              InteractKind.mirror,
              holdSeconds: mirrorTurnHold,
              range: mirrorInteractRange,
            ),
            if (prisms++ < run.prisms) const PrismMirror(),
          ]);
        }
      case BuildPhase.dragStart:
        grab.held = _mirrorNear(world, at.x, at.z);
      case BuildPhase.drag:
        final held = grab.held;
        final mirror = held == null ? null : world.tryGet<Mirror>(held);
        final t = held == null ? null : world.tryGet<SceneTransform>(held);
        if (mirror == null || t == null) continue;
        // Drag toward where the light should go.
        final snap = (at.fine ? mirrorFineSnapDeg : mirrorSnapDeg) *
            degrees2Radians;
        final raw = yawToward(at.x - t.x, at.z - t.z);
        mirror.throwYaw = wrapAngle((raw / snap).round() * snap);
      case BuildPhase.dragEnd:
        if (grab.held case final held?) world.emit(MirrorAimed(held));
        grab.held = null;
    }
  }
}

Entity? _mirrorNear(World world, double x, double z) => world
    .query2<Mirror, SceneTransform>()
    .firstWhere(
      (_, _, t) =>
          distSq2(t.x, t.z, x, z) <= mirrorPickRadius * mirrorPickRadius,
    )
    ?.$1;

/// Walkable dry ground, clear of the tower, the braziers and other mirrors.
bool _openGround(
  World world,
  HeightGrid grid,
  double x,
  double z,
  List<(double, double)> placed,
) {
  if (!grid.walkableXZ(x, z) || grid.sample(x, z) <= 0.2) return false;
  final tower = world.resource<IslandAnchors>().lighthouse;
  if (distSq2(x, z, tower.x, tower.z) <
      mirrorTowerClearance * mirrorTowerClearance) {
    return false;
  }
  bool near(double ox, double oz, double r) => distSq2(ox, oz, x, z) < r * r;
  for (final (px, pz) in placed) {
    if (near(px, pz, mirrorMinSpacing)) return false;
  }
  return !world.query2<Mirror, SceneTransform>().any(
        (_, _, t) => near(t.x, t.z, mirrorMinSpacing),
      ) &&
      !world.query<SceneTransform>().having<BrazierStand>().any(
        (_, t) => near(t.x, t.z, mirrorBrazierClearance),
      );
}

/// A new mirror throws the light at the nearest landing beach, so it works
/// the moment it stands.
double _defaultThrow(
  double px,
  double pz,
  Vector3 lighthouse,
  SpawnPoints? spawns,
) {
  var best = yawToward(px - lighthouse.x, pz - lighthouse.z);
  var bestD = double.infinity;
  for (final p in spawns?.points ?? const <Vector3>[]) {
    final d = distSq2(p.x, p.z, px, pz);
    if (d < bestD) (bestD, best) = (d, yawToward(p.x - px, p.z - pz));
  }
  final snap = mirrorSnapDeg * degrees2Radians;
  return wrapAngle((best / snap).round() * snap);
}

/// The facing that reflects light arriving along (inX, inZ) out along
/// [throwYaw]: the normal halfway between where it came from and where it
/// goes.
double _facingFor(double inX, double inZ, double throwYaw) {
  final l = math.sqrt(inX * inX + inZ * inZ);
  if (l < 1e-6) return throwYaw;
  final nx = -inX / l + yawDirX(throwYaw), nz = -inZ / l + yawDirZ(throwYaw);
  // Light thrown straight back: face it head on.
  if (nx * nx + nz * nz < 1e-8) return yawToward(-inX, -inZ);
  return yawToward(nx, nz);
}

/// Every mirror with a throw direction turns to bisect the light it holds
/// (or, holding none, the lighthouse's) and that direction.
void _steerMirrors(World world) {
  final lighthouse = world.tryResource<IslandAnchors>()?.lighthouse;
  world.query2<Mirror, SceneTransform>().each((entity, mirror, t) {
    final throwYaw = mirror.throwYaw;
    if (throwYaw == null || !mirror.upright) return;
    final caught = world.tryGet<CaughtLight>(entity);
    final (inX, inZ) = caught != null && caught.hold > 0
        ? (caught.inX, caught.inZ)
        : (t.x - (lighthouse?.x ?? 0), t.z - (lighthouse?.z ?? 0));
    mirror.targetYaw = _facingFor(inX, inZ, throwYaw);
  });
}

/// Yaw eases to its target; the interact hold follows the mirror's state.
void _easeMirrors(World world) {
  final dt = world.dt;
  world.query2<Mirror, Interactable>().each((_, mirror, interact) {
    final blend = smoothBlend(dt, mirrorEaseHalfLife);
    mirror.yaw = wrapAngle(
      mirror.yaw + angleDelta(mirror.yaw, mirror.targetYaw) * blend,
    );
    interact
      ..holdSeconds = mirror.upright ? mirrorTurnHold : mirrorRaiseHold
      ..continuous = mirror.upright
      ..verb = mirror.upright ? PromptVerb.aim : PromptVerb.raise;
  });
}
