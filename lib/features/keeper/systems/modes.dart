part of '../keeper.dart';

void installKeeperModes(GameBuilder game) {
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _findInteractable,
      writes: {KeeperBrain},
      reads: {Interactable, SceneTransform, Keeper},
      inSet: GameSets.keeper,
      runIf: inPlay,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _keeperModes,
      writes: {KeeperBrain, KeeperBody, Hearts, SceneTransform},
      reads: {Harpoon, Lantern, Interactable, Crab, Dead, Keeper},
      inSet: GameSets.keeper,
      after: [_findInteractable],
      runIf: inPlay,
    )
    ..addSystem(
      Schedules.update,
      _restoreTimeScale,
      reads: const {},
      inSet: GameSets.feedback,
    );
}

/// The enabled interactable within its range that he is looking at (the
/// one nearest the aim), else the nearest.
void _findInteractable(World world) {
  final row = world.query2<KeeperBrain, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (_, brain, k) = row;
  // While one is held, keep it.
  if (brain.mode.state == KeeperMode.interacting) return;
  final aim = world.resource<AimInput>();
  Entity? best;
  var bestScore = double.infinity;
  world.query2<Interactable, SceneTransform>().each((entity, item, t) {
    if (!item.enabled) return;
    final d = distSq2(k.x, k.z, t.x, t.z);
    if (d > item.range * item.range) return;
    final score = math.sqrt(d) +
        (aim.valid ? math.sqrt(distSq2(aim.point.x, aim.point.z, t.x, t.z)) : 0);
    if (score < bestScore) (best, bestScore) = (entity, score);
  });
  brain.inReach = best;
}

/// The keeper's mode machine: timers, downed and respawn, jump, interact,
/// lantern focus, and the harpoon's aim and reel.
void _keeperModes(World world) {
  final row = world.query4<KeeperBrain, KeeperBody, Hearts, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (entity, brain, body, hearts, t) = row;
  final dt = world.dt;
  final mode = brain.mode..tick(dt);
  brain.invulnerable -= dt;
  body.jumpCooldown -= dt;

  final buffer = world.buffer<KeeperAction>();
  final buttons = world.buttons<KeeperAction>();
  final axes = world.axes<KeeperAxis>();
  final mx = axes.value(KeeperAxis.moveX), my = axes.value(KeeperAxis.moveY);
  final wantsMove = mx * mx + my * my > 0.01;

  switch (mode.state) {
    case KeeperMode.downed:
      if (mode.elapsed < keeperDownedSeconds) return;
      hearts.current = hearts.max;
      brain
        ..invulnerable = keeperHitInvuln
        ..mode.go(KeeperMode.idle);
      final spawn = world.tryResource<IslandAnchors>()?.keeperSpawn;
      if (spawn != null) t.setTranslationFrom(spawn);
      body.velocity.setZero();
      world.emit(const KeeperRespawned());
      return;
    case KeeperMode.hit:
      if (mode.elapsed >= keeperHitStagger) mode.go(KeeperMode.idle);
      return;
    case KeeperMode.jumping:
      if (mode.elapsed > 0.05 && !body.airborne) {
        mode.go(wantsMove ? KeeperMode.moving : KeeperMode.idle);
        body.sinceLanding = 0;
        world.emit(KeeperLanded(Vector3(t.x, t.y, t.z), body.apex));
      }
      return;
    case KeeperMode.interacting:
      final target = brain.interacting;
      final item = target == null ? null : world.tryGet<Interactable>(target);
      final released =
          !world.buttons<KeeperAction>().pressed(KeeperAction.interact);
      if (item == null || !item.enabled || wantsMove ||
          (item.continuous && released)) {
        brain.interacting = null;
        mode.go(KeeperMode.idle);
      } else if (!item.continuous && mode.elapsed >= brain.interactSeconds) {
        final aim = world.resource<AimInput>();
        world.emit(Interacted(
          target!,
          item.kind,
          aim.valid ? aim.point.x : t.x + yawDirX(body.facing),
          aim.valid ? aim.point.z : t.z + yawDirZ(body.facing),
        ));
        brain.interacting = null;
        mode.go(KeeperMode.idle);
      }
      return;
    default:
      break;
  }

  final harpoon = world.tryGet<Harpoon>(entity);
  final harpoonBusy = harpoon != null &&
      harpoon.mode.state != HarpoonMode.ready &&
      harpoon.mode.state != HarpoonMode.reloading;

  // Jump: from any free mode, or out of an aim.
  if ((brain.canAct || mode.state == KeeperMode.aiming) &&
      body.jumpCooldown <= 0 &&
      buffer.consume(KeeperAction.jump)) {
    _startJump(world, brain, body, t, mx, my);
    return;
  }

  // Interact with whatever is in reach.
  if (brain.canAct && brain.inReach != null &&
      buffer.consume(KeeperAction.interact)) {
    final item = world.tryGet<Interactable>(brain.inReach!);
    if (item != null && item.enabled) {
      brain
        ..interacting = brain.inReach
        ..interactSeconds = item.holdSeconds;
      mode.go(KeeperMode.interacting);
      return;
    }
  }

  // The harpoon drives aiming and reeling.
  if (harpoonBusy) {
    mode.go(switch (harpoon.mode.state) {
      HarpoonMode.reeling => KeeperMode.reeling,
      _ => KeeperMode.aiming,
    });
    return;
  }

  // Lantern focus: held, or toggled with the accessibility setting.
  final settings = world.tryResource<Settings>();
  if (settings?.holdToToggleFocus ?? false) {
    if (buffer.consume(KeeperAction.focus)) {
      brain.focusToggled = !brain.focusToggled;
    }
  } else {
    brain.focusToggled = false;
  }
  final lantern = world.tryGet<Lantern>(entity);
  final focus = (buttons.pressed(KeeperAction.focus) || brain.focusToggled) &&
      lantern != null &&
      lantern.oil > 0 &&
      lantern.lit;
  mode.go(focus
      ? KeeperMode.focusing
      : (wantsMove ? KeeperMode.moving : KeeperMode.idle));
}

