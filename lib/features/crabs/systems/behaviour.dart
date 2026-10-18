part of '../crabs.dart';

void installCrabBehaviour(GameBuilder game) {
  game
    ..addSystem(
      Schedules.fixedUpdate,
      _landCrabs,
      writes: {CrabBrain, SceneTransform},
      reads: {CrabBody, Burrows},
      inSet: GameSets.crabs,
      runIf: _night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _reactToDodge,
      writes: {CrabBody},
      reads: {SceneTransform, Dead, Flashpoint, Undertow, BrineWave},
      inSet: GameSets.crabs,
      after: [_landCrabs],
      runIf: _night.and(hasEvents<JumpStarted>()),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _shoveAndFlare,
      writes: {CrabBody},
      reads: {SceneTransform, Dead, Crab},
      inSet: GameSets.crabs,
      after: [_reactToDodge],
      runIf: _night.and(hasEvents<CrabShoved>().or(hasEvents<LampFlare>())),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _takeBash,
      writes: {CrabBody, Shroud},
      reads: {SceneTransform, Dead, Crab, Boss, Exposed},
      inSet: GameSets.crabs,
      after: [_shoveAndFlare],
      runIf: _night.and(hasEvents<LampBashed>()),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _respondToLight,
      writes: {CrabBrain},
      reads: {LightExposure, FleesLight, CowerThreshold, Underground, Dazzled, Dead},
      inSet: GameSets.crabs,
      after: [_takeBash],
      runIf: _night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _chooseTargets,
      writes: {CrabBrain},
      reads: {SceneTransform, SnuffsLamps, KnocksMirrors, SeeksLight, LampPost, Mirror, Lantern, Keeper, KeeperBrain, Dead, Lure},
      inSet: GameSets.crabs,
      after: [_respondToLight],
      runIf: _night.and(every(0.25)),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _steerCrabs,
      writes: {CrabBody, SceneTransform, CrabBrain},
      reads: {
        Crab,
        LightExposure,
        KeeperBody,
        FleesLight,
        SeeksLight,
        HuntsKeeper,
        Keeper,
        KeeperBrain,
        Underground,
        Hooked,
        Slowed,
        Boss,
        Dead,
        Riptide,
        BrineLight,
        SaltRing,
      },
      inSet: GameSets.crabs,
      after: [_chooseTargets],
      runIf: _night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _climbCrabs,
      writes: {CrabBody, SceneTransform},
      reads: {CrabBrain, Boss, Dead},
      inSet: GameSets.crabs,
      after: [_steerCrabs],
      runIf: _night,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _crabAttacks,
      writes: {CrabBrain},
      reads: {Crab, CrabBody, SceneTransform, Keeper, KeeperBrain, Boss, Dead},
      inSet: GameSets.crabs,
      after: [_climbCrabs],
      runIf: _night,
    );
}

/// Ticks every crab's machine, then raises landing crabs out of the water.
void _landCrabs(World world) {
  final dt = world.dt;
  final grid = world.resource<HeightGrid>();
  world.query3<CrabBrain, CrabBody, SceneTransform>().each((
    entity,
    brain,
    body,
    t,
  ) {
    brain.mode.tick(dt);
    brain.cooldown -= dt;
    if (brain.mode.state != CrabMode.landing) return;
    final f = (brain.mode.elapsed / crabLandSeconds).clamp(0.0, 1.0);
    t.y = grid.sample(t.x, t.z) - crabLandDepth * (1 - f);
    if (f < 1) return;
    if (world.has<Burrows>(entity)) {
      _startSpecial(brain, 'Dig_In');
    } else {
      brain.mode.go(CrabMode.advancing);
    }
  });
}

