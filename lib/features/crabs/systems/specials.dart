part of '../crabs.dart';

void installCrabSpecials(GameBuilder game) {
  game.addSystem(
    Schedules.fixedUpdate,
    _crabSpecials,
    writes: {CrabBrain, Health},
    reads: {Crab, SceneTransform, SnuffsLamps, KnocksMirrors, SeeksLight, Burrows, Underground, LampPost, Mirror, Keeper, Boss, Dead},
    inSet: GameSets.crabs,
    after: [_crabAttacks],
    runIf: _night,
  );
}

/// Per-type specials, timed by each clip's authored event in clips.json:
/// snuffers spit at lamps, bashers slam mirrors, moth crabs explode on
/// lamps, burrowers dig in after landing and dig out near the lighthouse,
/// and a tarback rears when its shell cracks.
void _crabSpecials(World world) {
  final dt = world.dt;
  final lib = world.resource<ModelLibrary>();
  final flow = world.resource<FlowField>();
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;
  // A cracked tar shell makes the tarback rear back in pain.
  for (final crack in world.events<ShellCracked>()) {
    final brain = world.tryGet<CrabBrain>(crack.entity);
    if (brain != null && brain.mode.state != CrabMode.dying) {
      _startSpecial(brain, 'Shell_Crack');
    }
  }
  world.query4<Crab, CrabBrain, SceneTransform, Health>()
      .without<Dead>()
      .without<Boss>()
      .each((entity, crab, brain, t, health) {
    final asset = crabStats[crab.type]!.asset;
    final target = brain.target;
    final tt = target == null ? null : world.tryGet<SceneTransform>(target);
    final d2 = tt == null ? double.infinity : distSq2(t.x, t.z, tt.x, tt.z);

    switch (brain.mode.state) {
      case CrabMode.advancing:
        if (world.has<SnuffsLamps>(entity) &&
            d2 <= crabSpitRange * crabSpitRange) {
          _startSpecial(brain, 'Spit');
        } else if (world.has<KnocksMirrors>(entity) &&
            d2 <= crabSlamReach * crabSlamReach) {
          _startSpecial(brain, 'Slam');
        } else if (world.has<SeeksLight>(entity) &&
            target != null &&
            world.has<LampPost>(target) &&
            d2 <= crabMothExplodeReach * crabMothExplodeReach) {
          // The moth bursts on the lamp: snuffs it, hurts what is close.
          world
            ..emit(MothExploded(Vector3(t.x, t.y, t.z)))
            ..emit(LampStruck(target));
          if (keeper != null &&
              distSq2(t.x, t.z, keeper.$2.x, keeper.$2.z) <=
                  crabMothBlastRadius * crabMothBlastRadius) {
            world.emit(CrabAttackLanded(entity, 1));
          }
          health.current = 0;
        } else if (world.has<Underground>(entity) &&
            distSq2(t.x, t.z, flow.centreX, flow.centreZ) <=
                crabBurrowSurfaceRadius * crabBurrowSurfaceRadius) {
          _startSpecial(brain, 'Dig_Out');
        }
      case CrabMode.special:
        final info = lib.clip(asset, brain.special);
        final at = info?.eventAt;
        if (!brain.specialFired &&
            at != null &&
            passedMoment(brain.mode.elapsed, dt, at)) {
          brain.specialFired = true;
          switch (brain.special) {
            case 'Spit' when target != null:
              world.emit(LampStruck(target));
            case 'Slam' when target != null:
              world
                ..emit(MirrorSlammed(target))
                ..emit(SlamLanded(entity, Vector3(t.x, t.y, t.z),
                    crabBasherSlamDamage, crabBasherSlamRadius));
          }
        }
        if (brain.mode.elapsed >= (info?.seconds ?? 0.6)) {
          switch (brain.special) {
            case 'Dig_In':
              world.add(entity, const Underground());
            case 'Dig_Out':
              world.remove<Underground>(entity);
            case 'Spit' || 'Slam':
              brain.target = null;
          }
          brain
            ..special = ''
            ..mode.go(CrabMode.advancing);
        }
      default:
        break;
    }
  });
}
