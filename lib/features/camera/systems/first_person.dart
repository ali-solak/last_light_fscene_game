part of '../camera.dart';

void installFirstPerson(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _lookThroughEyes,
    reads: {Keeper, KeeperBody, SceneTransform},
    inSet: GameSets.camera,
    after: [_turnView],
    runIf: _inFirstPerson,
  );
}

bool _inFirstPerson(World world) => world.resource<CameraRig>().firstPerson;

/// First person: the eye rides the keeper's head, bobbing with his stride
/// and dipping when he lands; the view turns with the mouse.
void _lookThroughEyes(World world) {
  final rig = world.resource<CameraRig>();
  final dt = world.unscaledDelta;
  final keeper = world
      .query2<KeeperBody, SceneTransform>()
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
