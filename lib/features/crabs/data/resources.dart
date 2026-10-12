part of '../crabs.dart';

/// Direction toward the lighthouse per cell, by Dijkstra from the base.
/// Cost = 1 + 3·slope + 30·light (beam cells 200). Burrowers use a second
/// field with no light cost. Flat typed arrays, allocated once.
final class FlowField {
  final Float32List dist = Float32List(gridCellCount);
  final Int16List next = Int16List(gridCellCount)
    ..fillRange(0, gridCellCount, -1);
  final Float32List burrowDist = Float32List(gridCellCount);
  final Int16List burrowNext = Int16List(gridCellCount)
    ..fillRange(0, gridCellCount, -1);

  /// Built from the lit field when false; the burrow field rebuilds only
  /// when the terrain (tide) changes.
  bool burrowValid = false;
  bool builtLowTide = false;

  double centreX = 0, centreZ = 0;

  final Float32List _cost = Float32List(gridCellCount);
  FlowObstacles? _obstacles;
  final Int32List _heapCell = Int32List(gridCellCount * 8);
  final Float32List _heapKey = Float32List(gridCellCount * 8);

  /// Rebuilds the light-aware field (and the burrow field when stale).
  void rebuild(
    HeightGrid grid,
    LightMap? light, {
    required double centreX,
    required double centreZ,
    required bool lowTide,
    FlowObstacles? obstacles,
  }) {
    _obstacles = obstacles;
    this
      ..centreX = centreX
      ..centreZ = centreZ;
    if (!burrowValid || builtLowTide != lowTide) {
      _costs(grid, null, lowTide);
      _dijkstra(burrowDist, burrowNext, grid, lowTide);
      burrowValid = true;
      builtLowTide = lowTide;
    }
    _costs(grid, light, lowTide);
    _dijkstra(dist, next, grid, lowTide);
  }

  void _costs(HeightGrid grid, LightMap? light, bool lowTide) {
    for (var i = 0; i < gridCellCount; i++) {
      if (!grid.walkableAt(i, lowTide: lowTide)) {
        _cost[i] = double.infinity;
        continue;
      }
      final slope = math.tan(grid.slope[i] * math.pi / 180).clamp(0.0, 3.0);
      var c = (1 + crabFlowCostSlope * slope) *
          (grid.road[i] == 1 ? crabFlowCostRoad : 1.0);
      if (_obstacles case final o?) {
        if (o.wall[i] == 1) {
          _cost[i] = double.infinity;
          continue;
        }
        c += o.cost[i];
      }
      if (light != null) {
        c += light.flags[i] & LightFlags.beam != 0
            ? crabFlowCostBeam
            : crabFlowCostLight * light.intensity[i];
      }
      _cost[i] = c;
    }
  }

  void _dijkstra(Float32List d, Int16List to, HeightGrid grid, bool lowTide) {
    d.fillRange(0, gridCellCount, double.infinity);
    to.fillRange(0, gridCellCount, -1);
    var size = 0;
    void push(int cell, double key) {
      if (size >= _heapCell.length) return;
      var i = size++;
      while (i > 0) {
        final parent = (i - 1) >> 1;
        if (_heapKey[parent] <= key) break;
        _heapCell[i] = _heapCell[parent];
        _heapKey[i] = _heapKey[parent];
        i = parent;
      }
      _heapCell[i] = cell;
      _heapKey[i] = key;
    }

    final r = crabFlowTargetRadius;
    for (var gz = gridZ(centreZ - r); gz <= gridZ(centreZ + r); gz++) {
      for (var gx = gridX(centreX - r); gx <= gridX(centreX + r); gx++) {
        if (!gridInside(gx, gz)) continue;
        final i = gz * gridCells + gx;
        if (distSq2(gridCenterX(gx), gridCenterZ(gz), centreX, centreZ) >
                r * r ||
            !grid.walkableAt(i, lowTide: lowTide)) {
          continue;
        }
        d[i] = 0;
        push(i, 0);
      }
    }

    while (size > 0) {
      final cell = _heapCell[0];
      final key = _heapKey[0];
      // Pop.
      size--;
      if (size > 0) {
        final lastCell = _heapCell[size], lastKey = _heapKey[size];
        var i = 0;
        while (true) {
          final l = 2 * i + 1;
          if (l >= size) break;
          final rr = l + 1;
          final c = rr < size && _heapKey[rr] < _heapKey[l] ? rr : l;
          if (_heapKey[c] >= lastKey) break;
          _heapCell[i] = _heapCell[c];
          _heapKey[i] = _heapKey[c];
          i = c;
        }
        _heapCell[i] = lastCell;
        _heapKey[i] = lastKey;
      }
      if (key > d[cell]) continue;
      final cx = cell % gridCells, cz = cell ~/ gridCells;
      for (var dz = -1; dz <= 1; dz++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dz == 0) continue;
          final nx = cx + dx, nz = cz + dz;
          if (!gridInside(nx, nz)) continue;
          final n = nz * gridCells + nx;
          final cost = _cost[n];
          if (cost.isInfinite) continue;
          // No cutting round a rock's corner: both sides must be open.
          if (dx != 0 &&
              dz != 0 &&
              (_cost[cz * gridCells + nx].isInfinite ||
                  _cost[nz * gridCells + cx].isInfinite)) {
            continue;
          }
          // A crab walks n -> cell: never up a step it could not take.
          if (grid.height[cell] - grid.height[n] > islandMaxStep * 2) continue;
          final nd = key + cost * (dx != 0 && dz != 0 ? math.sqrt2 : 1);
          if (nd < d[n]) {
            d[n] = nd;
            to[n] = cell;
            push(n, nd);
          }
        }
      }
    }
  }

  /// The unit direction to walk from (x, z), into [out] (x, z): toward
  /// the next cell and the one after, blended, so the way bends smoothly
  /// instead of snapping between the eight neighbours at every border.
  void direction(double x, double z, Vector2 out, {bool burrow = false}) {
    final to = burrow ? burrowNext : next;
    final i = gridIndexAt(x, z);
    final first = i < 0 ? -1 : to[i];
    final second = first < 0 ? -1 : to[first];
    out.setZero();
    for (final step in [first, if (second >= 0) second]) {
      final dx = (step < 0 ? centreX : gridCenterX(step % gridCells)) - x;
      final dz = (step < 0 ? centreZ : gridCenterZ(step ~/ gridCells)) - z;
      final len = math.sqrt(dx * dx + dz * dz);
      if (len > 1e-6) out.add(Vector2(dx / len, dz / len));
    }
    final len = out.length;
    if (len > 1e-6) out.scale(1 / len);
  }
}

