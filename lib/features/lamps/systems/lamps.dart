part of '../lamps.dart';

void installLampRules(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.dawnBoons), _resetLamps, writes: {LampPost})
    ..addSystem(
      Schedules.fixedUpdate,
      _buildLamps,
      writes: {SceneTransform},
      reads: {LampPost, BrazierStand},
      inSet: GameSets.lamps,
      runIf: inState(GameStatus.dawnBuild).and(hasEvents<BuildAt>()),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _snuffLamps,
      writes: {LampPost},
      reads: {SceneTransform},
      inSet: GameSets.lamps,
      after: [_buildLamps],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _relightLamps,
      writes: {LampPost, Interactable},
      reads: {SaltedWicks},
      inSet: GameSets.lamps,
      after: [_snuffLamps],
      runIf: inState(GameStatus.night),
    );
}

/// Dawn relights every lamp; a fresh run clears them.
void _resetLamps(World world) {
  if (world.tryResource<Run>()?.fresh ?? true) {
    world.entitiesWith<LampPost>().each(world.despawn);
    return;
  }
  world.query<LampPost>().each((_, lamp) {
    lamp
      ..lit = true
      ..dark = 0;
  });
}

List<Object> lampBundle(double x, double y, double z) => [
  LampPost(),
  SceneTransform(x, y, z),
  Interactable(
    InteractKind.lamp,
    holdSeconds: lampRelightHold,
    enabled: false,
    range: lampInteractRange,
    verb: PromptVerb.relight,
  ),
];

/// Dawn build: tap open walkable ground to place a lamp (3 m from others),
/// tap a lamp to remove it, drag a lamp to move it.
void _buildLamps(World world) {
  final run = world.resource<Run>();
  final grid = world.resource<HeightGrid>();
  final grab = world.resource<LampGrab>();

  bool nearBrazier(double x, double z) => world
      .query<SceneTransform>()
      .having<BrazierStand>()
      .any((_, t) =>
          distSq2(t.x, t.z, x, z) <=
          lampBrazierClearance * lampBrazierClearance);

  bool spaced(double x, double z, Entity? ignore) => !world
      .query<SceneTransform>()
      .having<LampPost>()
      .any((e, t) =>
          e != ignore &&
          distSq2(t.x, t.z, x, z) < lampMinSpacing * lampMinSpacing);

  Entity? lampAt(double x, double z) => world
      .query<SceneTransform>()
      .having<LampPost>()
      .firstWhere((_, t) =>
          distSq2(t.x, t.z, x, z) <= lampPickRadius * lampPickRadius)
      ?.$1;

  final tool = world.resource<BuildSelection>().tool;
  for (final at in world.events<BuildAt>()) {
    if (nearBrazier(at.x, at.z)) continue;
    switch (at.phase) {
      case BuildPhase.tap:
        if (lampAt(at.x, at.z) case final lamp?) {
          world.despawn(lamp);
        } else if (tool == BuildTool.lamp &&
            world.query<LampPost>().count() < run.lampsOwned &&
            grid.walkableXZ(at.x, at.z) &&
            grid.sample(at.x, at.z) > 0 &&
            spaced(at.x, at.z, null)) {
          world.spawn(lampBundle(at.x, grid.sample(at.x, at.z), at.z));
        }
      case BuildPhase.dragStart:
        grab.held = lampAt(at.x, at.z);
      case BuildPhase.drag:
        final held = grab.held;
        final t = held == null ? null : world.tryGet<SceneTransform>(held);
        if (t == null ||
            !grid.walkableXZ(at.x, at.z) ||
            grid.sample(at.x, at.z) <= 0 ||
            !spaced(at.x, at.z, held)) {
          continue;
        }
        t.setTranslation(at.x, grid.sample(at.x, at.z), at.z);
      case BuildPhase.dragEnd:
        grab.held = null;
    }
  }
}

/// Spit and moth blasts put one lamp out; slams put out lamps around them.
void _snuffLamps(World world) {
  void snuff(Entity entity) {
    final lamp = world.tryGet<LampPost>(entity);
    if (lamp == null || !lamp.lit) return;
    lamp
      ..lit = false
      ..dark = 0;
    world.emit(LampSnuffed(entity));
  }

  for (final e in world.events<LampStruck>()) {
    snuff(e.lamp);
  }
  for (final slam in world.events<SlamLanded>()) {
    final r2 = slam.toppleRadius * slam.toppleRadius;
    final hit = <Entity>[];
    world.query2<LampPost, SceneTransform>().each((entity, _, t) {
      if (distSq2(t.x, t.z, slam.position.x, slam.position.z) <= r2) {
        hit.add(entity);
      }
    });
    hit.forEach(snuff);
  }
}

/// The keeper relights a lamp by holding interact; Salted Wicks relights
/// them on their own. Only dark lamps are interactable.
void _relightLamps(World world) {
  void relight(Entity entity, LampPost lamp) {
    lamp
      ..lit = true
      ..dark = 0;
    world.emit(LampRelit(entity));
  }

  for (final e in world.events<Interacted>()) {
    if (e.kind != InteractKind.lamp) continue;
    final lamp = world.tryGet<LampPost>(e.target);
    if (lamp != null && !lamp.lit) relight(e.target, lamp);
  }
  final salted = !world.entitiesWith<SaltedWicks>().isEmpty;
  final dt = world.dt;
  world.query2<LampPost, Interactable>().each((entity, lamp, interact) {
    if (!lamp.lit) {
      lamp.dark += dt;
      if (salted && lamp.dark >= lampSaltedWicksSeconds) relight(entity, lamp);
    }
    interact.enabled = !lamp.lit;
  });
}
