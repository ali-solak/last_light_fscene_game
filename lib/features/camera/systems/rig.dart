part of '../camera.dart';

void installCameraRig(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _driveCamera,
      reads: {Keeper, KeeperBrain, KeeperBody, SceneTransform},
      inSet: GameSets.camera,
    )
    ..addSystem(
      Schedules.update,
      _shakeCamera,
      reads: const {},
      inSet: GameSets.camera,
      after: [_driveCamera],
    )
    ..addSystem(
      Schedules.startup,
      _spawnCamera,
      reads: const {},
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.renderSync,
      _placeCamera,
      writes: {CameraView},
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.renderSync,
      _faceCamera,
      reads: {Billboard, NodeRef, CameraView},
      after: [_placeCamera],
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.renderSync,
      _fadeOccluders,
      writes: {NodeRef},
      reads: {CameraFade},
      after: [_placeCamera, _faceCamera],
      runIf: hasResource<Scene>(),
    );
}

/// Follow the keeper at night, frame the island at dawn, orbit the title.
void _driveCamera(World world) {
  final rig = world.resource<CameraRig>();
  final dt = world.unscaledDelta;
  final status = world.state<GameStatus>();
  final centre = world.tryResource<IslandAnchors>()?.lighthouse ?? Vector3.zero();

  // Aiming pulls the camera in over the shoulder.
  final mode = world.query<KeeperBrain>().having<Keeper>().firstOrNull?.$2
      .mode.state;
  final aimGoal = switch (mode) {
    KeeperMode.aiming => 1.0,
    KeeperMode.focusing => cameraFocusAim,
    _ => 0.0,
  };
  rig.aim += (aimGoal - rig.aim) * smoothBlend(dt, cameraAimHalfLife);
  final sideGoal = mode == KeeperMode.focusing ? -1.0 : 1.0;
  rig.side += (sideGoal - rig.side) * smoothBlend(dt, cameraSideHalfLife);
  final following0 = status == GameStatus.night || status == GameStatus.dusk;
  // (Only with a picture to look through: headless runs aim by point.)
  final wasFirstPerson = rig.firstPerson;
  rig.firstPerson = following0 &&
      world.hasResource<Scene>() &&
      !(world.tryResource<Settings>()?.thirdPerson ?? false);
  // Into his eyes looking out, not down at the orbit camera's angle.
  if (rig.firstPerson && !wasFirstPerson) {
    rig.pitch = fpStartPitchDeg * degrees2Radians;
  }
  final look = (rig.firstPerson ? fpLookSensitivity : cameraLookSensitivity) *
      (1 - (1 - cameraAimLookScale) * rig.aim);
  final (pitchMin, pitchMax) = rig.firstPerson
      ? (-fpPitchLimitDeg, fpPitchLimitDeg)
      : (cameraPitchMinDeg, cameraPitchMaxDeg);

  // The player's zoom and orbit.
  final input = world.resource<CameraInput>();
  rig
    ..zoom = (rig.zoom * (1 + input.zoom * cameraZoomStep))
        .clamp(cameraZoomMin, cameraZoomMax)
    ..yawGoal += input.orbit +
        input.lookX * look +
        input.orbitRate * cameraOrbitDegPerSecond * degrees2Radians * dt
    ..pitch = (rig.pitch + input.lookY * look).clamp(
      pitchMin * degrees2Radians,
      pitchMax * degrees2Radians,
    );
  input
    ..zoom = 0
    ..orbit = 0
    ..lookX = 0
    ..lookY = 0;
  // First person turns exactly with the mouse; third person eases.
  rig.yaw = rig.firstPerson
      ? rig.yawGoal
      : rig.yaw +
            angleDelta(rig.yaw, rig.yawGoal) *
                smoothBlend(dt, cameraOrbitHalfLife);

  final (pitch, distance, halfLife, yaw) = switch (status) {
    GameStatus.title || GameStatus.won || GameStatus.lost => (
      cameraTitlePitchDeg,
      cameraTitleDistance,
      cameraOverviewHalfLife,
      rig.orbit += cameraTitleOrbitDegPerSecond * degrees2Radians * dt,
    ),
    GameStatus.dawnBoons || GameStatus.dawnBuild => (
      cameraOverviewPitchDeg,
      cameraOverviewDistance * rig.zoom,
      cameraOverviewHalfLife,
      rig.yaw,
    ),
    _ => (
      rig.pitch * radians2Degrees,
      cameraDistance * rig.zoom,
      cameraFollowHalfLife,
      rig.yaw,
    ),
  };

  final goal = Vector3.copy(centre);
  final following = status == GameStatus.night || status == GameStatus.dusk;
  rig.following = following;
  if (following) {
    final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;
    if (keeper != null) {
      final k = keeper.$2;
      goal.setValues(k.x, k.y + cameraLookHeight, k.z);
    }
  }
  rig.target.smoothToward(goal, dt, halfLife);

  // Spherical placement behind the target: yaw 0 looks along +Z.
  final p = pitch * degrees2Radians;
  final fx = math.sin(yaw), fz = math.cos(yaw);
  final eye = Vector3(
    rig.target.x - fx * math.cos(p) * distance,
    rig.target.y + math.sin(p) * distance,
    rig.target.z - fz * math.cos(p) * distance,
  );
  if (rig.firstPerson) {
    _eyes(world, rig, dt);
    return;
  }
  if (following) {
    rig.position.setFrom(eye);
    // Tilt up over rising ground behind him rather than pushing in.
    var need = 0.0;
    if (world.tryResource<HeightGrid>() case final grid?) {
      final length = distance * (1 - (1 - cameraAimArm) * rig.aim);
      for (final f in const [0.5, 0.75, 1.0]) {
        final d = length * f;
        final x = rig.target.x - fx * math.cos(p) * d;
        final z = rig.target.z - fz * math.cos(p) * d;
        final floor = math.max(grid.sample(x, z), 0) + cameraGroundClearance;
        final rise = (floor - rig.target.y) / d;
        if (rise > math.sin(p)) {
          need = math.max(need, math.asin(rise.clamp(-1.0, 0.95)) - p);
        }
      }
    }
    rig.lift += (need - rig.lift) * smoothBlend(dt, cameraLiftHalfLife);
  } else {
    rig.position.smoothToward(eye, dt, halfLife);
  }
  final hx = rig.target.x - rig.position.x, hz = rig.target.z - rig.position.z;
  final hl = math.sqrt(hx * hx + hz * hz);
  if (hl > 1e-4) {
    rig
      ..forwardX = hx / hl
      ..forwardZ = hz / hl;
  }
}