/// Starts a special clip (gameplay times it from clips.json).
void _startSpecial(CrabBrain brain, String clip) {
  brain
    ..special = clip
    ..specialFired = false
    ..mode.go(CrabMode.special);
  // Re-entering `special` from `special` would be a no-op: restart time.
  if (!brain.mode.justEntered(CrabMode.special)) {
    brain.mode
      ..go(CrabMode.advancing)
      ..go(CrabMode.special);
  }
}

/// Dodge boons: Flashpoint dazzles, Undertow knocks back, Brine Wave slows.
void _reactToDodge(World world) {
  final flash = !world.entitiesWith<Flashpoint>().isEmpty;
  final undertow = !world.entitiesWith<Undertow>().isEmpty;
  final brineWave = undertow && !world.entitiesWith<BrineWave>().isEmpty;
  if (!flash && !undertow) return;
  for (final dodge in world.events<JumpStarted>()) {
    final kx = dodge.position.x, kz = dodge.position.z;
    world.query2<CrabBody, SceneTransform>().without<Dead>().each((
      entity,
      body,
      t,
    ) {
      final d2 = distSq2(t.x, t.z, kx, kz);
      if (flash && d2 <= crabFlashRadius * crabFlashRadius) {
        world.add(entity, const Dazzled(), removeAfter: crabFlashSeconds);
      }
      if (undertow && d2 <= crabUndertowRadius * crabUndertowRadius) {
        final d = math.max(math.sqrt(d2), 1e-3);
        final push = crabUndertowDistance / crabKnockSeconds;
        body
          ..knockX = (t.x - kx) / d * push
          ..knockZ = (t.z - kz) / d * push
          ..knockTime = crabKnockSeconds;
        if (brineWave) {
          world.add(entity, const Slowed(), removeAfter: crabBrineWaveSeconds);
        }
      }
    });
  }
}

/// A lashing chain flings crabs; a flare burns and dazzles every crab in
/// its short cone.
void _shoveAndFlare(World world) {
  for (final shove in world.events<CrabShoved>()) {
    final body = world.tryGet<CrabBody>(shove.crab);
    if (body == null || world.has<Dead>(shove.crab)) continue;
    body
      ..knockX = shove.dirX * shove.speed
      ..knockZ = shove.dirZ * shove.speed
      ..knockTime = crabKnockSeconds;
  }
  final cosHalf = math.cos(crabFlareHalfAngle);
  for (final flare in world.events<LampFlare>()) {
    final o = flare.origin;
    world.query2<CrabBody, SceneTransform>().having<Crab>().without<Dead>().each((
      entity,
      body,
      t,
    ) {
      final dx = t.x - o.x, dz = t.z - o.z;
      final d = math.sqrt(dx * dx + dz * dz);
      if (d > crabFlareRange + body.size * 0.5) return;
      if (d > 1 && (dx * flare.dirX + dz * flare.dirZ) / d < cosHalf) return;
      world
        ..emit(CrabDamaged(entity, crabFlareDamage, DamageSource.light))
        ..add(entity, const Dazzled(), removeAfter: crabFlareDazzle);
      final push = crabFlarePush / crabKnockSeconds;
      body
        ..knockX = dx / math.max(d, 0.3) * push
        ..knockZ = dz / math.max(d, 0.3) * push
        ..knockTime = crabKnockSeconds;
    });
  }
}

