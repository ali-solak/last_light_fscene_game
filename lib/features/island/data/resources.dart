part of '../island.dart';

/// What gameplay needs from `island.glb`, in engine space: every named
/// node's world transform, and the collision and ground triangles (packed
/// xyz, 9 floats each) with each ground triangle's mean palette U. The game
/// reads it off the loaded model ([IslandAsset.fromModel]); a headless test,
/// with no GPU to load models, builds it from the file. The startup system
/// builds everything else from it, so navigation works headless.
final class IslandAsset({
  required final Map<String, Matrix4> transforms,
  required final Float32List collision,
  required final Float32List ground,
  required final Float32List groundUs,
}) {
  factory IslandAsset.fromModel(Node island) {
    final transforms = <String, Matrix4>{};
    void walk(Node node) {
      if (node.name.isNotEmpty) transforms[node.name] = node.globalTransform;
      node.children.forEach(walk);
    }

    walk(island);
    final collision = _mesh(island, 'collision');
    final ground = _mesh(island, 'ground');
    final uvs = ground?.texCoords;
    return IslandAsset(
      transforms: transforms,
      collision: _packed(collision),
      ground: _packed(ground),
      groundUs: Float32List.fromList([
        for (final t in ground?.triangles ?? const <MeshTriangle>[])
          uvs == null ? 0 : (uvs[t.a * 2] + uvs[t.b * 2] + uvs[t.c * 2]) / 3,
      ]),
    );
  }

  bool hasNode(String name) => transforms.containsKey(name);

  /// The node's world transform, or null if absent.
  Matrix4? worldTransform(String name) => transforms[name];

  /// The node's world position, or null if absent.
  Vector3? position(String name) => transforms[name]?.getTranslation();

  /// The node's yaw about +Y.
  double yaw(String name) {
    final m = transforms[name];
    if (m == null) return 0;
    // Local −Z (the authored forward) in world space.
    final f = m.transform3(Vector3(0, 0, -1)) - m.getTranslation();
    return math.atan2(-f.x, -f.z);
  }

  /// The named node's geometry in world space, or null.
  static MeshData? _mesh(Node island, String name) {
    final node = island.getChildByName(name);
    return node?.extractMeshData(transform: node.globalTransform);
  }

  static Float32List _packed(MeshData? mesh) => Float32List.fromList([
    for (final t in mesh?.triangles ?? const <MeshTriangle>[]) ...[
      t.pa.x, t.pa.y, t.pa.z, //
      t.pb.x, t.pb.y, t.pb.z, //
      t.pc.x, t.pc.y, t.pc.z,
    ],
  ]);
}

/// 1 m cells over 96×96 m: ground height, slope and walkability, rasterised
/// from the island's `collision` mesh. Sampled bilinearly.
final class HeightGrid {
  final Float32List height = Float32List(gridCellCount)..fillRange(
    0,
    gridCellCount,
    -10,
  );

  /// Slope in degrees of the triangle that set each cell's height.
  final Float32List slope = Float32List(gridCellCount);

  /// 1 where walkable at high tide.
  final Uint8List walkable = Uint8List(gridCellCount);

  /// 1 on the tide-pool path: walkable only at low tide.
  final Uint8List tidal = Uint8List(gridCellCount);

  /// 1 under rocks and buildings: never walkable.
  final Uint8List blocked = Uint8List(gridCellCount);

  /// 1 on the sand trails up from the beaches: crabs march along them.
  final Uint8List road = Uint8List(gridCellCount);

  /// 1 on grass: fuel for fire.
  final Uint8List grass = Uint8List(gridCellCount);

