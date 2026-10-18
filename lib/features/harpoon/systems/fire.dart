part of '../harpoon.dart';

void installHarpoonFire(GameBuilder game) {
  game
    ..observe<Keeper>(onAdd: (world, entity, _) => world.add(entity, Harpoon()))
    ..addSystem(
      Schedules.fixedUpdate,
      _harpoonMachine,
      writes: {Harpoon},
      reads: {KeeperBrain, KeeperBody, SceneTransform, Keeper, Mirror, Crab, CrabBody, Dead, Flotsam},
      inSet: GameSets.weapons,
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _flyBolt,
      writes: {Harpoon},
      reads: {
        SceneTransform,
        CrabBody,
        Crab,
        Dead,
        Mirror,
        Barbed,
        WhalersReel,
        Keeper,
        Flotsam,
      },
      inSet: GameSets.weapons,
      after: [_harpoonMachine],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _reel,
      writes: {Harpoon, SceneTransform},
      reads: {Dead, Keeper, Crab, CrabBody},
      inSet: GameSets.weapons,
      after: [_flyBolt],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _flyDarts,
      writes: {Dart},
      reads: {SceneTransform, CrabBody, Crab, Dead},
      inSet: GameSets.weapons,
      after: [_reel],
      runIf: inState(GameStatus.night),
    )
    ..addSystem(OnExit(GameStatus.night), _stowHarpoon, writes: {Harpoon});
}

/// Ready → aiming while held → fire on release; reload after a shot.
void _harpoonMachine(World world) {
  final row = world.query4<Harpoon, KeeperBrain, KeeperBody, SceneTransform>()
      .having<Keeper>()
      .firstOrNull;
  if (row == null) return;
  final (_, harpoon, brain, body, t) = row;
  final mode = harpoon.mode..tick(world.dt);
  final held = world.buttons<KeeperAction>().pressed(KeeperAction.harpoon);
  final keeperState = brain.mode.state;

  switch (mode.state) {
    case HarpoonMode.ready when held && brain.canAct:
      mode.go(HarpoonMode.aiming);
    case HarpoonMode.aiming
        when keeperState == KeeperMode.downed ||
            keeperState == KeeperMode.jumping ||
            keeperState == KeeperMode.hit:
      mode.go(HarpoonMode.ready);
    case HarpoonMode.aiming when !held:
      final fx = yawDirX(body.facing), fz = yawDirZ(body.facing);
      // Through his eyes the shot leaves from just below the eye, so it
      // goes where the crosshair is.
      final rig = world.tryResource<CameraRig>();
      final muzzle = rig != null && rig.firstPerson
          ? rig.position + rig.look * 0.5 - Vector3(0, 0.12, 0)
          : Vector3(
              t.x + fx * harpoonMuzzleForward,
              t.y + harpoonMuzzleHeight,
              t.z + fz * harpoonMuzzleForward,
            );
      var dir = _aimTarget(world, muzzle) - muzzle;
      if (dir.length < 1.0) dir = Vector3(fx, 0, fz);
      dir.normalize();
      harpoon
        ..travelled = 0
        ..hooked = null
        ..hookKind = .miss
        ..reelSelfTo = null
        ..pierced.clear();
      harpoon.bolt.setFrom(muzzle);
      harpoon.velocity.setFrom(dir * harpoonSpeed);
      harpoon.lashed.clear();
      // Triple Bolt: two darts fan out beside it.
      if (!world.entitiesWith<TripleBolt>().isEmpty) {
        for (final a in const [-harpoonDartSpread, harpoonDartSpread]) {
          final c = math.cos(a), s = math.sin(a);
          final v = Vector3(dir.x * c - dir.z * s, dir.y, dir.x * s + dir.z * c)
            ..normalize()
            ..scale(harpoonDartSpeed);
          world.spawn([
            Dart(muzzle.clone(), v),
            const DespawnOnExit(GameStatus.night),
          ]);
        }
      }
      // The kick shoves him back a step.
      body.velocity
        ..x -= dir.x * harpoonKnockback
        ..z -= dir.z * harpoonKnockback;
      mode.go(HarpoonMode.flying);
      world.emit(const HarpoonFired());
    case HarpoonMode.reloading:
      final reload = world
          .resource<ModelLibrary>()
          .seconds('keeper', 'Ranged_2H_Reload', fallback: harpoonReloadFallback);
      if (mode.elapsed >= reload) mode.go(HarpoonMode.ready);
    default:
      break;
  }
}

