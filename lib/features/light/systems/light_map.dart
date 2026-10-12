part of '../light.dart';

void installLightMap(GameBuilder game) {
  game.addSystem(
    Schedules.fixedUpdate,
    _buildLightMap,
    reads: {
      Brazier,
      LampPost,
      Lantern,
      BurnPuddle,
      KeeperBody,
      KeeperBrain,
      SceneTransform,
    },
    inSet: GameSets.light,
    after: [_traceBeam, _kindleBraziers],
  );
}

/// Rebuilds the light map: lamp posts, burning oil, the lantern, the beam.
void _buildLightMap(World world) {
  final map = world.resource<LightMap>()..clear();

  world.query2<LampPost, SceneTransform>().each((_, lamp, t) {
    if (!lamp.lit) return;
    _disc(map, t.x, t.z, lampLightRadius, lampLightCentre, lampLightEdge,
        LightFlags.lamp);
  });

  world.query2<Brazier, SceneTransform>().each((_, brazier, t) {
    if (!brazier.lit) return;
    _disc(map, t.x, t.z, brazierLightRadius, brazierLightCentre,
        brazierLightEdge, LightFlags.lamp);
    _disc(map, t.x, t.z, brazierBurnRadius, brazierLightCentre,
        brazierLightCentre, LightFlags.burn | LightFlags.lamp);
  });

  // Burning grass is light (the horde goes round it) and it scorches.
  if (world.tryResource<FireField>() case final fire? when fire.count > 0) {
    for (var k = 0; k < fire.count; k++) {
      map.mark(fire.active[k], fireLightIntensity,
          LightFlags.burn | LightFlags.lantern);
    }
  }

  world.query<BurnPuddle>().each((_, puddle) {
    _disc(map, puddle.x, puddle.z, puddle.radius, burnLightIntensity,
        burnLightIntensity, LightFlags.burn | LightFlags.lantern);
  });

  world.query4<Lantern, KeeperBody, KeeperBrain, SceneTransform>().each((
    _,
    lantern,
    body,
    brain,
    t,
  ) {
    if (!lantern.lit || brain.mode.state == KeeperMode.downed) return;
    final focus = lantern.focusing;
    final x = t.x + yawDirX(body.facing) * lanternConeOffset;
    final z = t.z + yawDirZ(body.facing) * lanternConeOffset;
    _cone(
      map,
      x,
      z,
      body.facing,
      focus ? lanternFocusRange : lanternWideRange,
      (focus ? lanternFocusAngleDeg : lanternWideAngleDeg) *
          degrees2Radians /
          2,
      focus ? lanternFocusIntensity : lanternWideIntensity,
      focus ? LightFlags.focus | LightFlags.lantern : LightFlags.lantern,
    );
  });

  final beam = world.resource<Beam>();
  for (final s in world.resource<BeamPath>().segments) {
    _stripe(map, s, beam.halfWidth,
        LightFlags.beam | (s.depth > 0 ? LightFlags.bounced : 0));
  }
}

/// A disc fading linearly from [centre] to [edge] intensity.
void _disc(
  LightMap map,
  double cx,
  double cz,
  double radius,
  double centre,
  double edge,
  int flag,
) {
  final x0 = math.max(0, gridX(cx - radius));
  final x1 = math.min(gridCells - 1, gridX(cx + radius));
  final z0 = math.max(0, gridZ(cz - radius));
  final z1 = math.min(gridCells - 1, gridZ(cz + radius));
  for (var gz = z0; gz <= z1; gz++) {
    for (var gx = x0; gx <= x1; gx++) {
      final d = math.sqrt(distSq2(gridCenterX(gx), gridCenterZ(gz), cx, cz));
      if (d > radius) continue;
      map.mark(gz * gridCells + gx, centre + (edge - centre) * (d / radius),
          flag);
    }
  }
}

/// A flat cone from (cx, cz) toward [yaw].
void _cone(
  LightMap map,
  double cx,
  double cz,
  double yaw,
  double range,
  double halfAngle,
  double intensity,
  int flag,
) {
  final fx = yawDirX(yaw), fz = yawDirZ(yaw);
  final cosHalf = math.cos(halfAngle);
  final x0 = math.max(0, gridX(cx - range));
  final x1 = math.min(gridCells - 1, gridX(cx + range));
  final z0 = math.max(0, gridZ(cz - range));
  final z1 = math.min(gridCells - 1, gridZ(cz + range));
  for (var gz = z0; gz <= z1; gz++) {
    for (var gx = x0; gx <= x1; gx++) {
      final vx = gridCenterX(gx) - cx, vz = gridCenterZ(gz) - cz;
      final d = math.sqrt(vx * vx + vz * vz);
      if (d > range) continue;
      // The cell the lantern stands in is always lit.
      if (d > 0.75 && (vx * fx + vz * fz) / d < cosHalf) continue;
      map.mark(gz * gridCells + gx, intensity, flag);
    }
  }
}

/// Cells within [halfWidth] of the segment's centreline.
void _stripe(LightMap map, BeamSegment s, double halfWidth, int flag) {
  final x0 = math.max(0, gridX(math.min(s.x0, s.x1) - halfWidth));
  final x1 = math.min(gridCells - 1, gridX(math.max(s.x0, s.x1) + halfWidth));
  final z0 = math.max(0, gridZ(math.min(s.z0, s.z1) - halfWidth));
  final z1 = math.min(gridCells - 1, gridZ(math.max(s.z0, s.z1) + halfWidth));
  for (var gz = z0; gz <= z1; gz++) {
    for (var gx = x0; gx <= x1; gx++) {
      final d = distToSegment(
          gridCenterX(gx), gridCenterZ(gz), s.x0, s.z0, s.x1, s.z1);
      if (d <= halfWidth) map.mark(gz * gridCells + gx, s.intensity, flag);
    }
  }
}