  /// Marks the trails and the grass from the ground's palette colours
  /// (columns of its 16-wide palette row): [islandRoadColumns] and
  /// [islandGrassColumns].
  void paintGround(Float32List tris, Float32List us) {
    for (var t = 0, k = 0; t + 8 < tris.length && k < us.length; t += 9, k++) {
      final column = (us[k] * 16).floor();
      final mark = islandRoadColumns.contains(column)
          ? road
          : (islandGrassColumns.contains(column) ? grass : null);
      if (mark == null) continue;
      _raster(
        tris[t], tris[t + 1], tris[t + 2], //
        tris[t + 3], tris[t + 4], tris[t + 5], //
        tris[t + 6], tris[t + 7], tris[t + 8],
        mark: mark,
      );
    }
  }

  /// Builds the grid from packed world-space triangles (9 floats each).
  HeightGrid.fromTriangles(Float32List tris) {
    for (var t = 0; t + 8 < tris.length; t += 9) {
      _raster(
        tris[t], tris[t + 1], tris[t + 2], //
        tris[t + 3], tris[t + 4], tris[t + 5], //
        tris[t + 6], tris[t + 7], tris[t + 8],
      );
    }
    for (var i = 0; i < gridCellCount; i++) {
      final flat = slope[i] < islandMaxWalkSlopeDeg;
      final h = height[i];
      walkable[i] = flat && h > islandWadeDepth ? 1 : 0;
      tidal[i] = flat && h <= islandWadeDepth && h > islandTidePathDepth
          ? 1
          : 0;
    }
  }

  /// A flat grassy grid at [level] (tests).
  HeightGrid.flat(double level) {
    height.fillRange(0, gridCellCount, level);
    walkable.fillRange(0, gridCellCount, 1);
    grass.fillRange(0, gridCellCount, 1);
  }