/// The swung lamp: every crab in the short arc in front of the keeper is
/// struck. It is knocked back (not the Tide Mother), set briefly alight,
/// and a chunk of its shroud is knocked away (enough to bare a scuttler);
/// one already exposed takes the hard hit. Each strike sends sparks back
/// into the lamp (`CrabBashed`).
void _takeBash(World world) {
  final cosHalf = math.cos(crabBashHalfAngle);
  for (final bash in world.events<LampBashed>()) {
    final o = bash.origin;
    world.query2<CrabBody, SceneTransform>().having<Crab>().without<Dead>().each((
      entity,
      body,
      t,
    ) {
      final dx = t.x - o.x, dz = t.z - o.z;
      final d = math.sqrt(dx * dx + dz * dz);
      if (d > crabBashRange + body.size * 0.5) return;
      if (d > 0.5 && (dx * bash.dirX + dz * bash.dirZ) / d < cosHalf) return;
      final exposed = world.has<Exposed>(entity);
      world
        ..emit(CrabDamaged(
          entity,
          crabBashDamage * (exposed ? crabBashExposedFactor : 1),
          DamageSource.bash,
        ))
        ..add(entity, const Burning(), removeAfter: crabBashBurnSeconds)
        ..emit(CrabBashed(
          entity,
          Vector3(t.x, t.y + body.size * 0.4, t.z),
          exposed,
        ));
      if (!exposed) {
        if (world.tryGet<Shroud>(entity) case final shroud?) {
          shroud.value -= crabBashShroud;
          if (shroud.value <= 0) _expose(world, entity, shroud);
        }
      }
      if (world.has<Boss>(entity)) return;
      final push = crabBashShove / crabKnockSeconds;
      final nx = d > 0.3 ? dx / d : bash.dirX, nz = d > 0.3 ? dz / d : bash.dirZ;
      body
        ..knockX = nx * push
        ..knockZ = nz * push
        ..knockTime = crabKnockSeconds;
    });
  }
}

/// Light-fleeing crabs cower in light at or above their threshold and stop;
/// out of the light for 0.3 s they advance again. Dazzled crabs cower too.
void _respondToLight(World world) {
  final dt = world.dt;
  world.query2<CrabBrain, LightExposure>().without<Dead>().each((
    entity,
    brain,
    light,
  ) {
    final state = brain.mode.state;
    if (state != CrabMode.advancing && state != CrabMode.cowering) return;
    if (world.has<Underground>(entity)) return;
    // Only a beam makes a crab cower, the lighthouse's or the lantern's
    // focus; the glow and lamps slow it instead (steering).
    final lit = (world.has<FleesLight>(entity) && (light.beam || light.focus)) ||
        world.has<Dazzled>(entity);
    if (lit) {
      brain.outOfLight = 0;
      if (state == CrabMode.advancing) brain.mode.go(CrabMode.cowering);
    } else if (state == CrabMode.cowering) {
      brain.outOfLight += dt;
      if (brain.outOfLight >= crabCowerRelease) {
        brain.mode.go(CrabMode.advancing);
      }
    }
  });
}

/// Snuffers seek lit lamps, bashers upright mirrors, moth crabs the
/// brightest light near them; the rest go to a wisp near them.
void _chooseTargets(World world) {
  final lures = [
    for (final (e, t) in world.query<SceneTransform>().having<Lure>().snapshot())
      (e, t.x, t.z),
  ];
  final lamps = <(Entity, double, double)>[];
  world.query2<LampPost, SceneTransform>().each((e, lamp, t) {
    if (lamp.lit) lamps.add((e, t.x, t.z));
  });
  final mirrors = <(Entity, double, double)>[];
  world.query2<Mirror, SceneTransform>().each((e, mirror, t) {
    if (mirror.upright) mirrors.add((e, t.x, t.z));
  });
  final keeper = world.query2<KeeperBrain, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  final keeperLit =
      keeper != null &&
      keeper.$2.mode.state != KeeperMode.downed &&
      (world.tryGet<Lantern>(keeper.$1)?.lit ?? false);

  Entity? nearest(List<(Entity, double, double)> from, double x, double z,
      double range) {
    Entity? best;
    var bestD = range * range;
    for (final (e, ex, ez) in from) {
      final d = distSq2(x, z, ex, ez);
      if (d <= bestD) (best, bestD) = (e, d);
    }
    return best;
  }

  world.query2<CrabBrain, SceneTransform>().without<Dead>().each((
    entity,
    brain,
    t,
  ) {
    if (world.has<SnuffsLamps>(entity)) {
      brain.target = nearest(lamps, t.x, t.z, crabSnufferSeek);
    } else if (world.has<KnocksMirrors>(entity)) {
      brain.target = nearest(mirrors, t.x, t.z, crabBasherSeek);
    } else if (world.has<SeeksLight>(entity)) {
      brain.target = nearest(lamps, t.x, t.z, crabMothSeek);
      if (brain.target == null &&
          keeperLit &&
          distSq2(t.x, t.z, keeper.$3.x, keeper.$3.z) <=
              crabMothSeek * crabMothSeek) {
        brain.target = keeper.$1;
      }
    } else {
      brain.target = nearest(lures, t.x, t.z, lanternLureRadius);
    }
  });
}