/// Where the shot goes: the first crab (or mirror hook) along the camera's
/// aim ray, else the aimed ground point lifted to body height.
Vector3 _aimTarget(World world, Vector3 muzzle) {
  final aim = world.resource<AimInput>();
  if (!aim.valid) return muzzle;
  final ground = aim.point.clone()..y += harpoonGroundLift;
  final assisted = _assist(world, aim.point) ?? ground;
  if (!aim.hasRay) return assisted;
  final o = aim.rayOrigin, d = aim.rayDirection.normalized();
  // Ignore anything between the camera and the keeper.
  final skip = (muzzle - o).dot(d) - 0.5;
  var best = (ground - o).dot(d);
  if (best < skip) return assisted;
  Vector3? hit;
  world.query2<CrabBody, SceneTransform>().having<Crab>().without<Dead>().each((
    _,
    body,
    c,
  ) {
    final t = raySphere(o, d, _crabCentre(c, body), body.size * 0.5 + harpoonCrabPad);
    if (t != null && t > skip && t < best) (best, hit) = (t, o + d * t);
  });
  world.query2<Mirror, SceneTransform>().each((_, _, m) {
    final t = raySphere(o, d, _hookPoint(m), harpoonHookRadius);
    if (t != null && t > skip && t < best) (best, hit) = (t, o + d * t);
  });
  world.query2<Flotsam, SceneTransform>().each((_, _, f) {
    final t = raySphere(o, d, flotsamCentre(f), flotsamHookRadius);
    if (t != null && t > skip && t < best) (best, hit) = (t, o + d * t);
  });
  return hit ?? assisted;
}

/// Aim assist: the crab, mirror hook or flotsam nearest the aimed ground
/// point, if one is within [harpoonAimAssist] of it (plus a crab's half
/// size, or a float's).
Vector3? _assist(World world, Vector3 point) {
  Vector3? best;
  var bestD = double.infinity;
  world.query2<CrabBody, SceneTransform>().having<Crab>().without<Dead>().each((
    _,
    body,
    c,
  ) {
    final r = harpoonAimAssist + body.size * 0.5;
    final d = distSq2(c.x, c.z, point.x, point.z);
    if (d <= r * r && d < bestD) (best, bestD) = (_crabCentre(c, body), d);
  });
  world.query2<Mirror, SceneTransform>().each((_, _, m) {
    final d = distSq2(m.x, m.z, point.x, point.z);
    if (d <= harpoonAimAssist * harpoonAimAssist && d < bestD) {
      (best, bestD) = (_hookPoint(m), d);
    }
  });
  world.query2<Flotsam, SceneTransform>().each((_, _, f) {
    final r = harpoonAimAssist + flotsamHookRadius;
    final d = distSq2(f.x, f.z, point.x, point.z);
    if (d <= r * r && d < bestD) (best, bestD) = (flotsamCentre(f), d);
  });
  return best;
}

Vector3 _crabCentre(SceneTransform c, CrabBody body) =>
    Vector3(c.x, c.y + body.size * 0.35, c.z);

Vector3 _hookPoint(SceneTransform m) => Vector3(m.x, m.y + 1.2, m.z);

/// The nearest hit of a ray (unit [d]) on a sphere, or null.
double? raySphere(Vector3 o, Vector3 d, Vector3 c, double r) {
  final fx = o.x - c.x, fy = o.y - c.y, fz = o.z - c.z;
  final b = fx * d.x + fy * d.y + fz * d.z;
  final k = fx * fx + fy * fy + fz * fz - r * r;
  final disc = b * b - k;
  if (disc < 0) return null;
  final s = math.sqrt(disc);
  final t0 = -b - s;
  if (t0 >= 0) return t0;
  final t1 = -b + s;
  return t1 >= 0 ? 0 : null;
}

