import 'dart:math' as math;

/// Shared 2D grid maths: 1 m cells over a 96×96 m square centred on the
/// island. `HeightGrid`, `LightMap` and `FlowField` all index the same way.
const int gridCells = 96;
const int gridCellCount = gridCells * gridCells;
const double gridOrigin = -48;
const double gridCellSize = 1;

int gridX(double x) => ((x - gridOrigin) / gridCellSize).floor();

int gridZ(double z) => ((z - gridOrigin) / gridCellSize).floor();

bool gridInside(int gx, int gz) =>
    gx >= 0 && gz >= 0 && gx < gridCells && gz < gridCells;

/// The cell index under (x, z), or -1 off the grid.
int gridIndexAt(double x, double z) {
  final gx = gridX(x), gz = gridZ(z);
  return gridInside(gx, gz) ? gz * gridCells + gx : -1;
}

double gridCenterX(int gx) => gridOrigin + (gx + 0.5) * gridCellSize;

double gridCenterZ(int gz) => gridOrigin + (gz + 0.5) * gridCellSize;

// ------------------------------------------------------------ yaw helpers
//
// Models are authored facing glTF +Z, which the scene importer bakes to
// engine −Z. A yaw θ is a rotation about +Y (Matrix4.rotationY), so a model
// with yaw θ faces (−sin θ, 0, −cos θ) and its local +X points
// (cos θ, 0, −sin θ).

double yawDirX(double yaw) => -math.sin(yaw);

double yawDirZ(double yaw) => -math.cos(yaw);

/// The yaw that faces a model along (dx, dz).
double yawToward(double dx, double dz) => math.atan2(-dx, -dz);

/// The world direction of a model's local +X for [yaw].
double yawRightX(double yaw) => math.cos(yaw);

double yawRightZ(double yaw) => -math.sin(yaw);

/// [a] wrapped into (−π, π].
double wrapAngle(double a) {
  var r = a % (2 * math.pi);
  if (r > math.pi) r -= 2 * math.pi;
  if (r <= -math.pi) r += 2 * math.pi;
  return r;
}

/// The signed shortest turn from [from] to [to].
double angleDelta(double from, double to) => wrapAngle(to - from);

/// Turns [current] toward [target] by at most [maxStep] radians.
double turnToward(double current, double target, double maxStep) {
  final d = angleDelta(current, target);
  if (d.abs() <= maxStep) return target;
  return wrapAngle(current + maxStep * d.sign);
}

/// Squared distance on the ground plane.
double distSq2(double ax, double az, double bx, double bz) {
  final dx = ax - bx, dz = az - bz;
  return dx * dx + dz * dz;
}

/// Distance from (px, pz) to the segment (ax, az)–(bx, bz).
double distToSegment(
  double px,
  double pz,
  double ax,
  double az,
  double bx,
  double bz,
) {
  final vx = bx - ax, vz = bz - az;
  final len2 = vx * vx + vz * vz;
  var t = len2 == 0 ? 0.0 : ((px - ax) * vx + (pz - az) * vz) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + vx * t - px, cz = az + vz * t - pz;
  return math.sqrt(cx * cx + cz * cz);
}

/// The ray parameter where (ox, oz) + t·(dx, dz) first enters the circle,
/// or null if it misses or the circle lies behind. (dx, dz) is unit length.
double? rayCircle(
  double ox,
  double oz,
  double dx,
  double dz,
  double cx,
  double cz,
  double r,
) {
  final fx = ox - cx, fz = oz - cz;
  final b = fx * dx + fz * dz;
  final c = fx * fx + fz * fz - r * r;
  final disc = b * b - c;
  if (disc < 0) return null;
  final s = math.sqrt(disc);
  final t0 = -b - s;
  if (t0 >= 0) return t0;
  final t1 = -b + s;
  return t1 >= 0 && c > 0 ? t1 : null;
}