/// Advancing crabs follow the flow field (or their target), keep apart,
/// stay on walkable ground and scuttle sideways. Near the base they climb.
void _steerCrabs(World world) {
  final dt = world.dt;
  final grid = world.resource<HeightGrid>();
  final flow = world.resource<FlowField>();
  final spatial = world.resource<SpatialGrid>();
  final scratch = world.resource<CrabScratch>();
  final lowTide = world.resource<TideLevel>().low;
  final riptide = !world.entitiesWith<Riptide>().isEmpty;
  final brine = !world.entitiesWith<BrineLight>().isEmpty;
  final saltRing = !world.entitiesWith<SaltRing>().isEmpty;
  final nightTime = world.tryResource<Run>()?.nightTime ?? 0;
  final cx = flow.centreX, cz = flow.centreZ;
  final dir = scratch.dir;
  final obstacles = world.resource<FlowObstacles>();
  final lightMap = world.tryResource<LightMap>();
  final keeperRow = world.query3<KeeperBrain, SceneTransform, KeeperBody>()
      .having<Keeper>()
      .firstOrNull;
  final keeperDown =
      keeperRow == null || keeperRow.$2.mode.state == KeeperMode.downed;
  final keeper = keeperDown ? null : keeperRow.$3;
  final keeperBody = keeperDown ? null : keeperRow.$4;

  world.query4<CrabBrain, CrabBody, SceneTransform, LightExposure>()
      .without<Dead>()
      .each((entity, brain, body, t, light) {
    if (world.has<Hooked>(entity) || world.has<Boss>(entity)) return;
    final state = brain.mode.state;

    // Knockback rides on top of any mode but death: flung, then dazed.
    if (body.knockTime > 0) {
      body.knockTime -= dt;
      _moveOn(grid, t, body.knockX * dt, body.knockZ * dt, lowTide);
      t.y = grid.sample(t.x, t.z);
      if (body.knockTime <= 0) body.dazed = crabKnockDaze;
      body.velocity.setZero();
      return;
    }
    if (body.dazed > 0) {
      body.dazed -= dt;
      body.velocity.setZero();
      return;
    }

    // Mid-leap: fly the arc at the keeper, then land ready to bite.
    body.leapCooldown -= dt;
    if (body.leap > 0) {
      body.leap -= dt;
      _moveOn(grid, t, body.leapX * dt, body.leapZ * dt, lowTide);
      final f = 1 - (body.leap / crabLeapSeconds).clamp(0.0, 1.0);
      t.y = grid.sample(t.x, t.z) + crabLeapHeight * 4 * f * (1 - f);
      body.velocity.setValues(body.leapX, 0, body.leapZ);
      _face(body, dt);
      if (body.leap <= 0) {
        t.y = grid.sample(t.x, t.z);
        brain.cooldown = 0;
      }
      return;
    }

    // The attack's pounce: a short spring at the keeper as the claw drops.
    if (state == CrabMode.attacking) {
      final at = brain.attackAt;
      final e = brain.mode.elapsed;
      if (!body.lunged && e >= at - crabLungeLead && e <= at + 0.05) {
        final step = crabLungeSpeed * dt;
        _moveOn(grid, t, body.lungeX * step, body.lungeZ * step, lowTide);
        t.y = grid.sample(t.x, t.z);
        if (e >= at) body.lunged = true;
      }
      body.velocity.setZero();
      return;
    }
    if (state != CrabMode.advancing) {
      body.velocity.setZero();
      return;
    }

    final underground = world.has<Underground>(entity);
    var speed = underground ? crabBurrowSpeed : body.speed;
    // A beam bogs a hunter down (the rest cower in it); the lantern's glow
    // and lamps' light bog any crab down but a light-seeker.
    final hunter = world.has<HuntsKeeper>(entity);
    if (!underground) {
      if (light.beam || light.focus) {
        speed *= crabBeamSlow;
      } else if (light.intensity >= crabCowerThreshold &&
          !world.has<SeeksLight>(entity)) {
        speed *= crabLightSlow;
      }
    }
    if (brine && light.lit && !underground) speed *= crabBrineSlow;
    if (world.has<Slowed>(entity)) speed *= crabSlowFactor;

    // Desired direction: the target; the keeper when he is close and the
    // crab is not dazzled; otherwise the flow field.
    var stop = false;
    final target = brain.target;
    final tt = target == null ? null : world.tryGet<SceneTransform>(target);
    final aggro = hunter ? crabHunterAggroRadius : crabAggroRadius;
    final hunt = keeper != null &&
        !underground &&
        tt == null &&
        (hunter || light.intensity < crabCowerThreshold) &&
        distSq2(t.x, t.z, keeper.x, keeper.z) <= aggro * aggro;
    // The quarry the horde wheels round: what it is after.
    double qx = cx, qz = cz;
    if (tt != null && !underground) {
      (qx, qz) = (tt.x, tt.z);
      dir.setValues(tt.x - t.x, tt.z - t.z);
      final d = dir.length;
      if (d > 1e-4) dir.scale(1 / d);
      stop = d < body.size * 0.5;
    } else if (hunt) {
      (qx, qz) = (keeper.x, keeper.z);
      dir.setValues(keeper.x - t.x, keeper.z - t.z);
      final d = dir.length;
      if (d > 1e-4) dir.scale(1 / d);
      speed *= hunter ? crabHunterSpeed : crabHuntSpeed;
      // Close enough, out of the lighthouse beam: leap at where he is
      // heading, through his lantern's focus if need be.
      if (hunter &&
          body.leapCooldown <= 0 &&
          d >= crabLeapMin &&
          d <= crabLeapMax &&
          !light.beam &&
          keeperBody != null) {
        final reach = body.size * crabAttackReachFactor;
        final lx = keeper.x + keeperBody.velocity.x * crabLeapSeconds * 0.5;
        final lz = keeper.z + keeperBody.velocity.z * crabLeapSeconds * 0.5;
        final ox = lx - t.x, oz = lz - t.z;
        final od = math.max(math.sqrt(ox * ox + oz * oz), 1e-3);
        final travel = math.max(od - reach, 0.0);
        body
          ..leap = crabLeapSeconds
          ..leapX = ox / od * travel / crabLeapSeconds
          ..leapZ = oz / od * travel / crabLeapSeconds
          ..leapCooldown = crabLeapCooldownMin +
              scratch.rng.nextDouble() *
                  (crabLeapCooldownMax - crabLeapCooldownMin);
        world.emit(CrabLeapt(entity));
        return;
      }
    } else {
      flow.direction(t.x, t.z, dir, burrow: underground);
    }
    // The hurricane: closing in, everyone wheels the same way round the
    // quarry, so the mass circles and spirals in; but never wheels into a
    // beam.
    if (!underground && !stop) {
      final ox = qx - t.x, oz = qz - t.z;
      final d = math.sqrt(ox * ox + oz * oz);
      final w = crabSwirl *
          ((d - crabSwirlNear) / 2).clamp(0.0, 1.0) *
          ((crabSwirlFar - d) / 4).clamp(0.0, 1.0);
      if (w > 0) {
        var sx = dir.x - oz / d * w, sz = dir.y + ox / d * w;
        final len = math.sqrt(sx * sx + sz * sz);
        if (len > 1e-4) (sx, sz) = (sx / len, sz / len);
        final ahead = lightMap?.flagsAt(
              t.x + sx * crabSwirlLookAhead,
              t.z + sz * crabSwirlLookAhead,
            ) ??
            0;
        if (ahead & (LightFlags.beam | LightFlags.focus) == 0) {
          dir.setValues(sx, sz);
        }
      }
    }
    // Ease the wanted heading toward the new way (a fresh crab takes it
    // at once).
    final heading = body.heading;
    if (heading.length2 < 1e-6) {
      heading.setFrom(dir);
    } else {
      heading
        ..add((dir - heading)..scale(smoothBlend(dt, crabHeadingHalfLife)))
        ..normalize();
    }
    dir.setFrom(heading);

    // Salt underfoot slows and stings.
    final here = gridIndexAt(t.x, t.z);
    if (here >= 0 && obstacles.cost[here] > 0 && !underground) {
      speed *= crabSaltSlow;
      obstacles.trodden[here] += dt;
      world.emit(CrabDamaged(entity, crabSaltDps * dt, DamageSource.burn));
    }

    // A barricade in the way: chew it.
    body.chew -= dt;
    if (!underground) {
      final reach = body.size * 0.5 + 0.5;
      final ahead = gridIndexAt(t.x + dir.x * reach, t.z + dir.y * reach);
      if (ahead >= 0 && obstacles.wall[ahead] == 1) {
        body
          ..velocity.setZero()
          ..facing = yawToward(dir.x, dir.y);
        if (body.chew <= 0) {
          body.chew = crabChewCooldown;
          final crab = world.tryGet<Crab>(entity);
          obstacles.chewed[ahead] += crabChewBite *
              (crab?.type == CrabType.basher ? crabBasherChew : 1);
          _startSpecial(brain, 'Attack');
        }
        return;
      }
    }

    // Jammed against a wall or the crowd: sidestep along it for a moment.
    if (body.sidestep > 0) {
      body.sidestep -= dt;
      final a = crabSidestepAngle * body.sideSign;
      final c = math.cos(a), sn = math.sin(a);
      dir.setValues(dir.x * c - dir.y * sn, dir.x * sn + dir.y * c);
    }

    // The kit's steering: seek along the way, shove apart, fall in with
    // the neighbours' heading and close up on them, so the horde moves as
    // a mass.
    final n = body.sidestep > 0
        ? 0
        : spatial.near(t.x, t.z, crabNeighbourRadius, scratch.near);
    scratch.neighbours(spatial, n, entity);
    final pos = Vector3(t.x, 0, t.z);
    final vel = Vector3(body.velocity.x, 0, body.velocity.z);
    final force = stop
        ? -vel * crabSteerResponse
        : Steering.seek(
            pos,
            vel,
            pos + Vector3(dir.x, 0, dir.y) * 4,
            maxSpeed: speed,
            maxForce: crabSteerForce,
          );
    if (scratch.positions.isNotEmpty) {
      force
        ..add(Steering.separation(
              pos,
              vel,
              scratch.positions,
              desiredDistance: body.size * (1 + crabSeparation),
              maxSpeed: speed,
              maxForce: crabSteerForce,
            ) *
            crabSeparationWeight)
        ..add(Steering.alignment(
              vel,
              scratch.velocities,
              maxSpeed: speed,
              maxForce: crabSteerForce,
            ) *
            crabAlignmentWeight)
        ..add(Steering.cohesion(
              pos,
              vel,
              scratch.positions,
              maxSpeed: speed,
              maxForce: crabSteerForce,
            ) *
            crabCohesionWeight);
    }
    // The kit's forces are velocity corrections; ease toward them.
    vel.add(force * (crabSteerResponse * dt));
    if (vel.length > speed * 1.1) vel.scale(speed * 1.1 / vel.length);
    body.velocity.setValues(vel.x, 0, vel.z);
    var mx = body.velocity.x * dt, mz = body.velocity.z * dt;
    if (riptide && light.beam) {
      final ox = t.x - cx, oz = t.z - cz;
      final d = math.max(math.sqrt(ox * ox + oz * oz), 1e-3);
      mx += ox / d * crabRiptidePush * dt;
      mz += oz / d * crabRiptidePush * dt;
    }
    final fromX = t.x, fromZ = t.z;
    _moveOn(grid, t, mx, mz, lowTide, obstacles);
    t.y = grid.sample(t.x, t.z);
    _face(body, dt);

    // Getting nowhere (pinned, or circling a corner)? Sidestep, the other
    // way from last time.
    final moved = math.sqrt(distSq2(fromX, fromZ, t.x, t.z));
    if (!stop && moved < speed * dt * crabStuckShare) {
      body.stuck += dt;
    } else {
      body.stuck = math.max(0, body.stuck - dt);
    }
    final cell = gridIndexAt(t.x, t.z);
    final along = cell < 0
        ? double.infinity
        : (underground ? flow.burrowDist : flow.dist)[cell];
    if (along < body.bestFlow - 0.5) {
      body
        ..bestFlow = along
        ..noProgress = 0;
    } else if (tt == null && !hunt) {
      body.noProgress += dt;
    }
    if (body.sidestep <= 0 &&
        (body.stuck >= crabStuckSeconds ||
            body.noProgress >= crabNoProgressSeconds)) {
      body
        ..sidestep = crabSidestepSeconds
        ..sideSign = -body.sideSign
        ..stuck = 0
        ..noProgress = 0;
    }

    // At the base: climb (Salt Ring holds them off early in the night).
    if (!underground &&
        distSq2(t.x, t.z, cx, cz) <=
            math.pow(crabClimbStartRadius + body.size * 0.6, 2)) {
      if (saltRing && nightTime < crabSaltRingSeconds) {
        body.velocity.setZero();
      } else {
        body.climb = 0;
        brain.mode.go(CrabMode.climbing);
      }
    }
  });
}

