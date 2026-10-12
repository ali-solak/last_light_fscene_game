part of '../crabs.dart';

void installTideMother(GameBuilder game) {
  game.addSystem(
    Schedules.fixedUpdate,
    _driveBoss,
    writes: {CrabBrain, BossBrain, CrabBody, SceneTransform},
    reads: {Health, Keeper, Dead},
    inSet: GameSets.crabs,
    after: [_crabSpecials],
    runIf: _night,
  );
}

/// The Tide Mother runs her routine; each third of her health lost breaks a
/// boat-shell piece and interrupts it.
void _driveBoss(World world) {
  final dt = world.dt;
  final lib = world.resource<ModelLibrary>();
  final flow = world.resource<FlowField>();
  final grid = world.resource<HeightGrid>();
  final dir = world.resource<CrabScratch>().dir;
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;
  const asset = 'tide_mother';

  world.query4<BossBrain, CrabBrain, CrabBody, SceneTransform>()
      .without<Dead>()
      .each((entity, boss, brain, body, t) {
    final state = brain.mode.state;
    if (state == CrabMode.landing) return;
    final health = world.get<Health>(entity);

    // A phase break interrupts whatever she was doing.
    if (boss.breaking < 0 &&
        boss.phase < tideMotherPhaseAt.length &&
        health.fraction <= tideMotherPhaseAt[boss.phase]) {
      boss.breaking = boss.phase;
      world.emit(BossPhase(entity, boss.phase));
      boss.phase++;
      _startSpecial(brain, 'Shell_Break_${boss.breaking}');
    }
    if (boss.breaking >= 0) {
      if (brain.mode.elapsed >=
          lib.seconds(asset, 'Shell_Break_${boss.breaking}', fallback: 2.5)) {
        boss.breaking = -1;
        brain
          ..special = ''
          ..mode.go(CrabMode.advancing);
      }
      return;
    }

    StepResult play(String clip, void Function()? onEvent) {
      if (brain.mode.state != CrabMode.special || brain.special != clip) {
        _startSpecial(brain, clip);
        return StepResult.running;
      }
      final info = lib.clip(asset, clip);
      if (!brain.specialFired &&
          info?.eventAt != null &&
          passedMoment(brain.mode.elapsed, dt, info!.eventAt!)) {
        brain.specialFired = true;
        onEvent?.call();
      }
      if (brain.mode.elapsed < (info?.seconds ?? 1)) return StepResult.running;
      brain
        ..special = ''
        ..mode.go(CrabMode.advancing);
      return StepResult.success;
    }

    boss.routine.advance(dt, (step) => switch (step) {
      Roar() => play('Roar', null),
      Advance(:final metres) => () {
        final near = distSq2(t.x, t.z, flow.centreX, flow.centreZ) <=
            tideMotherLighthouseStop * tideMotherLighthouseStop;
        if (near || boss.advanced >= metres) {
          boss.advanced = 0;
          body.velocity.setZero();
          return StepResult.success;
        }
        flow.direction(t.x, t.z, dir);
        final step = body.speed * dt;
        t
          ..x += dir.x * step
          ..z += dir.y * step;
        t.y = grid.sample(t.x, t.z);
        body.velocity.setValues(dir.x * body.speed, 0, dir.y * body.speed);
        _face(body, dt);
        boss.advanced += step;
        return StepResult.running;
      }(),
      BossSlam() => play('Slam', () {
        world.emit(SlamLanded(entity, Vector3(t.x, t.y, t.z),
            tideMotherSlamDamage, tideMotherSlamTopple));
        if (keeper != null &&
            distSq2(t.x, t.z, keeper.$2.x, keeper.$2.z) <=
                tideMotherSlamDamage * tideMotherSlamDamage) {
          world.emit(CrabAttackLanded(entity, 1));
        }
      }),
      BroodRelease(:final count) => play('Brood_Release', () {
        // The brood port sits behind her (local +Z, opposite her facing).
        final bx = t.x - yawDirX(body.facing) * tideMotherBroodPortBack;
        final bz = t.z - yawDirZ(body.facing) * tideMotherBroodPortBack;
        for (var i = 0; i < count; i++) {
          final a = i / count * math.pi * 2;
          final x = bx + math.cos(a) * 0.8, z = bz + math.sin(a) * 0.8;
          world.spawn(crabBundle(
            CrabType.scuttler,
            Vector3(x, grid.sample(x, z), z),
            brood: true,
          ));
        }
      }),
    });
  });
}