/// Live crabs bucketed per 2 m cell, rebuilt every fixed step.
final class SpatialGrid {
  static const double cell = 2;
  static const int dim = 48;
  static const int capacity = 512;

  final Int32List head = Int32List(dim * dim);
  final Int32List link = Int32List(capacity);
  final Float32List xs = Float32List(capacity);
  final Float32List zs = Float32List(capacity);
  final Float32List sizes = Float32List(capacity);
  final Float32List vxs = Float32List(capacity);
  final Float32List vzs = Float32List(capacity);
  final List<Entity?> entities = List.filled(capacity, null);
  int count = 0;

  void clear() {
    head.fillRange(0, head.length, -1);
    count = 0;
  }

  static int _bucket(double v) =>
      ((v - gridOrigin) / cell).floor().clamp(0, dim - 1);

  void add(
    Entity entity,
    double x,
    double z,
    double size, [
    double vx = 0,
    double vz = 0,
  ]) {
    if (count >= capacity) return;
    final slot = count++;
    final b = _bucket(z) * dim + _bucket(x);
    xs[slot] = x;
    zs[slot] = z;
    sizes[slot] = size;
    vxs[slot] = vx;
    vzs[slot] = vz;
    entities[slot] = entity;
    link[slot] = head[b];
    head[b] = slot;
  }

  /// Writes the slots within [radius] of (x, z) into [out]; returns count.
  int near(double x, double z, double radius, Int32List out) {
    var n = 0;
    final r2 = radius * radius;
    for (var bz = _bucket(z - radius); bz <= _bucket(z + radius); bz++) {
      for (var bx = _bucket(x - radius); bx <= _bucket(x + radius); bx++) {
        for (var s = head[bz * dim + bx]; s >= 0; s = link[s]) {
          if (distSq2(xs[s], zs[s], x, z) <= r2 && n < out.length) out[n++] = s;
        }
      }
    }
    return n;
  }
}

/// Scratch reused by the crab systems (no per-step allocation).
final class CrabScratch {
  final Int32List near = Int32List(64);
  final Vector2 dir = Vector2.zero();
  final Vector3 point = Vector3.zero();

  /// Reused neighbour positions and velocities for the kit's steering.
  final List<Vector3> positions = [];
  final List<Vector3> velocities = [];
  final List<Vector3> _pool = [for (var i = 0; i < 128; i++) Vector3.zero()];

  /// Fills [positions] and [velocities] from [n] spatial-grid slots.
  void neighbours(SpatialGrid grid, int n, Entity self) {
    positions.clear();
    velocities.clear();
    var used = 0;
    for (var i = 0; i < n && used + 1 < _pool.length; i++) {
      final s = near[i];
      if (grid.entities[s] == self) continue;
      positions.add(_pool[used++]..setValues(grid.xs[s], 0, grid.zs[s]));
      velocities.add(_pool[used++]..setValues(grid.vxs[s], 0, grid.vzs[s]));
    }
  }
}

/// Pre-warmed crab models per type. Released models are detached, put back
/// to their first clip, and reused; nothing is instantiated during a night.
final class CrabPool {
  final Map<CrabType, List<(Node, Clips, Node?)>> free = {};

  (Node, Clips, Node?)? take(CrabType type) {
    final list = free[type];
    return list == null || list.isEmpty ? null : list.removeLast();
  }

  void give(CrabType type, Node node, Clips clips, Node? mound) {
    node.detach();
    mound?.detach();
    resetClips(clips, 'Idle');
    (free[type] ??= []).add((node, clips, mound));
  }
}

/// What the keeper laid in the horde's way, per 1 m cell: extra path cost
/// (salt: they go round if they can), walls (barricades: they cannot pass
/// and chew through instead), and the damage chewed into each wall cell
/// this step, for whoever owns the wall to take. Written by the defenses,
/// read by the flow field and the steering.
final class FlowObstacles {
  final Float32List cost = Float32List(gridCellCount);
  final Uint8List wall = Uint8List(gridCellCount);
  final Float32List chewed = Float32List(gridCellCount);

  /// Crab-seconds spent on each cell this step (salt wears under them).
  final Float32List trodden = Float32List(gridCellCount);

  /// Set when the overlay changed, so the flow rebuilds now; and whether
  /// anything is painted at all.
  bool dirty = false;
  bool painted = false;

  void clear() {
    cost.fillRange(0, gridCellCount, 0);
    wall.fillRange(0, gridCellCount, 0);
  }
}