/// Moves (dx, dz), sliding along an axis rather than stepping from
/// walkable ground onto unwalkable ground.
void _moveOn(HeightGrid grid, SceneTransform t, double dx, double dz,
    bool lowTide, [FlowObstacles? obstacles]) {
  final here = grid.walkableXZ(t.x, t.z, lowTide: lowTide);
  bool ok(double x, double z) {
    if (obstacles != null) {
      final i = gridIndexAt(x, z);
      if (i >= 0 && obstacles.wall[i] == 1) return false;
    }
    return !here || grid.canStep(t.x, t.z, x, z, lowTide: lowTide);
  }
  if (ok(t.x + dx, t.z + dz)) {
    t
      ..x += dx
      ..z += dz;
  } else if (ok(t.x + dx, t.z)) {
    t.x += dx;
  } else if (ok(t.x, t.z + dz)) {
    t.z += dz;
  }
}

/// Sideways: local ±X along travel, whichever needs the smaller turn.
void _face(CrabBody body, double dt) {
  final vx = body.velocity.x, vz = body.velocity.z;
  if (vx * vx + vz * vz < 0.01) return;
  // Local +X is (cos θ, −sin θ): θ = atan2(−vz, vx) puts it along travel.
  final plus = math.atan2(-vz, vx);
  final minus = wrapAngle(plus + math.pi);
  // Keep scuttling on the same side unless the other is clearly the
  // smaller turn, so a crab heading across its body never flips back
  // and forth.
  final keep = body.scuttleSign > 0 ? plus : minus;
  final other = body.scuttleSign > 0 ? minus : plus;
  final switchSides = angleDelta(body.facing, keep).abs() >
      angleDelta(body.facing, other).abs() + crabSideHysteresis;
  final usePlus = (body.scuttleSign > 0) != switchSides;
  body
    ..scuttleSign = usePlus ? 1 : -1
    ..facing = turnToward(
      body.facing,
      usePlus ? plus : minus,
      crabTurnRate * dt,
    );
}