/// First person: the eye rides the keeper's head, bobbing with his stride
/// and dipping when he lands; the view turns with the mouse.
void _eyes(World world, CameraRig rig, double dt) {
  final keeper = world.query2<KeeperBody, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (keeper == null) return;
  final (_, body, k) = keeper;
  final speed = math.sqrt(
    body.velocity.x * body.velocity.x + body.velocity.z * body.velocity.z,
  );
  final grounded = !body.airborne;
  // The stride: one up-down per step, at a natural cadence (capped, so a
  // sprint lengthens the stride instead of rattling the view).
  final steps = math.min(speed / fpStepLength, fpStepsMax);
  if (grounded) rig.bobPhase += steps * math.pi * dt;
  final amount = grounded ? (speed / 6).clamp(0.0, 1.0) : 0.0;
  final fx = math.sin(rig.yaw), fz = math.cos(rig.yaw);
  rig.right.setValues(fz, 0, -fx);
  final side = math.sin(rig.bobPhase) * fpBobSide * amount;
  final up = -math.cos(rig.bobPhase * 2).abs() * fpBobUp * amount;
  rig.bob.setValues(rig.right.x * side, up, rig.right.z * side);
  for (final landed in world.events<KeeperLanded>()) {
    rig.dip = math.min(0.25, rig.dip + landed.height * fpDipPerMetre + 0.03);
  }
  rig.dip = smoothTo(rig.dip, 0, dt, fpDipHalfLife);

  rig.position.setValues(
    k.x + rig.bob.x,
    k.y + fpEyeHeight + rig.bob.y - rig.dip,
    k.z + rig.bob.z,
  );
  final p = rig.pitch - rig.kick;
  rig.look.setValues(fx * math.cos(p), -math.sin(p), fz * math.cos(p));
  rig.target.setFrom(rig.position + rig.look * 4);
  // Through his eyes the aim is where he looks (the crosshair), whatever
  // drives the view: mouse, touch or pad.
  world.resource<AimInput>().setRay(rig.position, rig.look.normalized());
  rig
    ..forwardX = fx
    ..forwardZ = fz
    ..following = true
    ..lift = 0
    ..squeeze = 0;
}

/// Startup, visual: the camera node, active as soon as it mounts, and the
/// spring-arm boom that carries it at night.
void _spawnCamera(World world) {
  final component = CameraComponent(
    projection: PerspectiveProjection(fovRadiansY: cameraFovDeg * degrees2Radians),
    activateOnMount: true,
  );
  final node = Node(name: 'camera')..addComponent(component);
  final arm = SpringArmComponent(
    targetLength: cameraDistance,
    probeRadius: cameraArmProbe,
    targetOffset: Vector3.zero(),
    socketOffset: Vector3(cameraShoulder, 0, 0),
    minLength: cameraArmMin,
    layerMask: RenderLayers.world,
    inheritYaw: false,
    inheritPitch: false,
  );
  final boom = Node(name: 'camera_boom')..addComponent(arm);
  world
    ..spawn([CameraView(node, component, boom, arm), NodeRef(node)])
    ..spawn([NodeRef(boom)]);
}