void _startJump(
  World world,
  KeeperBrain brain,
  KeeperBody body,
  SceneTransform t,
  double mx,
  double my,
) {
  // Carry the run into the leap; from standing, hop the way he faces.
  var (dx, dz) = (yawDirX(body.facing), yawDirZ(body.facing));
  var carry = keeperJumpHop;
  if (mx * mx + my * my > 0.01) {
    (dx, dz) = _cameraRelative(world, mx, my);
    carry = keeperJumpCarry;
  }
  final len = math.sqrt(dx * dx + dz * dz);
  if (len > 1e-6) (dx, dz) = (dx / len, dz / len);
  final along = body.velocity.x * dx + body.velocity.z * dz;
  final speed = math.max(carry, along);
  body
    ..velocity.setValues(dx * speed, 0, dz * speed)
    ..rise = keeperJumpSpeed
    ..apex = 0
    ..jumpCooldown = keeperJumpCooldown;
  brain.mode.go(KeeperMode.jumping);

  // The close call: a crab within reach slows the world for a moment.
  final r2 = keeperCloseCallRadius * keeperCloseCallRadius;
  final close = world.query<SceneTransform>()
      .having<Crab>()
      .without<Dead>()
      .any((_, c) => distSq2(c.x, c.z, t.x, t.z) <= r2);
  if (close) {
    world.clock.timeScale = keeperSlowScale;
    world.resource<SlowMotion>()
      ..hold = keeperSlowSeconds
      ..recover = null;
  }
  world.emit(JumpStarted(Vector3(t.x, t.y, t.z), close));
}

/// Stick input to a world direction, relative to the camera.
(double, double) _cameraRelative(World world, double mx, double my) {
  final rig = world.tryResource<CameraRig>();
  final fx = rig?.forwardX ?? 0, fz = rig?.forwardZ ?? 1;
  // Screen-right in flutter_scene's view space is up × forward.
  final rx = fz, rz = -fx;
  return (rx * mx + fx * my, rz * mx + fz * my);
}

/// Wall-time slow motion: hold, then ease back to normal speed.
void _restoreTimeScale(World world) {
  final slow = world.resource<SlowMotion>();
  final dt = world.unscaledDelta;
  if (slow.hold > 0) {
    slow.hold -= dt;
    if (slow.hold <= 0) {
      slow.recover = GameTween.number(
        world.clock.timeScale,
        1,
        keeperSlowRecover,
      );
    }
    return;
  }
  final recover = slow.recover;
  if (recover == null) return;
  recover.tick(dt);
  world.clock.timeScale = recover.value;
  if (recover.finished) slow.recover = null;
}
