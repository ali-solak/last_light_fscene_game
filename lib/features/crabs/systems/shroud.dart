part of '../crabs.dart';

void installCrabShroud(GameBuilder game) {
  game.addSystem(
    Schedules.fixedUpdate,
    _burnShrouds,
    writes: {Shroud},
    reads: {LightExposure, Exposed, Dead},
    inSet: GameSets.damage,
    before: [_applyCrabDamage],
    runIf: _night,
  );
}

/// The lamp burns the brine shroud off a crab (the focused lamp fast, its
/// glow slowly, the lighthouse beam hard); out of the light it grows back.
/// Burnt through, the crab is exposed for a few seconds (a timed tag) and
/// reels from the flash: harpoon it now.
void _burnShrouds(World world) {
  final dt = world.dt;
  world.query2<Shroud, LightExposure>().without<Dead>().each((
    entity,
    shroud,
    light,
  ) {
    if (world.has<Exposed>(entity)) {
      shroud.burning = false;
      return;
    }
    final burn = (light.focus ? crabShroudFocusBurn : 0) +
        (light.beam ? crabShroudBeamBurn : 0) +
        (!light.focus && light.lit ? crabShroudGlowBurn * light.intensity : 0);
    shroud.burning = burn > 0;
    shroud.value = burn > 0
        ? shroud.value - burn * dt
        : math.min(shroud.max, shroud.value + shroud.max * crabShroudRegrow * dt);
    if (shroud.value <= 0) _expose(world, entity, shroud);
  });
}

/// The shroud is through: it regrows from full later; for now the crab
/// is exposed (a timed tag) and reels from the flash.
void _expose(World world, Entity crab, Shroud shroud) {
  shroud.value = shroud.max;
  world
    ..add(crab, const Exposed(), removeAfter: crabExposedSeconds)
    ..add(crab, const Dazzled(), removeAfter: crabExposedStagger)
    ..emit(CrabExposed(crab));
}