/// Render sync: at night the spring arm carries the camera behind the
/// keeper's shoulder (pulling in when the world blocks it); otherwise the
/// camera takes the rig's pose. The shake rides on top either way.
void _placeCamera(World world) {
  final rig = world.resource<CameraRig>();
  world.query<CameraView>().each((_, view) {
    final aim = rig.following ? rig.aim : 0.0;
    if (rig.firstPerson) {
      if (view.component.projection case final PerspectiveProjection lens) {
        final focus = (aim / cameraFocusAim).clamp(0.0, 1.0);
        final aimed = ((aim - cameraFocusAim) / (1 - cameraFocusAim))
            .clamp(0.0, 1.0);
        final fov = fpFovDeg +
            (fpFocusFovDeg - fpFovDeg) * focus +
            (fpAimFovDeg - fpFocusFovDeg) * aimed;
        lens
          ..fovRadiansY = fov * degrees2Radians
          ..near = fpNear;
      }
      // Shake turns the head rather than moving it.
      view.arm.cameraNode = null;
      view.node.lookAtFrom(
        rig.position + rig.shake * 0.05,
        rig.position + rig.look + rig.shake * fpShakeTurn,
      );
      return;
    }
    if (view.component.projection case final PerspectiveProjection lens) {
      lens
        ..fovRadiansY =
            (cameraFovDeg + (cameraAimFovDeg - cameraFovDeg) * aim) *
            degrees2Radians
        ..near = 0.1;
    }
    if (rig.following) {
      final short = 1 - view.arm.currentLength / math.max(view.arm.targetLength, 1e-3);
      final want = short > cameraSqueezeStart
          ? (short - cameraSqueezeStart) * cameraSqueezeLift
          : 0.0;
      rig.squeeze += (want - rig.squeeze) *
          smoothBlend(world.unscaledDelta, cameraSqueezeHalfLife);
      view.boom.position = rig.target +
          rig.shake * 0.5 +
          Vector3(0, cameraAimRaise * aim, 0);
      view.arm
        ..cameraNode = view.node
        ..yaw = rig.yaw
        ..pitch = math.min(
          rig.pitch + rig.lift + rig.squeeze - rig.kick,
          cameraPitchMaxDeg * degrees2Radians,
        )
        ..targetLength =
            cameraDistance * rig.zoom * (1 - (1 - cameraAimArm) * aim)
        ..socketOffset.x =
            (cameraShoulder + (cameraAimShoulder - cameraShoulder) * aim) *
            rig.side;
    } else {
      view.arm.cameraNode = null;
      view.node.lookAtFrom(rig.position + rig.shake, rig.target + rig.shake * 0.5);
    }
  });
}

/// Trauma decays on wall time, so the shake keeps moving through hitstop.
void _shakeCamera(World world) {
  final rig = world.resource<CameraRig>();
  final dt = world.unscaledDelta;
  rig
    ..trauma = math.max(0, rig.trauma - cameraTraumaDecay * dt)
    ..shakeTime += dt
    ..kick = smoothTo(rig.kick, 0, dt, cameraKickHalfLife);
  final enabled = world.tryResource<Settings>()?.screenShake ?? true;
  final amount = enabled ? rig.trauma * rig.trauma * cameraShakeMetres : 0.0;
  final t = rig.shakeTime * cameraShakeFrequency;
  // Three incommensurate sines: cheap, smooth, never repeating visibly.
  rig.shake.setValues(
    amount * (math.sin(t * 1.0) + math.sin(t * 2.71) * 0.5) / 1.5,
    amount * (math.sin(t * 1.37 + 1) + math.sin(t * 3.11) * 0.5) / 1.5,
    amount * (math.sin(t * 0.83 + 2) + math.sin(t * 2.29) * 0.5) / 1.5,
  );
}

/// Render sync: scenery standing between the camera and the keeper hides,
/// so nothing blocks the view of the fight.
void _fadeOccluders(World world) {
  final rig = world.resource<CameraRig>();
  final status = world.state<GameStatus>();
  final following = status == GameStatus.night || status == GameStatus.dusk;
  final cx = rig.position.x, cz = rig.position.z;
  final tx = rig.target.x, tz = rig.target.z;
  final sight = math.sqrt((tx - cx) * (tx - cx) + (tz - cz) * (tz - cz));
  world.query2<CameraFade, NodeRef>().each((_, fade, ref) {
    var blocks = false;
    if (following) {
      final d = distToSegment(fade.x, fade.z, cx, cz, tx, tz);
      final toTarget = math.sqrt(
        (fade.x - tx) * (fade.x - tx) + (fade.z - tz) * (fade.z - tz),
      );
      blocks = d < fade.radius + cameraFadeMargin &&
          toTarget > fade.radius * 0.5 &&
          toTarget < sight + fade.radius;
    }
    ref.node.visible = !blocks;
  });
}

/// Render sync: world labels turn about Y to face the eye (a quad facing
/// +Z reads mirrored from behind otherwise).
void _faceCamera(World world) {
  final view = world.query<CameraView>().firstOrNull?.$2;
  if (view == null) return;
  final eye = view.node.globalTransform.getTranslation();
  world.query<NodeRef>().having<Billboard>().each((_, ref) {
    final node = ref.node;
    if (!node.visible) return;
    final p = node.globalTransform.getTranslation();
    node.rotation = Quaternion.axisAngle(
      Vector3(0, 1, 0),
      math.atan2(eye.x - p.x, eye.z - p.z),
    );
  });
}
