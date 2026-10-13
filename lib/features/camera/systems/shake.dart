part of '../camera.dart';

void installCameraShake(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _shakeCamera,
    reads: const {},
    inSet: GameSets.camera,
    after: [_lookThroughEyes, _liftOverGround],
  );
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
