part of '../fire.dart';

/// The fire on the 1 m grid: per cell, seconds left burning, heat toward
/// catching, and whether it has burned out. [active] lists the cells
/// burning now (unordered), so spreading never scans the whole island.
final class FireField {
  final Float32List burn = Float32List(gridCellCount);
  final Float32List heat = Float32List(gridCellCount);
  final Uint8List scorched = Uint8List(gridCellCount);
  final Int32List active = Int32List(gridCellCount);
  int count = 0;

  bool burning(int i) => burn[i] > 0;

  bool burningAt(double x, double z) {
    final i = gridIndexAt(x, z);
    return i >= 0 && burn[i] > 0;
  }

  /// Sets cell [i] alight, if it has fuel left ([oil] burns on any ground).
  bool ignite(int i, HeightGrid grid, {bool oil = false}) {
    if (i < 0 || burn[i] > 0) return false;
    if (!oil && (scorched[i] == 1 || grid.grass[i] == 0)) return false;
    // A per-cell hash varies how long it burns, deterministically.
    final h = ((i * 2654435761) & 0xffff) / 0xffff;
    burn[i] = fireBurnMin + (fireBurnMax - fireBurnMin) * h;
    heat[i] = 0;
    active[count++] = i;
    return true;
  }

  /// Ignites every cell within [radius] of (x, z); returns how many.
  int igniteDisc(
    double x,
    double z,
    double radius,
    HeightGrid grid, {
    bool oil = false,
  }) {
    var n = 0;
    for (var gz = gridZ(z - radius); gz <= gridZ(z + radius); gz++) {
      for (var gx = gridX(x - radius); gx <= gridX(x + radius); gx++) {
        if (!gridInside(gx, gz)) continue;
        if (distSq2(gridCenterX(gx), gridCenterZ(gz), x, z) > radius * radius) {
          continue;
        }
        if (ignite(gz * gridCells + gx, grid, oil: oil)) n++;
      }
    }
    return n;
  }

  /// Everything out and the grass grown back.
  void reset() {
    burn.fillRange(0, gridCellCount, 0);
    heat.fillRange(0, gridCellCount, 0);
    scorched.fillRange(0, gridCellCount, 0);
    count = 0;
  }
}

/// The fire's look: one instanced batch of crossed flame cards (a card per
/// burning cell) and a pool of flickering lights.
final class FireVisual(
  final InstancedMesh? flames,
  final List<(Node, PointLight)> lights,
) {
  double time = 0;
  double debt = 0;
}
