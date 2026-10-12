part of '../light.dart';

/// Light source bits per `LightMap` cell.
abstract final class LightFlags {
  static const int lamp = 1 << 0;
  static const int lantern = 1 << 1;
  static const int focus = 1 << 2;
  static const int beam = 1 << 3;
  static const int bounced = 1 << 4;
  static const int burn = 1 << 5;
}

/// The lighthouse beam's state. Boons change [degreesPerSecond],
/// [halfWidth] and [bounceLoss].
final class Beam {
  double yaw = 0;
  double degreesPerSecond = beamDegreesPerSecond;
  double halfWidth = beamHalfWidth;
  double bounceLoss = beamBounceLoss;
  bool on = true;

  /// The lighthouse axis on the ground, and its ground height.
  double centreX = 0, centreZ = 0, groundY = 0;

  /// `beam_origin` on the ground plane, recomputed as the head turns.
  double originX = 0, originZ = 0;

  double get dirX => yawDirX(yaw);
  double get dirZ => yawDirZ(yaw);
}

/// One straight run of the traced beam.
final class BeamSegment {
  double x0 = 0, z0 = 0, x1 = 0, z1 = 0;
  double intensity = 0;
  int depth = 0;

  /// The height it skims at (the ground it set out from + clearance).
  double altitude = 0;

  /// The mirror (or glassback) it leaves, or null for the lighthouse's run.
  Entity? from;

  /// Ended on a blocker (a cliff, a rock) rather than running out.
  bool blocked = false;

  double get length => math.sqrt(distSq2(x0, z0, x1, z1));
}

/// The traced beam: segments in trace order (a prism makes a tree), and
/// the mirrors and glassbacks it bounced off this step.
final class BeamPath {
  final List<BeamSegment> segments = [];
  final List<Entity> mirrorsHit = [];
  final List<Entity> glassbacksHit = [];
  final List<BeamSegment> _pool = [];

  void clear() {
    segments.clear();
    mirrorsHit.clear();
    glassbacksHit.clear();
  }

  BeamSegment add() {
    final i = segments.length;
    if (i == _pool.length) _pool.add(BeamSegment());
    final s = _pool[i];
    segments.add(s);
    return s;
  }

  /// How many reflections the deepest branch took.
  int get bounces => segments.fold(0, (m, s) => math.max(m, s.depth));
}

/// 1 m cells of light intensity (0..n) plus source flags, rebuilt every
/// fixed step. Flat typed arrays, allocated once.
final class LightMap {
  final Float32List intensity = Float32List(gridCellCount);
  final Uint8List flags = Uint8List(gridCellCount);

  void clear() {
    intensity.fillRange(0, gridCellCount, 0);
    flags.fillRange(0, gridCellCount, 0);
  }

  void mark(int i, double value, int flag) {
    if (value > intensity[i]) intensity[i] = value;
    flags[i] |= flag;
  }

  double intensityAt(double x, double z) {
    final i = gridIndexAt(x, z);
    return i < 0 ? 0 : intensity[i];
  }

  int flagsAt(double x, double z) {
    final i = gridIndexAt(x, z);
    return i < 0 ? 0 : flags[i];
  }

  bool beamAt(double x, double z) => flagsAt(x, z) & LightFlags.beam != 0;
}

/// Reflectors gathered once per trace, so the trace never queries inside
/// a query.
final class BeamScratch {
  final List<BeamReflector> mirrors = [];
  final List<(Entity, double, double)> glassbacks = [];
}
