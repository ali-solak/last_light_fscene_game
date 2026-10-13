part of '../camera.dart';

void installCameraView(GameBuilder game) {
  game
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
    );
}

/// Startup, visual: the camera node, active as soon as it mounts, and the
/// spring-arm boom that carries it at night.
void _spawnCamera(World world) {
  final component = CameraComponent(
    projection: PerspectiveProjection(
      fovRadiansY: cameraFovDeg * degrees2Radians,
    ),
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
        final aimed = ((aim - cameraFocusAim) / (1 - cameraFocusAim)).clamp(
          0.0,
          1.0,
        );
        final fov =
            fpFovDeg +
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
      final short =
          1 - view.arm.currentLength / math.max(view.arm.targetLength, 1e-3);
      final want = short > cameraSqueezeStart
          ? (short - cameraSqueezeStart) * cameraSqueezeLift
          : 0.0;
      rig.squeeze +=
          (want - rig.squeeze) *
          smoothBlend(world.unscaledDelta, cameraSqueezeHalfLife);
      view.boom.position =
          rig.target + rig.shake * 0.5 + Vector3(0, cameraAimRaise * aim, 0);
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
      view.node.lookAtFrom(
        rig.position + rig.shake,
        rig.target + rig.shake * 0.5,
      );
    }
  });
}
