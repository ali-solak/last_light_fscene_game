part of '../camera.dart';

void installCameraRig(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _poseForAim,
      reads: {Keeper, KeeperBrain},
      inSet: GameSets.camera,
    )
    ..addSystem(
      Schedules.update,
      _chooseView,
      reads: const {},
      inSet: GameSets.camera,
      after: [_poseForAim],
    )
    ..addSystem(
      Schedules.update,
      _turnView,
      reads: const {},
      inSet: GameSets.camera,
      after: [_chooseView],
    )
    ..addSystem(
      Schedules.update,
      _trackTarget,
      reads: {Keeper, SceneTransform},
      inSet: GameSets.camera,
      after: [_turnView],
      runIf: _inThirdPerson,
    )
    ..addSystem(
      Schedules.update,
      _placeOrbit,
      reads: const {},
      inSet: GameSets.camera,
      after: [_trackTarget],
      runIf: _inThirdPerson,
    )
    ..addSystem(
      Schedules.update,
      _liftOverGround,
      reads: const {},
      inSet: GameSets.camera,
      after: [_placeOrbit],
      runIf: _followingBehind,
    );
}

bool _inThirdPerson(World world) => !world.resource<CameraRig>().firstPerson;

bool _followingBehind(World world) {
  final rig = world.resource<CameraRig>();
  return rig.following && !rig.firstPerson;
}

/// The orbit camera's framing in each state: pitch (degrees), distance,
/// and how fast it settles. At night, the player's pitch and zoom.
(double pitchDeg, double distance, double halfLife) _framing(
  GameStatus status,
  CameraRig rig,
) => switch (status) {
  GameStatus.title || GameStatus.won || GameStatus.lost => (
    cameraTitlePitchDeg,
    cameraTitleDistance,
    cameraOverviewHalfLife,
  ),
  GameStatus.dawnBoons || GameStatus.dawnBuild => (
    cameraOverviewPitchDeg,
    cameraOverviewDistance * rig.zoom,
    cameraOverviewHalfLife,
  ),
  GameStatus.dusk || GameStatus.night => (
    rig.pitch * radians2Degrees,
    cameraDistance * rig.zoom,
    cameraFollowHalfLife,
  ),
};

/// Aiming pulls the camera in over the shoulder; focusing the lamp swaps
/// it to the other shoulder.
void _poseForAim(World world) {
  final rig = world.resource<CameraRig>();
  final dt = world.unscaledDelta;
  final mode = world
      .query<KeeperBrain>()
      .having<Keeper>()
      .firstOrNull
      ?.$2
      .mode
      .state;
  final aimGoal = switch (mode) {
    KeeperMode.aiming => 1.0,
    KeeperMode.focusing => cameraFocusAim,
    _ => 0.0,
  };
  rig.aim += (aimGoal - rig.aim) * smoothBlend(dt, cameraAimHalfLife);
  final sideGoal = mode == KeeperMode.focusing ? -1.0 : 1.0;
  rig.side += (sideGoal - rig.side) * smoothBlend(dt, cameraSideHalfLife);
}

/// At dusk and night the camera follows the keeper: through his eyes,
/// unless the settings ask for third person (and only with a picture to
/// look through; headless runs aim by point). Otherwise it frames the
/// island.
void _chooseView(World world) {
  final rig = world.resource<CameraRig>();
  final status = world.state<GameStatus>();
  rig.following = status == GameStatus.night || status == GameStatus.dusk;
  final wasFirstPerson = rig.firstPerson;
  rig.firstPerson =
      rig.following &&
      world.hasResource<Scene>() &&
      !(world.tryResource<Settings>()?.thirdPerson ?? false);
  // Into his eyes looking out, not down at the orbit camera's angle.
  if (rig.firstPerson && !wasFirstPerson) {
    rig.pitch = fpStartPitchDeg * degrees2Radians;
  }
}

/// The player's look, orbit and zoom, taken from [CameraInput]. First
/// person turns exactly with the mouse; third person eases. Away from the
/// keeper the title camera circles on its own.
void _turnView(World world) {
  final rig = world.resource<CameraRig>();
  final input = world.resource<CameraInput>();
  final dt = world.unscaledDelta;
  final look =
      (rig.firstPerson ? fpLookSensitivity : cameraLookSensitivity) *
      (1 - (1 - cameraAimLookScale) * rig.aim);
  final (pitchMin, pitchMax) = rig.firstPerson
      ? (-fpPitchLimitDeg, fpPitchLimitDeg)
      : (cameraPitchMinDeg, cameraPitchMaxDeg);
  rig
    ..zoom = (rig.zoom * (1 + input.zoom * cameraZoomStep)).clamp(
      cameraZoomMin,
      cameraZoomMax,
    )
    ..yawGoal +=
        input.orbit +
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
  rig.yaw = rig.firstPerson
      ? rig.yawGoal
      : rig.yaw +
            angleDelta(rig.yaw, rig.yawGoal) *
                smoothBlend(dt, cameraOrbitHalfLife);
  if (!rig.following) {
    rig.orbit += cameraTitleOrbitDegPerSecond * degrees2Radians * dt;
  }
}

/// Third person: look at the keeper while following, at the lighthouse
/// otherwise.
void _trackTarget(World world) {
  final rig = world.resource<CameraRig>();
  final goal = Vector3.copy(
    world.tryResource<IslandAnchors>()?.lighthouse ?? Vector3.zero(),
  );
  if (rig.following) {
    if (world.query<SceneTransform>().having<Keeper>().firstOrNull case (
      _,
      final k,
    )) {
      goal.setValues(k.x, k.y + cameraLookHeight, k.z);
    }
  }
  final (_, _, halfLife) = _framing(world.state<GameStatus>(), rig);
  rig.target.smoothToward(goal, world.unscaledDelta, halfLife);
}

/// Third person: the eye on a sphere round the target (yaw 0 looks along
/// +Z), held behind the keeper while following, eased everywhere else.
void _placeOrbit(World world) {
  final rig = world.resource<CameraRig>();
  final status = world.state<GameStatus>();
  final (pitchDeg, distance, halfLife) = _framing(status, rig);
  final yaw = switch (status) {
    GameStatus.title || GameStatus.won || GameStatus.lost => rig.orbit,
    _ => rig.yaw,
  };
  final p = pitchDeg * degrees2Radians;
  final eye = Vector3(
    rig.target.x - math.sin(yaw) * math.cos(p) * distance,
    rig.target.y + math.sin(p) * distance,
    rig.target.z - math.cos(yaw) * math.cos(p) * distance,
  );
  if (rig.following) {
    rig.position.setFrom(eye);
  } else {
    rig.position.smoothToward(eye, world.unscaledDelta, halfLife);
  }
  final hx = rig.target.x - rig.position.x, hz = rig.target.z - rig.position.z;
  final hl = math.sqrt(hx * hx + hz * hz);
  if (hl > 1e-4) {
    rig
      ..forwardX = hx / hl
      ..forwardZ = hz / hl;
  }
}

/// Following in third person: tilt up over rising ground behind him
/// rather than pushing in.
void _liftOverGround(World world) {
  final rig = world.resource<CameraRig>();
  final p = rig.pitch;
  final fx = math.sin(rig.yaw), fz = math.cos(rig.yaw);
  var need = 0.0;
  if (world.tryResource<HeightGrid>() case final grid?) {
    final length =
        cameraDistance * rig.zoom * (1 - (1 - cameraAimArm) * rig.aim);
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
  rig.lift +=
      (need - rig.lift) * smoothBlend(world.unscaledDelta, cameraLiftHalfLife);
}
