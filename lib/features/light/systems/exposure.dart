part of '../light.dart';

void installExposure(GameBuilder game) {
  game.addSystem(
    Schedules.fixedUpdate,
    _sampleExposure,
    writes: {LightExposure},
    reads: {SceneTransform, HotWick, Sunfire},
    inSet: GameSets.light,
    after: [_buildLightMap],
  );
}

/// Every lit-able entity samples the light map at its feet. Damage rates
/// are settled here (with the light boons), so crabs read only numbers.
void _sampleExposure(World world) {
  final map = world.resource<LightMap>();
  final hotWick = !world.entitiesWith<HotWick>().isEmpty;
  final sunfire = !world.entitiesWith<Sunfire>().isEmpty;
  final dt = world.dt;
  world.query2<LightExposure, SceneTransform>().each((_, x, t) {
    final i = gridIndexAt(t.x, t.z);
    final intensity = i < 0 ? 0.0 : map.intensity[i];
    final flags = i < 0 ? 0 : map.flags[i];
    x
      ..intensity = intensity
      ..flags = flags
      ..seconds = intensity > 0 ? x.seconds + dt : 0
      ..focusSeconds = flags & LightFlags.focus != 0 ? x.focusSeconds + dt : 0;

    var dps = 0.0;
    if (flags & LightFlags.focus != 0) {
      dps = lightFocusDps * (hotWick ? hotWickMultiplier : 1);
    } else if (intensity >= lightHurtThreshold &&
        flags & (LightFlags.lantern | LightFlags.lamp) != 0) {
      dps = lightWideDps;
    }
    if (flags & LightFlags.burn != 0) dps += lightBurnDps;
    x
      ..dps = dps
      ..beamDps = flags & LightFlags.beam == 0
          ? 0
          : lightBeamDps *
                (sunfire && flags & LightFlags.bounced != 0
                    ? sunfireMultiplier
                    : 1);
  });
}