/// The bolt flies in 3D, dropping a little, and casts each step against
/// crab bodies, mirror hooks and the world (Rapier when present; terrain
/// and occluder circles headless).
void _flyBolt(World world) {
  final row = world.query<Harpoon>().having<Keeper>().firstOrNull;
  if (row == null) return;
  final harpoon = row.$2;
  if (harpoon.mode.state != HarpoonMode.flying) return;
  final dt = world.dt;
  harpoon.velocity.y -= harpoonDrop * dt;
  final speed = harpoon.velocity.length;
  final dir = harpoon.velocity / speed;
  final from = harpoon.bolt.clone();
  final barbed = !world.entitiesWith<Barbed>().isEmpty;
  final reach = math.min(speed * dt, harpoonRange - harpoon.travelled);

  // Nearest crab and mirror hook along this step.
  Entity? crab;
  var crabT = double.infinity;
  world.query2<CrabBody, SceneTransform>().having<Crab>().without<Dead>().each((
    entity,
    body,
    c,
  ) {
    if (harpoon.pierced.contains(entity)) return;
    final hit = raySphere(from, dir, _crabCentre(c, body),
        body.size * 0.5 + harpoonCrabPad);
    if (hit != null && hit <= reach && hit < crabT) (crab, crabT) = (entity, hit);
  });
  Entity? mirror;
  var mirrorT = double.infinity;
  world.query2<Mirror, SceneTransform>().each((entity, _, m) {
    final hit = raySphere(from, dir, _hookPoint(m), harpoonHookRadius);
    if (hit != null && hit <= reach && hit < mirrorT) {
      (mirror, mirrorT) = (entity, hit);
    }
  });
  Entity? float;
  var floatT = double.infinity;
  world.query2<Flotsam, SceneTransform>().each((entity, _, f) {
    final hit = raySphere(from, dir, flotsamCentre(f), flotsamHookRadius);
    if (hit != null && hit <= reach && hit < floatT) (float, floatT) = (entity, hit);
  });
  final wallT = _worldHit(world, from, dir, reach);

  final firstT = [crabT, mirrorT, floatT, wallT].reduce(math.min);
  if (firstT.isFinite) {
    final point = from + dir * firstT;
    if (firstT == crabT && crab != null) {
      final target = crab!;
      // The upper shell is the weak spot.
      final c = world.get<SceneTransform>(target);
      final size = world.get<CrabBody>(target).size;
      final weak = point.y >= c.y + size * 0.45;
      world
        ..emit(CrabDamaged(
          target,
          harpoonDamage * (weak ? harpoonWeakSpot : 1),
          DamageSource.harpoon,
        ))
        ..emit(HarpoonHit(.crab, target, point));
      if (weak) world.emit(WeakSpotHit(target, point));
      harpoon.pierced.add(target);
      if (harpoon.hooked == null) {
        harpoon
          ..hooked = target
          ..hookKind = .crab;
        world.add(target, const Hooked());
      }
      // Barbed bolts fly on through up to three crabs.
      if (barbed && harpoon.pierced.length < harpoonBarbedPierce) {
        harpoon.bolt.setFrom(point);
        harpoon.travelled += firstT;
        return;
      }
      harpoon.mode.go(HarpoonMode.reeling);
    } else if (firstT == mirrorT && mirror != null) {
      harpoon
        ..hooked = mirror
        ..hookKind = .mirror;
      world.emit(HarpoonHit(.mirror, mirror, point));
      harpoon.mode.go(HarpoonMode.reeling);
    } else if (firstT == floatT && float != null && harpoon.hooked == null) {
      // Wreckage at sea: hooked, to be hauled ashore.
      harpoon
        ..hooked = float
        ..hookKind = .flotsam;
      world
        ..add(float!, const Hooked())
        ..emit(HarpoonHit(.flotsam, float, point));
      harpoon.mode.go(HarpoonMode.reeling);
    } else {
      world.emit(HarpoonHit(.prop, null, point));
      if (harpoon.hooked != null) {
        harpoon.mode.go(HarpoonMode.reeling);
      } else if (!world.entitiesWith<WhalersReel>().isEmpty) {
        harpoon
          ..hookKind = .prop
          ..reelSelfTo = point;
        harpoon.mode.go(HarpoonMode.reeling);
      } else {
        harpoon.mode.go(HarpoonMode.reloading);
      }
    }
    harpoon.bolt.setFrom(point);
    return;
  }

  harpoon.bolt.setFrom(from + dir * reach);
  harpoon.travelled += reach;
  if (harpoon.travelled >= harpoonRange - 1e-6) {
    world.emit(HarpoonHit(.miss, null, harpoon.bolt.clone()));
    harpoon.mode.go(
      harpoon.hooked != null ? HarpoonMode.reeling : HarpoonMode.reloading,
    );
  }
}

