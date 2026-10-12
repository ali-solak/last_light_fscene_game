part of '../keeper.dart';

void installKeeperMovement(GameBuilder game) {
  game.addSystem(
    Schedules.fixedUpdate,
    _moveKeeper,
    writes: {KeeperBody, SceneTransform},
    reads: {KeeperBrain, Harpoon, Keeper},
    inSet: GameSets.keeper,
    after: [_takeHits],
    runIf: inPlay,
  );
}

/// Camera-relative movement with acceleration; the jump's arc; Y from a
/// ground raycast (or the HeightGrid headless) plus the jump height; never
/// onto unwalkable cells.
void _moveKeeper(World world) {
  final row = world.query3<KeeperBody, KeeperBrain, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (entity, body, brain, t) = row;
  final dt = world.dt;
  final grid = world.tryResource<HeightGrid>();
  final lowTide = world.tryResource<TideLevel>()?.low ?? false;
  final axes = world.axes<KeeperAxis>();
  final (wx, wz) = _cameraRelative(
    world,
    axes.value(KeeperAxis.moveX),
    axes.value(KeeperAxis.moveY),
  );
  final wishLen = math.sqrt(wx * wx + wz * wz);
  final (ux, uz) = wishLen > 1 ? (wx / wishLen, wz / wishLen) : (wx, wz);
  final harpoon = world.tryGet<Harpoon>(entity);

  final state = brain.mode.state;
  if (state == KeeperMode.jumping) {
    // A little steering in the air.
    final step = keeperAcceleration * keeperAirControl * dt;
    final speed = math.max(
      keeperRunSpeed,
      math.sqrt(body.velocity.x * body.velocity.x +
          body.velocity.z * body.velocity.z),
    );
    if (wishLen > 0.01) {
      body.velocity
        ..x = moveToward(body.velocity.x, ux * speed, step)
        ..z = moveToward(body.velocity.z, uz * speed, step);
    }
  } else if (state == KeeperMode.reeling && harpoon?.reelSelfTo != null) {
    // Whaler's Reel: hauled toward the harpooned rock or mirror.
    final to = harpoon!.reelSelfTo!;
    final dx = to.x - t.x, dz = to.z - t.z;
    final d = math.sqrt(dx * dx + dz * dz);
    final v = d < 0.5 ? 0.0 : keeperReelSpeed;
    body.velocity.setValues(d > 1e-4 ? dx / d * v : 0, 0, d > 1e-4 ? dz / d * v : 0);
  } else {
    final reloading = harpoon?.mode.state == HarpoonMode.reloading;
    final factor = switch (state) {
      KeeperMode.idle || KeeperMode.moving when reloading =>
        keeperReloadSpeedFactor,
      KeeperMode.idle || KeeperMode.moving => 1.0,
      KeeperMode.focusing => keeperFocusSpeedFactor,
      KeeperMode.aiming => keeperAimSpeedFactor,
      _ => 0.0,
    };
    final step = keeperAcceleration * dt;
    body.velocity
      ..x = moveToward(body.velocity.x, ux * keeperRunSpeed * factor, step)
      ..z = moveToward(body.velocity.z, uz * keeperRunSpeed * factor, step);
  }

  // Move, sliding along an axis rather than onto unwalkable ground.
  final dx = body.velocity.x * dt, dz = body.velocity.z * dt;
  bool ok(double x, double z) =>
      grid == null ||
      grid.canWalk(t.x, t.z, x, z, lowTide: lowTide, lift: body.air);
  if (ok(t.x + dx, t.z + dz)) {
    t
      ..x += dx
      ..z += dz;
  } else if (ok(t.x + dx, t.z)) {
    t.x += dx;
  } else if (ok(t.x, t.z + dz)) {
    t.z += dz;
  }
  // The jump's arc over the ground.
  if (body.airborne) {
    body
      ..rise -= keeperGravity * dt
      ..air += body.rise * dt;
    body.apex = math.max(body.apex, body.air);
    if (body.air <= 0) {
      body
        ..air = 0
        ..rise = 0;
    }
  }
  body.sinceLanding += dt;
  t.y = _groundAt(world, grid, t) + body.air;

  // Holding the lamp up or aiming, he faces where the camera looks and
  // strafes; otherwise he turns the way he moves.
  final rig = world.tryResource<CameraRig>();
  final aim = world.resource<AimInput>();
  double? target;
  if (state == KeeperMode.focusing ||
      state == KeeperMode.aiming ||
      state == KeeperMode.reeling) {
    if (rig != null && aim.hasRay) {
      target = yawToward(rig.forwardX, rig.forwardZ);
    } else if (aim.valid) {
      target = yawToward(aim.point.x - t.x, aim.point.z - t.z);
    }
  } else if (body.velocity.length2 > 0.09) {
    target = yawToward(body.velocity.x, body.velocity.z);
  }
  // Through his eyes he always faces where the player looks.
  if (rig != null && rig.firstPerson) {
    body.facing = yawToward(rig.forwardX, rig.forwardZ);
  } else if (target != null) {
    body.facing = turnToward(body.facing, target, keeperTurnRate * dt);
  }
  t.setRotationY(body.facing);
}

/// Grounding: a Rapier ray down to the ground layer, else the HeightGrid.
double _groundAt(World world, HeightGrid? grid, SceneTransform t) {
  final fallback = grid?.sample(t.x, t.z) ?? t.y;
  final physics = world.tryResource<PhysicsWorld>();
  if (physics == null) return fallback;
  final hit = raycastLayers(
    physics,
    Ray.originDirection(
      Vector3(t.x, fallback + keeperGroundProbe, t.z),
      Vector3(0, -1, 0),
    ),
    keeperGroundReach,
    Layers.ground,
  );
  return hit?.worldPoint.y ?? fallback;
}
