part of '../harpoon.dart';

enum HarpoonMode { ready, aiming, flying, reeling, reloading }

/// The harpoon gun on the keeper.
final class Harpoon {
  final Machine<HarpoonMode> mode = Machine(.ready);

  /// The bolt in flight, and its velocity (it drops a little as it flies).
  final Vector3 bolt = Vector3.zero();
  final Vector3 velocity = Vector3(0, 0, harpoonSpeed);
  double travelled = 0;

  /// What it struck and holds while reeling.
  Entity? hooked;
  HarpoonTargetKind hookKind = .miss;

  /// Whaler's Reel: where the keeper is being hauled to.
  Vector3? reelSelfTo;

  /// Crabs already pierced this shot (Barbed), and lashed by the chain
  /// this reel (Whiplash).
  final List<Entity> pierced = [];
  final List<Entity> lashed = [];

  @override
  String toString() => mode.toString();
}

/// The bolt and chain nodes, the chain's verlet rope, the gun's kick, and
/// the [darts] it fans out (Triple Bolt). [tip] is the bolt model's tip
/// along its +Z, out from the chain's anchor.
final class HarpoonVisual(
  final Node bolt,
  final double tip,
  final List<Node> links,
  final ChainRope rope,
  final NodeRack darts,
) {
  /// 0..1, set to 1 on a shot and sprung back down.
  double recoil = 0;

  /// The gun's resting local transform, captured once.
  Matrix4? gunRest;

  /// Seconds since the bolt came to rest and the chain began winding in.
  double retract = 0;

  /// The chain's slack (eased toward the mode's) and its paid-out length.
  double slack = harpoonChainSlackFlying;
  double length = 0;
}

/// A chain of point masses (verlet), pinned at the gun and at the bolt:
/// it pays out loose while the bolt flies, sags and swings as the keeper
/// moves, lies on the ground, and draws in while reeling. Winding back,
/// the far end is let go so the chain drags the bolt home.
final class ChainRope(final int count) {
  late final List<Vector3> points = [
    for (var i = 0; i < count; i++) Vector3.zero(),
  ];
  late final List<Vector3> previous = [
    for (var i = 0; i < count; i++) Vector3.zero(),
  ];
  bool live = false;

  /// Collapses the rope onto [at] (stowed).
  void reset(Vector3 at) {
    for (var i = 0; i < count; i++) {
      points[i].setFrom(at);
      previous[i].setFrom(at);
    }
  }

  /// One step: inertia and gravity, then [iterations] passes of length
  /// constraints with the start pinned (and the end, if [pinEnd]), the
  /// ground pushing up underneath.
  void step(
    double dt,
    Vector3 start,
    Vector3 end,
    double segment,
    double Function(double x, double z) ground, {
    bool pinEnd = true,
    int iterations = 10,
  }) {
    if (dt <= 0) return;
    final g = harpoonChainGravity * dt * dt;
    final keep = harpoonChainDamping;
    final free = pinEnd ? count - 1 : count;
    for (var i = 1; i < free; i++) {
      final p = points[i], q = previous[i];
      final vx = (p.x - q.x) * keep, vy = (p.y - q.y) * keep;
      final vz = (p.z - q.z) * keep;
      q.setFrom(p);
      p
        ..x += vx
        ..y += vy - g
        ..z += vz;
    }
    for (var it = 0; it < iterations; it++) {
      points.first.setFrom(start);
      if (pinEnd) points.last.setFrom(end);
      for (var i = 0; i < count - 1; i++) {
        final a = points[i], b = points[i + 1];
        final dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
        final d = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (d < 1e-6 || d <= segment) continue;
        final push = (d - segment) / d * 0.5;
        final pinA = i == 0, pinB = pinEnd && i + 1 == count - 1;
        final wa = pinA ? 0.0 : (pinB ? 1.0 : 0.5) * 2;
        final wb = pinB ? 0.0 : (pinA ? 1.0 : 0.5) * 2;
        a
          ..x += dx * push * wa
          ..y += dy * push * wa
          ..z += dz * push * wa;
        b
          ..x -= dx * push * wb
          ..y -= dy * push * wb
          ..z -= dz * push * wb;
      }
      for (var i = 1; i < free; i++) {
        final p = points[i];
        final floor = ground(p.x, p.z) + harpoonChainThickness;
        if (p.y < floor) {
          p.y = floor;
          // Friction: lying links drag rather than slide.
          final q = previous[i];
          q
            ..x = p.x + (q.x - p.x) * 0.4
            ..z = p.z + (q.z - p.z) * 0.4;
        }
      }
    }
    points.first.setFrom(start);
    if (pinEnd) points.last.setFrom(end);
  }
}

/// A dart fanned out beside the bolt (Triple Bolt): flies straight, hits
/// the first crab, stops at the ground.
final class Dart(final Vector3 position, final Vector3 velocity) {
  double travelled = 0;
}