/// The distance to the first rock, building or ground along this step.
double _worldHit(World world, Vector3 from, Vector3 dir, double reach) {
  var best = double.infinity;
  final grid = world.tryResource<HeightGrid>();
  if (grid != null) {
    for (var s = 0.2; s <= reach; s += 0.2) {
      final y = from.y + dir.y * s;
      if (grid.sample(from.x + dir.x * s, from.z + dir.z * s) > y) {
        best = s;
        break;
      }
    }
  }
  final physics = world.tryResource<PhysicsWorld>();
  if (physics != null) {
    final hit = raycastLayers(
      physics,
      Ray.originDirection(from, dir),
      reach,
      Layers.prop | Layers.ground,
      includeDynamic: true,
    );
    if (hit != null) best = math.min(best, hit.distance);
  } else if (world.tryResource<Occluders>() case final occluders?) {
    final flat = math.sqrt(dir.x * dir.x + dir.z * dir.z);
    if (flat > 1e-6) {
      final dx = dir.x / flat, dz = dir.z / flat;
      for (final o in occluders.circles) {
        final t = rayCircle(from.x, from.z, dx, dz, o.x, o.z, o.radius);
        if (t != null && t / flat <= reach) best = math.min(best, t / flat);
      }
    }
  }
  return best;
}

/// Reels in a speared crab, drags a hooked mirror (the mirrors feature
/// turns it), hauls flotsam in (the wreckage feature beaches it), or hauls
/// the keeper (Whaler's Reel).
void _reel(World world) {
  final row = world.query2<Harpoon, SceneTransform>().having<Keeper>().firstOrNull;
  if (row == null) return;
  final (_, harpoon, k) = row;
  if (harpoon.mode.state != HarpoonMode.reeling) return;
  final elapsed = harpoon.mode.elapsed;
  final release = world.buttons<KeeperAction>().pressed(KeeperAction.harpoon) &&
      elapsed > 0.2;

  void done() {
    final hooked = harpoon.hooked;
    if (hooked != null &&
        (harpoon.hookKind == .crab || harpoon.hookKind == .flotsam) &&
        world.isAlive(hooked)) {
      world.remove<Hooked>(hooked);
    }
    harpoon
      ..hooked = null
      ..reelSelfTo = null;
    harpoon.mode.go(HarpoonMode.reloading);
    world.emit(const HarpoonReeled());
  }

  switch (harpoon.hookKind) {
    case .crab:
      final target = harpoon.hooked;
      final c = target == null ? null : world.tryGet<SceneTransform>(target);
      if (c == null || world.has<Dead>(target!) || release ||
          elapsed >= harpoonReelSeconds) {
        return done();
      }
      final dx = k.x - c.x, dz = k.z - c.z;
      final d = math.sqrt(dx * dx + dz * dz);
      // Whiplash: the chain lashes every crab it sweeps through.
      if (!world.entitiesWith<Whiplash>().isEmpty) {
        _lash(world, harpoon, target, k.x, k.z, c.x, c.z);
      }
      if (d <= harpoonReelRelease) return done();
      final step = math.min(harpoonReelSpeed * world.dt, d - harpoonReelRelease);
      c
        ..x += dx / d * step
        ..z += dz / d * step;
      harpoon.bolt.setValues(c.x, c.y + 0.3, c.z);
    case .flotsam:
      final target = harpoon.hooked;
      final f = target == null ? null : world.tryGet<SceneTransform>(target);
      if (f == null || release || elapsed >= harpoonHaulSeconds) return done();
      final dx = k.x - f.x, dz = k.z - f.z;
      final d = math.sqrt(dx * dx + dz * dz);
      if (d <= harpoonReelRelease) return done();
      final step = math.min(harpoonHaulSpeed * world.dt, d - harpoonReelRelease);
      f
        ..x += dx / d * step
        ..z += dz / d * step;
      harpoon.bolt.setFrom(flotsamCentre(f));
    case .mirror:
      if (release || elapsed >= harpoonMirrorReelSeconds) done();
    case .prop:
      final to = harpoon.reelSelfTo;
      if (to == null || release || elapsed >= harpoonSelfReelSeconds ||
          distSq2(k.x, k.z, to.x, to.z) <=
              harpoonSelfReelArrive * harpoonSelfReelArrive) {
        done();
      }
    default:
      done();
  }
}

