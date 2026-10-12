part of '../light.dart';

void installBeam(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _placeBeam,
      reads: const {},
      inSet: GameSets.keeper,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _rotateBeam,
      reads: const {},
      inSet: GameSets.light,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _traceBeam,
      writes: {CaughtLight},
      reads: {Mirror, PrismMirror, SceneTransform, ReflectsBeam, Dead, Keeper},
      inSet: GameSets.light,
      after: [_rotateBeam],
    );
}

/// Startup: put the beam on the lighthouse axis.
void _placeBeam(World world) {
  final anchors = world.tryResource<IslandAnchors>();
  if (anchors == null) return;
  world.resource<Beam>()
    ..centreX = anchors.lighthouse.x
    ..centreZ = anchors.lighthouse.z
    ..groundY = anchors.lighthouse.y;
  _moveOrigin(world.resource<Beam>());
}

void _moveOrigin(Beam beam) {
  beam
    ..originX = beam.centreX + beam.dirX * beamOriginForward
    ..originZ = beam.centreZ + beam.dirZ * beamOriginForward;
}

/// The lamp head turns at a steady rate, night and dawn alike, so the dawn
/// preview shows the real sweep.
void _rotateBeam(World world) {
  final beam = world.resource<Beam>();
  beam.yaw = wrapAngle(
    beam.yaw + beam.degreesPerSecond * degrees2Radians * world.dt,
  );
  _moveOrigin(beam);
}

/// Traces the beam on the XZ plane: stops at terrain rising above it, at
/// rocks and buildings (a Rapier ray, or the `Occluders` circles headless),
/// and reflects off upright placed mirrors and glassbacks.
///
/// Then every mirror still holding caught light throws it on along its
/// current facing (the relay), so a turned mirror redirects what it holds.
/// At dawn every mirror the lighthouse can see is primed, so the build
/// shows exactly where each one will throw.
void _traceBeam(World world) {
  final beam = world.resource<Beam>();
  final path = world.resource<BeamPath>()..clear();
  final scratch = world.resource<BeamScratch>();
  scratch.mirrors.clear();
  scratch.glassbacks.clear();
  world.query<Mirror>().without<CaughtLight>().each(
    (entity, _) => world.add(entity, CaughtLight()),
  );
  world.query2<Mirror, SceneTransform>().each((entity, mirror, t) {
    final caught = world.tryGet<CaughtLight>(entity)?..live = false;
    if (!mirror.upright) {
      caught?.hold = 0;
      return;
    }
    scratch.mirrors.add(
      BeamReflector(
        entity,
        t.x,
        t.z,
        mirror.yaw,
        world.has<PrismMirror>(entity),
        caught,
      ),
    );
  });
  world
      .query<SceneTransform>()
      .having<ReflectsBeam>()
      .without<Dead>()
      .each((entity, t) => scratch.glassbacks.add((entity, t.x, t.z)));
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;

  final grid = world.tryResource<HeightGrid>();
  final trace = _Trace(
    path: path,
    scratch: scratch,
    grid: grid,
    occluders: world.tryResource<Occluders>(),
    physics: world.tryResource<PhysicsWorld>(),
    loss: beam.bounceLoss,
    keeperX: keeper?.$2.x,
    keeperZ: keeper?.$2.z,
  );
  final altitude = beam.groundY + beamClearance;
  if (beam.on) {
    trace.run(
      beam.originX,
      beam.originZ,
      beam.dirX,
      beam.dirZ,
      beamIntensity,
      0,
      altitude,
      null,
      0,
      mirrorHoldSeconds,
    );
  }

  if (world.state<GameStatus>() == GameStatus.dawnBuild) {
    for (final m in scratch.mirrors) {
      final caught = m.caught;
      if (caught == null || caught.live) continue;
      final vx = m.x - beam.centreX, vz = m.z - beam.centreZ;
      final d = math.sqrt(vx * vx + vz * vz);
      if (d < 1e-3) continue;
      final (dx, dz) = (vx / d, vz / d);
      final seen = trace.blockedAt(
            beam.centreX + dx * beamOriginForward,
            beam.centreZ + dz * beamOriginForward,
            dx,
            dz,
            d,
            altitude,
            0,
          ) >=
          d - beamOriginForward - beamMirrorRadius;
      if (seen) {
        // Primed, not struck: the relay below throws it.
        caught
          ..take(dx, dz, beamIntensity, 0, mirrorHoldSeconds)
          ..live = false;
      }
    }
  }

  final dt = world.dt;
  for (final m in scratch.mirrors) {
    final caught = m.caught;
    if (caught == null || caught.live || caught.hold <= 0) continue;
    caught.hold = math.max(0, caught.hold - dt);
    final strength = caught.strength;
    if (strength < beamRelayMinIntensity) continue;
    trace.reflect(
      m,
      m.x,
      m.z,
      caught.inX,
      caught.inZ,
      strength / (1 - beam.bounceLoss),
      caught.depth,
      0,
      caught.hold,
    );
  }
}