  void _raster(
    double ax, double ay, double az, //
    double bx, double by, double bz, //
    double cx, double cy, double cz, {
    Uint8List? mark,
  }) {
    final ux = bx - ax, uy = by - ay, uz = bz - az;
    final vx = cx - ax, vy = cy - ay, vz = cz - az;
    final nx = uy * vz - uz * vy;
    final ny = uz * vx - ux * vz;
    final nz = ux * vy - uy * vx;
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-9) return;
    final deg = math.acos((ny.abs() / len).clamp(0.0, 1.0)) * 180 / math.pi;
    final d = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz);
    if (d.abs() < 1e-9) return;
    final x0 = math.max(0, gridX(math.min(ax, math.min(bx, cx))));
    final x1 = math.min(gridCells - 1, gridX(math.max(ax, math.max(bx, cx))));
    final z0 = math.max(0, gridZ(math.min(az, math.min(bz, cz))));
    final z1 = math.min(gridCells - 1, gridZ(math.max(az, math.max(bz, cz))));
    for (var gz = z0; gz <= z1; gz++) {
      final pz = gridCenterZ(gz);
      for (var gx = x0; gx <= x1; gx++) {
        final px = gridCenterX(gx);
        final l1 = ((bz - cz) * (px - cx) + (cx - bx) * (pz - cz)) / d;
        final l2 = ((cz - az) * (px - cx) + (ax - cx) * (pz - cz)) / d;
        final l3 = 1 - l1 - l2;
        if (l1 < -1e-6 || l2 < -1e-6 || l3 < -1e-6) continue;
        final i = gz * gridCells + gx;
        if (mark != null) {
          mark[i] = 1;
          continue;
        }
        final y = l1 * ay + l2 * by + l3 * cy;
        if (y > height[i]) {
          height[i] = y;
          slope[i] = deg;
        }
      }
    }
  }

  /// Marks every cell centred within [radius] of (x, z) unwalkable.
  void block(double x, double z, double radius) {
    for (var gz = gridZ(z - radius); gz <= gridZ(z + radius); gz++) {
      for (var gx = gridX(x - radius); gx <= gridX(x + radius); gx++) {
        if (!gridInside(gx, gz) ||
            distSq2(gridCenterX(gx), gridCenterZ(gz), x, z) > radius * radius) {
          continue;
        }
        walkable[gz * gridCells + gx] = 0;
        tidal[gz * gridCells + gx] = 0;
        blocked[gz * gridCells + gx] = 1;
      }
    }
  }

  /// Bilinear height at (x, z), between cell centres.
  double sample(double x, double z) {
    final fx = (x - gridOrigin) / gridCellSize - 0.5;
    final fz = (z - gridOrigin) / gridCellSize - 0.5;
    final x0 = fx.floor().clamp(0, gridCells - 1);
    final z0 = fz.floor().clamp(0, gridCells - 1);
    final x1 = math.min(x0 + 1, gridCells - 1);
    final z1 = math.min(z0 + 1, gridCells - 1);
    final tx = (fx - x0).clamp(0.0, 1.0), tz = (fz - z0).clamp(0.0, 1.0);
    final h00 = height[z0 * gridCells + x0], h10 = height[z0 * gridCells + x1];
    final h01 = height[z1 * gridCells + x0], h11 = height[z1 * gridCells + x1];
    return (h00 * (1 - tx) + h10 * tx) * (1 - tz) +
        (h01 * (1 - tx) + h11 * tx) * tz;
  }

  /// Whether cell [i] can be walked, given the tide.
  bool walkableAt(int i, {bool lowTide = false}) =>
      i >= 0 && (walkable[i] == 1 || (lowTide && tidal[i] == 1));

  bool walkableXZ(double x, double z, {bool lowTide = false}) =>
      walkableAt(gridIndexAt(x, z), lowTide: lowTide);

  /// Whether a mover at (fromX, fromZ) may step to (toX, toZ): onto a
  /// walkable cell, or up/down a small step. Solid occluder cells and deep
  /// water never pass.
  bool canStep(
    double fromX,
    double fromZ,
    double toX,
    double toZ, {
    bool lowTide = false,
  }) {
    final i = gridIndexAt(toX, toZ);
    if (i < 0) return false;
    final from = gridIndexAt(fromX, fromZ);
    if (walkableAt(i, lowTide: lowTide)) {
      // Never climb a wall from a walkable cell onto a much higher one.
      return from < 0 || height[i] - height[from] <= islandMaxStep * 2;
    }
    if (blocked[i] == 1 || height[i] <= islandWadeDepth) return false;
    // A steep-flagged cell is passable only as a small step between cells.
    return from >= 0 && (height[i] - height[from]).abs() <= islandMaxStep;
  }

  /// Whether the keeper may walk from (fromX, fromZ) to (toX, toZ): up any
  /// slope gentler than [islandKeeperMaxSlopeDeg] (measured on the smooth
  /// ground, so a bumpy hillside never snags him), down anything, never
  /// into rocks, buildings or deep water. [lift] is how high he is off the
  /// ground (a jump clears a ledge that high).
  bool canWalk(
    double fromX,
    double fromZ,
    double toX,
    double toZ, {
    bool lowTide = false,
    double lift = 0,
  }) {
    final i = gridIndexAt(toX, toZ);
    if (i < 0 || blocked[i] == 1) return false;
    final to = sample(toX, toZ);
    if (to <= islandWadeDepth && !(lowTide && tidal[i] == 1)) return false;
    final rise = to - sample(fromX, fromZ);
    if (rise <= 0) return true;
    final run = math.sqrt(distSq2(fromX, fromZ, toX, toZ));
    return rise <= run * _keeperClimb + islandKeeperStepUp + lift;
  }

  static final double _keeperClimb =
      math.tan(islandKeeperMaxSlopeDeg * math.pi / 180);

  /// Marches [direction] from [origin] onto the ground. Falls back to the
  /// sea plane (y = 0) when the ray never meets the terrain.
  bool raycast(Vector3 origin, Vector3 direction, Vector3 out) {
    final dir = direction.normalized();
    var prevAbove = true;
    for (var t = 0.0; t < islandAimMaxDistance; t += islandAimStep) {
      final x = origin.x + dir.x * t;
      final y = origin.y + dir.y * t;
      final z = origin.z + dir.z * t;
      final ground = math.max(sample(x, z), 0.0);
      final above = y > ground;
      if (!above && prevAbove) {
        out.setValues(x, ground, z);
        return true;
      }
      prevAbove = above;
    }
    if (dir.y < -1e-4) {
      final t = -origin.y / dir.y;
      out.setValues(origin.x + dir.x * t, 0, origin.z + dir.z * t);
      return true;
    }
    return false;
  }
}