/// Climbing crabs go up the tower wall to the gallery.
void _climbCrabs(World world) {
  final flow = world.resource<FlowField>();
  final grid = world.resource<HeightGrid>();
  final dt = world.dt;
  world.query3<CrabBrain, CrabBody, SceneTransform>().without<Dead>().each((
    entity,
    brain,
    body,
    t,
  ) {
    if (brain.mode.state != CrabMode.climbing || world.has<Boss>(entity)) {
      return;
    }
    body.climb = math.min(crabGalleryHeight, body.climb + crabClimbSpeed * dt);
    final ox = t.x - flow.centreX, oz = t.z - flow.centreZ;
    final d = math.max(math.sqrt(ox * ox + oz * oz), 1e-3);
    t
      ..x = flow.centreX + ox / d * crabClimbWallRadius
      ..z = flow.centreZ + oz / d * crabClimbWallRadius;
    t.y = grid.sample(t.x, t.z) + body.climb;
    body.facing = yawToward(-ox, -oz);
  });
}

/// A crab within reach of the keeper attacks; the hit lands at the Attack
/// clip's authored event moment, if the keeper is still in range.
void _crabAttacks(World world) {
  final dt = world.dt;
  final lib = world.resource<ModelLibrary>();
  final keeper = world.query2<KeeperBrain, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  final keeperUp =
      keeper != null && keeper.$2.mode.state != KeeperMode.downed;
  world.query4<Crab, CrabBrain, CrabBody, SceneTransform>()
      .without<Dead>()
      .each((entity, crab, brain, body, t) {
    final asset = crabStats[crab.type]!.asset;
    switch (brain.mode.state) {
      case CrabMode.hit when brain.mode.elapsed >= crabHitStagger:
        brain.mode.go(CrabMode.advancing);
      case CrabMode.attacking:
        final info = lib.clip(asset, 'Attack');
        final at = info?.eventAt ?? 0.3;
        if (passedMoment(brain.mode.elapsed, dt, at) && keeperUp) {
          final reach = body.size * crabAttackReachFactor + crabKeeperRadius;
          if (distSq2(t.x, t.z, keeper.$3.x, keeper.$3.z) <=
              math.pow(reach * crabAttackStillInRange, 2)) {
            // A swarmling only nibbles; enough nibbles cost a heart.
            world.emit(CrabAttackLanded(
              entity,
              1,
              nibble: crabHordeTypes.contains(crab.type),
            ));
          }
        }
        if (brain.mode.elapsed >= (info?.seconds ?? 0.6)) {
          brain
            ..cooldown = crabAttackCooldown
            ..mode.go(CrabMode.advancing);
        }
      case CrabMode.advancing || CrabMode.cowering
          when keeperUp && brain.cooldown <= 0 && !world.has<Boss>(entity):
        if (world.has<Underground>(entity) || body.leap > 0) return;
        final reach = body.size * crabAttackReachFactor + crabKeeperRadius;
        if (distSq2(t.x, t.z, keeper.$3.x, keeper.$3.z) <= reach * reach) {
          final dx = keeper.$3.x - t.x, dz = keeper.$3.z - t.z;
          final d = math.max(math.sqrt(dx * dx + dz * dz), 1e-3);
          body
            ..facing = yawToward(dx, dz)
            ..lungeX = dx / d
            ..lungeZ = dz / d
            ..lunged = false;
          brain
            ..attackAt = lib.clip(asset, 'Attack')?.eventAt ?? 0.3
            ..mode.go(CrabMode.attacking);
        }
      default:
        break;
    }
  });
}