/// Where the ray meets a mirror: its plane (through the pedestal, facing
/// its yaw), within [beamMirrorRadius] of the pedestal. Null on a miss.
double? _mirrorHit(
  double ox,
  double oz,
  double dx,
  double dz,
  double mx,
  double mz,
  double yaw,
) {
  final nx = yawDirX(yaw), nz = yawDirZ(yaw);
  final dn = dx * nx + dz * nz;
  if (dn.abs() < 1e-6) return null;
  final t = ((mx - ox) * nx + (mz - oz) * nz) / dn;
  if (t < 0) return null;
  final px = ox + dx * t - mx, pz = oz + dz * t - mz;
  return px * px + pz * pz <= beamMirrorRadius * beamMirrorRadius ? t : null;
}

/// One placed mirror as the trace sees it (trace scratch).
final class BeamReflector(
  final Entity entity,
  final double x,
  final double z,
  final double yaw,
  final bool prism,
  final CaughtLight? caught,
);

/// One trace's context; [run] recurses per bounce (and per prism branch).
final class _Trace({
  required final BeamPath path,
  required final BeamScratch scratch,
  required final HeightGrid? grid,
  required final Occluders? occluders,
  required final PhysicsWorld? physics,
  required final double loss,
  required final double? keeperX,
  required final double? keeperZ,
}) {
  /// Traces one straight run from (ox, oz) and whatever it bounces into.
  /// [hold] is how long a mirror this run strikes keeps the light: a relay
  /// never hands on more than it has left, so two facing mirrors cannot
  /// keep each other lit forever.
  void run(
    double ox,
    double oz,
    double dx,
    double dz,
    double intensity,
    int depth,
    double altitude,
    Entity? skip,
    double travelled,
    double hold,
  ) {
    var reach = beamLength - travelled;
    if (reach <= beamMinHit) return;

    // Nearest reflector.
    BeamReflector? mirror;
    Entity? glass;
    double hx = 0, hz = 0;
    for (final m in scratch.mirrors) {
      if (m.entity == skip) continue;
      final t = _mirrorHit(ox, oz, dx, dz, m.x, m.z, m.yaw);
      if (t != null && t > beamMinHit && t < reach) {
        (reach, mirror, glass) = (t, m, null);
      }
    }
    for (final (entity, gx, gz) in scratch.glassbacks) {
      if (entity == skip) continue;
      final t = rayCircle(ox, oz, dx, dz, gx, gz, beamGlassbackRadius);
      if (t != null && t > beamMinHit && t < reach) {
        (reach, mirror, glass, hx, hz) = (t, null, entity, gx, gz);
      }
    }

    // Blockers: rising terrain always; rocks and buildings from Rapier when
    // it is there, otherwise from the occluder circles.
    final blocked = blockedAt(ox, oz, dx, dz, reach, altitude, depth);
    final stopped = blocked < reach;
    if (stopped) {
      reach = blocked;
      mirror = null;
      glass = null;
    }

    path.add()
      ..x0 = ox
      ..z0 = oz
      ..x1 = ox + dx * reach
      ..z1 = oz + dz * reach
      ..intensity = intensity
      ..depth = depth
      ..altitude = altitude
      ..from = skip
      ..blocked = stopped;

    if (depth >= beamMaxBounces) return;
    final px = ox + dx * reach, pz = oz + dz * reach;
    if (mirror != null) {
      mirror.caught?.take(dx, dz, intensity, depth, hold);
      reflect(mirror, px, pz, dx, dz, intensity, depth, travelled + reach,
          hold);
    } else if (glass != null) {
      // A glassback throws the beam at the keeper.
      path.glassbacksHit.add(glass);
      final kx = (keeperX ?? hx) - hx, kz = (keeperZ ?? hz) - hz;
      final len = math.sqrt(kx * kx + kz * kz);
      if (len < 1e-6) return;
      _bounce(px, pz, dx, dz, kx / len, kz / len, intensity, depth, glass,
          travelled + reach, false, hold);
    }
  }

  /// Reflects a ray arriving along (dx, dz) off [mirror], at (px, pz).
  void reflect(
    BeamReflector mirror,
    double px,
    double pz,
    double dx,
    double dz,
    double intensity,
    int depth,
    double travelled,
    double hold,
  ) {
    path.mirrorsHit.add(mirror.entity);
    _bounce(px, pz, dx, dz, yawDirX(mirror.yaw), yawDirZ(mirror.yaw),
        intensity, depth, mirror.entity, travelled, mirror.prism, hold);
  }

  void _bounce(
    double px,
    double pz,
    double dx,
    double dz,
    double nx,
    double nz,
    double intensity,
    int depth,
    Entity from,
    double travelled,
    bool prism,
    double hold,
  ) {
    final dot = dx * nx + dz * nz;
    final rx = dx - 2 * dot * nx, rz = dz - 2 * dot * nz;
    final next = intensity * (1 - loss);
    final altitude = (grid?.sample(px, pz) ?? 0) + beamClearance;
    final spread = prism
        ? const [-beamPrismSpread, 0.0, beamPrismSpread]
        : const [0.0];
    for (final a in spread) {
      final c = math.cos(a), s = math.sin(a);
      run(px, pz, rx * c - rz * s, rx * s + rz * c, next, depth + 1, altitude,
          from, travelled, hold);
    }
  }

  double blockedAt(
    double ox,
    double oz,
    double dx,
    double dz,
    double reach,
    double altitude,
    int depth,
  ) {
    var best = reach;
    if (grid case final grid?) {
      for (var s = beamStep; s < best; s += beamStep) {
        if (grid.sample(ox + dx * s, oz + dz * s) > altitude) {
          best = s;
          break;
        }
      }
    }
    if (physics case final physics?) {
      // Start outside the lighthouse's own collider on the first run.
      final start = depth == 0 ? islandLighthouseRadius : beamMinHit;
      if (best > start) {
        final hit = raycastLayers(
          physics,
          Ray.originDirection(
            Vector3(ox + dx * start, altitude, oz + dz * start),
            Vector3(dx, 0, dz),
          ),
          best - start,
          Layers.ground | Layers.prop,
        );
        if (hit != null) best = math.min(best, start + hit.distance);
      }
    } else if (occluders case final occluders?) {
      for (final o in occluders.circles) {
        if (distSq2(ox, oz, o.x, o.z) <= o.radius * o.radius) continue;
        final t = rayCircle(ox, oz, dx, dz, o.x, o.z, o.radius);
        if (t != null && t < best) best = t;
      }
    }
    return best;
  }
}
