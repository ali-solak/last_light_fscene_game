part of '../crabs.dart';

void installCrabDamage(GameBuilder game) {
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _applyLightDamage,
      writes: {Health, TarShell},
      reads: {LightExposure, Underground, ReflectsBeam, Burning, Dead, Kindling, Crab},
      inSet: GameSets.damage,
      runIf: _night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _applyCrabDamage,
      writes: {Health, CrabBrain, CrabBody},
      reads: {TarShell, Underground, Boss, Dead, SceneTransform, Shroud, Exposed, Keeper},
      inSet: GameSets.damage,
      after: [_applyLightDamage],
      runIf: _night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _killCrabs,
      writes: {CrabBrain},
      reads: {Crab, Health, CrabBody, SceneTransform, Keeper, Dead},
      inSet: GameSets.damage,
      after: [_applyCrabDamage],
      runIf: _night,
    );
}

/// Light damage from the exposure numbers, with the immunities: tar shells
/// until cracked, burrowers underground, glassbacks to the beam. Focus on a
/// tar shell for 1.5 s cracks it.
void _applyLightDamage(World world) {
  final dt = world.dt;
  final kindling = !world.entitiesWith<Kindling>().isEmpty;
  world.query2<Health, LightExposure>().having<Crab>().without<Dead>().each((
    entity,
    health,
    light,
  ) {
    if (light.beam) world.add(entity, const HitFlash(), removeAfter: 0.1);
    if (world.has<Underground>(entity)) return;

    final shell = world.tryGet<TarShell>(entity);
    if (shell != null && !shell.cracked) {
      shell.progress = (light.focusSeconds / crabShellCrackSeconds).clamp(
        0.0,
        1.0,
      );
      if (light.focusSeconds >= crabShellCrackSeconds) {
        shell
          ..cracked = true
          ..progress = 1;
        world.emit(ShellCracked(entity));
      }
      return;
    }

    var dps = light.dps;
    if (!world.has<ReflectsBeam>(entity)) dps += light.beamDps;
    if (kindling && light.dps > 0) {
      world.add(entity, const Burning(), removeAfter: crabKindlingSeconds);
    } else if (light.dps == 0 && world.has<Burning>(entity)) {
      dps += crabBurnDps;
    }
    health.current -= dps * dt;
  });
}

/// Discrete damage (harpoon, slams, blasts), with the same immunities.
void _applyCrabDamage(World world) {
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;
  for (final hit in world.events<CrabDamaged>()) {
    final e = hit.entity;
    final health = world.tryGet<Health>(e);
    if (health == null || world.has<Dead>(e)) continue;
    if (world.has<Underground>(e)) continue;
    if (world.tryGet<TarShell>(e) case final shell? when !shell.cracked) {
      continue;
    }
    if (hit.source == DamageSource.beam && world.has<ReflectsBeam>(e)) {
      continue;
    }
    health.current -= hit.source == DamageSource.harpoon
        ? hit.amount * harpoonFactor(world, e)
        : hit.amount;
    final body = world.get<CrabBody>(e);
    if (keeper != null) {
      body
        ..hitFromX = keeper.$2.x
        ..hitFromZ = keeper.$2.z;
    }
    final brain = world.get<CrabBrain>(e);
    final state = brain.mode.state;
    if (!world.has<Boss>(e) &&
        hit.source != DamageSource.light &&
        hit.source != DamageSource.burn &&
        (state == CrabMode.advancing || state == CrabMode.cowering)) {
      brain.mode.go(CrabMode.hit);
    }
  }
}

/// How hard the harpoon bites [crab]: deep exposed, a glance shrouded.
double harpoonFactor(World world, Entity crab) => world.has<Exposed>(crab)
    ? harpoonExposedFactor
    : (world.tryGet<Shroud>(crab)?.value ?? 0) > 0
    ? harpoonShroudedFactor
    : 1;

/// At 0 health: the Death clip, a tar splat, `CrabKilled`, and a despawn
/// once the corpse is done (the model goes back to the pool then).
void _killCrabs(World world) {
  final lib = world.resource<ModelLibrary>();
  world.query4<Crab, Health, CrabBrain, SceneTransform>()
      .without<Dead>()
      .each((entity, crab, health, brain, t) {
    if (health.current > 0) return;
    final body = world.get<CrabBody>(entity);
    final asset = crabStats[crab.type]!.asset;
    brain
      ..target = null
      ..mode.go(CrabMode.dying);
    world
      ..add(entity, const Dead())
      ..remove<Hooked>(entity)
      ..add(
        entity,
        DespawnAfter(lib.seconds(asset, 'Death') + crabCorpseSeconds),
      )
      ..emit(CrabKilled(
        entity,
        crab.type,
        Vector3(t.x, t.y, t.z),
        Vector3(body.hitFromX, t.y, body.hitFromZ),
      ))
      ..spawn(tarSplatBundle(t.x, t.y + 0.02, t.z, body.facing));
  });
}