/// Leaving the night: drop whatever is hooked and reset the gun.
void _stowHarpoon(World world) {
  world.query<Harpoon>().each((_, harpoon) {
    harpoon
      ..hooked = null
      ..reelSelfTo = null
      ..pierced.clear()
      ..mode.go(HarpoonMode.ready);
  });
}

/// Crabs near the chain (from the keeper to the reeled crab) take a lash
/// and are flung off it, once per reel.
void _lash(
  World world,
  Harpoon harpoon,
  Entity hooked,
  double kx,
  double kz,
  double cx,
  double cz,
) {
  world.query2<CrabBody, SceneTransform>().having<Crab>().without<Dead>().each((
    entity,
    body,
    t,
  ) {
    if (entity == hooked || harpoon.lashed.contains(entity)) return;
    final reach = harpoonLashReach + body.size * 0.5;
    if (distToSegment(t.x, t.z, kx, kz, cx, cz) > reach) return;
    harpoon.lashed.add(entity);
    // Flung sideways off the chain.
    final lx = cx - kx, lz = cz - kz;
    final len = math.max(math.sqrt(lx * lx + lz * lz), 1e-3);
    var (nx, nz) = (-lz / len, lx / len);
    if ((t.x - kx) * nx + (t.z - kz) * nz < 0) (nx, nz) = (-nx, -nz);
    world
      ..emit(CrabDamaged(entity, harpoonLashDamage, DamageSource.harpoon))
      ..emit(CrabShoved(entity, nx, nz, harpoonLashFling))
      ..emit(HarpoonHit(.crab, entity, Vector3(t.x, t.y + 0.4, t.z)));
  });
}

/// Darts fly straight; the first crab they meet takes the hit.
void _flyDarts(World world) {
  final dt = world.dt;
  final grid = world.tryResource<HeightGrid>();
  final crabs = world.query2<CrabBody, SceneTransform>()
      .having<Crab>()
      .without<Dead>()
      .snapshot();
  world.query<Dart>().each((entity, dart) {
    final speed = dart.velocity.length;
    final dir = dart.velocity / speed;
    final step = speed * dt;
    for (final (crab, body, c) in crabs) {
      final t = raySphere(dart.position, dir, _crabCentre(c, body),
          body.size * 0.5 + harpoonCrabPad);
      if (t != null && t <= step) {
        final at = dart.position + dir * t;
        world
          ..emit(CrabDamaged(crab, harpoonDartDamage, DamageSource.harpoon))
          ..emit(HarpoonHit(.crab, crab, at))
          ..despawn(entity);
        return;
      }
    }
    dart.position.add(dir * step);
    dart.travelled += step;
    final ground = grid?.sample(dart.position.x, dart.position.z) ?? -1e9;
    if (dart.travelled >= harpoonDartRange || dart.position.y < ground) {
      world.despawn(entity);
    }
  });
}