/// The sea level. Low tide opens the tide-pool path.
enum TideState { high, low }

final class TideLevel {
  TideState state = .high;
  bool get low => state == .low;
}

/// Named anchor positions read from the island document.
final class IslandAnchors {
  final Vector3 keeperSpawn = Vector3.zero();
  final Vector3 lighthouse = Vector3.zero();
  final Vector3 cottage = Vector3.zero();
  double cottageYaw = 0;
  final Vector3 dock = Vector3.zero();
  double dockYaw = 0;
  final Vector3 bell = Vector3.zero();
  double bellYaw = 0;
}

/// Crab landing points, `crab_spawn_0..5`; two per beach.
final class SpawnPoints(final List<Vector3> points) {
  /// The spawn points of [beach].
  List<Vector3> of(Beach beach) => switch (beach) {
    .north => points.sublist(0, math.min(2, points.length)),
    .east => points.length >= 4 ? points.sublist(2, 4) : points,
    .south => points.length >= 6 ? points.sublist(4, 6) : points,
  };
}

/// A 2D circle that blocks the beam.
final class const Occluder(final double x, final double z, final double radius);

/// Everything on the island that blocks the beam headless.
final class Occluders(final List<Occluder> circles);

/// The dawn/night look: [dawn] runs 0 (night) → 1 (dawn), tweened on state
/// changes; `sky.fmat`, fog and lights read it.
final class SkyTint {
  GameTween<double> tween = GameTween.number(0, 0, 0.01);
  double get dawn => tween.value;

  void toward(double target) {
    tween = GameTween.number(tween.value, target, islandSkyTweenSeconds);
  }
}

/// The loaded `.fmat` materials (§5.13). Shared materials by file name, plus
/// small pools of per-entity instances. Every entry is optional: a material
/// that failed to load is absent and the palette material stays.
final class Materials(
  final Map<String, PreprocessedMaterial> shared,
  final Map<String, List<PreprocessedMaterial>> pools,
  final PreprocessedSky? sky,
) {
  PreprocessedMaterial? operator [](String name) => shared[name];

  /// Takes a per-entity instance of [name], or null when none is free.
  PreprocessedMaterial? take(String name) {
    final pool = pools[name];
    if (pool == null || pool.isEmpty) return null;
    return pool.removeLast();
  }

  /// Returns a per-entity instance.
  void give(String name, PreprocessedMaterial material) =>
      (pools[name] ??= []).add(material);

  /// Every instance handed out or pooled, for the shared parameters.
  final List<PreprocessedMaterial> live = [];
}

/// The visual island nodes systems keep touching.
final class IslandScenery {
  Node? sea;
  Node? ground;
  DirectionalLight? moonLight;

  /// 0..1 lightning flash, written by the weather; brightens the moon.
  double flash = 0;

  /// The two looks the sky tint cross-fades, and the last blend applied.
  EnvironmentSettings? night;
  EnvironmentSettings? dawn;
  double appliedDawn = -1;

  /// Shader time on the game clock, and on wall time (sky, HUD pulses).
  double time = 0;
  double wallTime = 0;

  /// Scratch for the shared beam parameters, reused every frame.
  final Vector4 beamInfo = Vector4.zero();
  final List<Vector4> beamSlots = List.generate(5, (_) => Vector4.zero());
}
