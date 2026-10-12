part of '../weather.dart';

void installSky(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _weatherLook,
    reads: const {},
    inSet: GameSets.feedback,
    runIf: hasResource<Scene>(),
  );
}

/// Visual: lightning (the island flashes, the clouds light from inside,
/// thunder shakes the camera a beat later), rain round the camera in a
/// storm, sea fog banks drifting past, and the wind and storm handed to
/// every shader that sways or drifts.
void _weatherLook(World world) {
  final weather = world.resource<Weather>();
  final wind = world.resource<Wind>();
  final scenery = world.resource<IslandScenery>();
  final rig = world.resource<CameraRig>();
  final fx = world.tryResource<Fx>();
  final dt = world.delta;
  final night = world.state<GameStatus>() == GameStatus.night;
  final rng = weather.rng;

  // Lightning, only in a storm and only at night.
  if (night && wind.storm > 0.5) {
    weather.nextBolt -= dt;
    if (weather.nextBolt <= 0) {
      weather
        ..flash = 1
        ..thunderIn = weatherThunderDelay * (0.5 + rng.nextDouble())
        ..nextBolt = weatherBoltMin +
            rng.nextDouble() * (weatherBoltMax - weatherBoltMin);
    }
  }
  if (weather.flash > 0) {
    weather.flash = math.max(0, weather.flash - dt / weatherFlashSeconds);
  }
  // A strike flickers: two pulses inside the flash.
  final f = weather.flash;
  scenery.flash = f * (0.6 + 0.4 * math.sin(f * 18).abs());
  if (weather.thunderIn > 0) {
    weather.thunderIn -= dt;
    if (weather.thunderIn <= 0) rig.addTrauma(weatherThunderTrauma);
  }

  // Shader inputs.
  if (world.tryResource<Materials>() case final materials?) {
    for (final m in materials.live) {
      setParam(m.parameters, 'wind', wind.force);
      setParam(m.parameters, 'storm', wind.storm);
    }
    if (materials.sky case final sky?) {
      setParam(sky.parameters, 'storm', wind.storm);
      setParam(sky.parameters, 'cloud_cover', 0.35 + 0.65 * wind.storm);
      setParam(sky.parameters, 'lightning', scenery.flash);
      if (sky.parameters.hasParameter('wind')) {
        sky.parameters.setVec2('wind', Vector2(wind.dirX, wind.dirZ));
      }
    }
  }

  if (fx == null) return;
  final eye = rig.position;

  // Rain, falling with the wind, in a box that rides with the camera.
  if (wind.storm > 0.3 && night) {
    weather.rainDebt += dt * weatherRainPerSecond * (wind.storm - 0.3) / 0.7;
    final n = weather.rainDebt.floor();
    weather.rainDebt -= n;
    final fall = Vector3(wind.x * 0.6, -1, wind.z * 0.6)..normalize();
    for (var i = 0; i < n; i++) {
      final at = Vector3(
        eye.x + (rng.nextDouble() - 0.5) * weatherRainBox * 2,
        eye.y + weatherRainHeight * (0.4 + rng.nextDouble() * 0.6),
        eye.z + (rng.nextDouble() - 0.5) * weatherRainBox * 2,
      );
      fx.burst(FxKind.rain, at, count: 1, dir: fall, spread: 0.02);
    }
  }

  // Sea fog: keep banks drifting round the camera at ground height.
  weather.fogTimer -= dt;
  if (weather.fogTimer <= 0 && fx[FxKind.fog].alive < weatherFogBanks) {
    weather.fogTimer = 0.35;
    final grid = world.tryResource<HeightGrid>();
    final a = rng.nextDouble() * math.pi * 2;
    final d = weatherFogNear + rng.nextDouble() * (weatherFogFar - weatherFogNear);
    final x = eye.x + math.cos(a) * d, z = eye.z + math.sin(a) * d;
    final y = math.max(grid?.sample(x, z) ?? 0, 0.0) + 0.8 + rng.nextDouble();
    final thick = night ? 1.0 : 0.5;
    fx.burst(
      FxKind.fog,
      Vector3(x, y, z),
      count: 1,
      dir: Vector3(wind.dirX, 0, wind.dirZ),
      spread: 0.3,
      size: thick * (1 + wind.storm * 0.4),
    );
  }
}
