part of '../island.dart';

void installIslandMaterials(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _updateMaterials,
    reads: const {},
    inSet: GameSets.feedback,
    after: [_tickSky],
    runIf: hasResource<Scene>().and(hasResource<Materials>()),
  );
}

/// Visual, every frame: the shared material parameters (time, tide, Flame,
/// beam, dawn). World time follows the game clock, so slow motion and
/// hitstop slow the world's shaders too; the sky runs on wall time.
void _updateMaterials(World world) {
  final materials = world.resource<Materials>();
  final scenery = world.resource<IslandScenery>()
    ..time += world.delta
    ..wallTime += world.unscaledDelta;
  final tide = world.resource<TideLevel>().low ? -islandTideShift : 0.0;
  final dawn = world.resource<SkyTint>().dawn;
  final flame = world.tryResource<Flame>();
  final flameLevel = flame == null ? 1.0 : flame.current / flame.max;
  final beam = world.tryResource<Beam>();
  final path = world.tryResource<BeamPath>();

  final beamInfo = scenery.beamInfo
    ..setValues(
      beam?.originX ?? 0,
      beam?.originZ ?? 0,
      beam?.yaw ?? 0,
      beam == null || !beam.on ? 0 : flameLevel,
    );
  for (var s = 0; s < islandBeamSlots.length; s++) {
    final slot = scenery.beamSlots[s];
    if (path != null && s < path.segments.length) {
      final seg = path.segments[s];
      slot.setValues(seg.x0, seg.z0, seg.x1, seg.z1);
    } else {
      slot.setValues(0, 0, 0, 0);
    }
  }

  for (final material in materials.live) {
    final p = material.parameters;
    setParam(p, 'time', scenery.time);
    setParam(p, 'tide_offset', tide);
    setParam(p, 'tide_level', tide);
    setParam(p, 'flame', flameLevel);
    setParam(p, 'dawn', dawn);
    setParam(p, 'density', (1 - dawn) * 0.85);
    setParam4(p, 'beam', beamInfo);
    if (p.hasParameter('beam_a')) {
      for (var s = 0; s < islandBeamSlots.length; s++) {
        p.setVec4(islandBeamSlots[s], scenery.beamSlots[s]);
      }
      setParam(p, 'beam_width', beam?.halfWidth ?? 1.2);
    }
  }
  if (materials.sky case final sky?) {
    setParam(sky.parameters, 'time', scenery.wallTime);
    setParam(sky.parameters, 'dawn', dawn);
  }
}

const List<String> islandBeamSlots = [
  'beam_a',
  'beam_b',
  'beam_c',
  'beam_d',
  'beam_e',
];
