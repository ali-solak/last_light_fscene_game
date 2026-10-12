part of '../mirrors.dart';

void installMirrorNight(GameBuilder game) {
  final night = inState(GameStatus.night);
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _interactMirrors,
      writes: {Mirror},
      reads: {SceneTransform},
      inSet: GameSets.rules,
      after: [_buildMirrors],
      runIf: night.and(hasEvents<Interacted>()),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _toppleMirrors,
      writes: {Mirror},
      reads: {SceneTransform},
      inSet: GameSets.rules,
      after: [_interactMirrors],
      runIf: night.and(
        hasEvents<MirrorSlammed>().or(hasEvents<SlamLanded>()),
      ),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _aimHeldMirror,
      writes: {Mirror},
      reads: {KeeperBrain, SceneTransform, Keeper},
      inSet: GameSets.rules,
      after: [_toppleMirrors],
      runIf: night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _dragHookedMirror,
      writes: {Mirror},
      reads: {Harpoon, SceneTransform, Keeper},
      inSet: GameSets.rules,
      after: [_aimHeldMirror],
      runIf: night,
    );
}

/// Holding interact on an upright mirror aims it: its light swings round
/// to the way the keeper is looking, so he sends it by looking there.
void _aimHeldMirror(World world) {
  final row = world.query2<KeeperBrain, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (_, brain, k) = row;
  final target = brain.interacting;
  if (brain.mode.state != KeeperMode.interacting || target == null) return;
  final mirror = world.tryGet<Mirror>(target);
  final aim = world.resource<AimInput>();
  if (mirror == null || !mirror.upright || !aim.valid) return;
  final look = yawToward(aim.point.x - k.x, aim.point.z - k.z);
  final step = mirrorAimDegPerSecond * degrees2Radians * world.dt;
  if (mirror.throwYaw case final throwYaw?) {
    mirror.throwYaw = turnToward(throwYaw, look, step);
  } else {
    mirror.targetYaw = turnToward(mirror.targetYaw, look, step);
  }
}

/// Interact: an upright mirror swings its throw 45° toward the keeper's
/// aim; a toppled one is raised.
void _interactMirrors(World world) {
  for (final e in world.events<Interacted>()) {
    if (e.kind != InteractKind.mirror) continue;
    final mirror = world.tryGet<Mirror>(e.target);
    final t = world.tryGet<SceneTransform>(e.target);
    if (mirror == null || t == null) continue;
    if (!mirror.upright) {
      mirror.upright = true;
      world.emit(MirrorRaised(e.target));
      continue;
    }
    final want = yawToward(e.aimX - t.x, e.aimZ - t.z);
    final current = mirror.throwYaw ?? mirror.targetYaw;
    final turn = angleDelta(current, want);
    if (turn.abs() < 1e-3) continue;
    final step = mirrorTurnStepDeg * degrees2Radians;
    final next = wrapAngle(
      current + (turn.abs() < step ? turn : step * turn.sign),
    );
    if (mirror.throwYaw != null) {
      mirror.throwYaw = next;
    } else {
      mirror.targetYaw = next;
    }
    world.emit(MirrorAimed(e.target));
  }
}

/// A basher's slam on a mirror, or an area slam, topples it.
void _toppleMirrors(World world) {
  void topple(Entity entity) {
    final mirror = world.tryGet<Mirror>(entity);
    if (mirror == null || !mirror.upright) return;
    mirror.upright = false;
    world.emit(MirrorToppled(entity));
  }

  for (final e in world.events<MirrorSlammed>()) {
    topple(e.mirror);
  }
  for (final slam in world.events<SlamLanded>()) {
    final r2 = slam.toppleRadius * slam.toppleRadius;
    final hit = <Entity>[];
    world.query2<Mirror, SceneTransform>().each((entity, _, t) {
      if (distSq2(t.x, t.z, slam.position.x, slam.position.z) <= r2) {
        hit.add(entity);
      }
    });
    hit.forEach(topple);
  }
}

/// A mirror hooked by the harpoon swings its throw toward the keeper while
/// reeled.
void _dragHookedMirror(World world) {
  final row = world.query2<Harpoon, SceneTransform>().having<Keeper>().firstOrNull;
  if (row == null) return;
  final (_, harpoon, k) = row;
  if (harpoon.mode.state != HarpoonMode.reeling ||
      harpoon.hookKind != HarpoonTargetKind.mirror) {
    return;
  }
  final target = harpoon.hooked;
  final mirror = target == null ? null : world.tryGet<Mirror>(target);
  final t = target == null ? null : world.tryGet<SceneTransform>(target);
  if (mirror == null || t == null || !mirror.upright) return;
  final want = yawToward(k.x - t.x, k.z - t.z);
  final step = mirrorDragDegPerSecond * degrees2Radians * world.dt;
  if (mirror.throwYaw case final throwYaw?) {
    mirror.throwYaw = turnToward(throwYaw, want, step);
  } else {
    mirror.targetYaw = turnToward(mirror.targetYaw, want, step);
  }
}
