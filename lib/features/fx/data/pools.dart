part of '../fx.dart';

/// The kinds of particle the world can throw.
enum FxKind {
  /// Hot metal and stone sparks, streaking and falling.
  spark,

  /// Embers rising and swirling off fire.
  ember,

  /// A short bright bloom at a hit or a muzzle.
  flash,

  /// Billowing dark smoke.
  smoke,

  /// Sand kicked up: landings, slams, crabs digging.
  dust,

  /// Flame tongues.
  fire,

  /// Brine droplets from a hurt crab, or water.
  droplet,

  /// Soft spray and mist.
  mist,

  /// Tumbling shell chips.
  chip,

  /// Tumbling wood splinters.
  splinter,

  /// Big slow banks of sea fog drifting over the ground.
  fog,

  /// Rain streaks.
  rain,
}

/// One kind's look and defaults. Colours come from [tint] (per burst) times
/// the brightness/alpha [envelope] over life.
final class FxSpec({
  required final int capacity,
  required final (double, double) life,
  required final (double, double) speed,
  required final (double, double) size,
  required final Vector3 tint,
  required final List<(double, double, double)> envelope,
  final double gravity = 0,
  final double drag = 0,
  final double turbulence = 0,
  final double spin = 0,
  final List<(double, double)>? grow,
  final int flipbook = 0,
  final bool additive = true,
  final BillboardFacing facing = BillboardFacing.spherical,
  final double stretch = 0,
  final double softDepth = 0,
  final bool mesh = false,
});

/// Every kind's spec. Tuned for a dark night: additive kinds glow over the
/// bloom threshold, alpha kinds stay dim.
final Map<FxKind, FxSpec> fxSpecs = {
  .spark: FxSpec(
    capacity: 512,
    life: (0.25, 0.6),
    speed: (5, 11),
    size: (0.04, 0.08),
    tint: Vector3(4.2, 2.1, 0.6),
    envelope: const [(0, 1, 1), (0.5, 0.75, 0.9), (1, 0.3, 0)],
    gravity: -12,
    drag: 1.0,
    facing: BillboardFacing.velocityStretched,
    stretch: 0.045,
  ),
  .ember: FxSpec(
    capacity: 512,
    life: (0.9, 2.0),
    speed: (0.8, 2.4),
    size: (0.03, 0.06),
    tint: Vector3(4.0, 1.8, 0.45),
    envelope: const [
      (0, 1, 0),
      (0.06, 1, 1),
      (0.25, 0.8, 0.3),
      (0.4, 1, 1),
      (0.7, 0.8, 0.8),
      (1, 0.4, 0),
    ],
    gravity: 0.9,
    drag: 0.5,
    turbulence: 3.5,
    facing: BillboardFacing.velocityStretched,
    stretch: 0.04,
  ),
  .flash: FxSpec(
    capacity: 64,
    life: (0.1, 0.18),
    speed: (0, 0),
    size: (1.2, 1.6),
    tint: Vector3(3.0, 2.2, 1.4),
    envelope: const [(0, 1, 1), (1, 0.2, 0)],
    grow: const [(0, 0.6), (1, 1.4)],
  ),
  .smoke: FxSpec(
    capacity: 256,
    life: (1.8, 3.2),
    speed: (0.4, 1.2),
    size: (0.8, 1.3),
    tint: Vector3(0.09, 0.085, 0.09),
    envelope: const [(0, 1, 0), (0.12, 1, 0.45), (0.6, 0.8, 0.3), (1, 0.6, 0)],
    gravity: 0.45,
    drag: 0.9,
    turbulence: 0.6,
    spin: 0.4,
    grow: const [(0, 0.6), (1, 2.4)],
    flipbook: 16,
    additive: false,
    softDepth: 0.6,
  ),
  .dust: FxSpec(
    capacity: 256,
    life: (0.7, 1.3),
    speed: (1.5, 4.0),
    size: (0.5, 0.9),
    tint: Vector3(0.42, 0.37, 0.30),
    envelope: const [(0, 1, 0), (0.1, 1, 0.5), (1, 0.8, 0)],
    gravity: -0.6,
    drag: 3.2,
    spin: 0.6,
    grow: const [(0, 0.5), (1, 2.2)],
    flipbook: 16,
    additive: false,
    softDepth: 0.4,
  ),
  .fire: FxSpec(
    capacity: 768,
    life: (0.8, 1.3),
    speed: (0.1, 0.35),
    size: (1.2, 1.8),
    tint: Vector3(1.0, 0.82, 0.62),
    envelope: const [(0, 1.1, 0), (0.1, 1.1, 0.95), (0.7, 0.9, 0.8), (1, 0.6, 0)],
    gravity: 1.1,
    drag: 1.4,
    turbulence: 1.2,
    grow: const [(0, 0.6), (0.3, 1), (1, 0.75)],
    flipbook: 64,
    facing: BillboardFacing.axisLocked,
  ),
  .droplet: FxSpec(
    capacity: 384,
    life: (0.35, 0.75),
    speed: (2.5, 6.0),
    size: (0.05, 0.11),
    tint: Vector3(0.35, 1.6, 1.3),
    envelope: const [(0, 1, 1), (0.7, 0.8, 0.8), (1, 0.4, 0)],
    gravity: -14,
    drag: 0.4,
    facing: BillboardFacing.velocityStretched,
    stretch: 0.03,
  ),
  .mist: FxSpec(
    capacity: 192,
    life: (0.6, 1.2),
    speed: (0.5, 2.0),
    size: (0.6, 1.1),
    tint: Vector3(0.5, 0.6, 0.7),
    envelope: const [(0, 1, 0), (0.15, 1, 0.25), (1, 1, 0)],
    gravity: -0.8,
    drag: 2.0,
    grow: const [(0, 0.6), (1, 1.8)],
    additive: false,
    softDepth: 0.5,
  ),
  .fog: FxSpec(
    capacity: 96,
    life: (9, 14),
    speed: (0.05, 0.25),
    size: (5, 8.5),
    tint: Vector3(0.32, 0.4, 0.55),
    envelope: const [(0, 1, 0), (0.25, 1, 0.12), (0.75, 1, 0.1), (1, 1, 0)],
    drag: 0.4,
    spin: 0.05,
    grow: const [(0, 0.8), (1, 1.4)],
    flipbook: 16,
    additive: false,
    softDepth: 2.0,
  ),
  .rain: FxSpec(
    capacity: 900,
    life: (0.55, 0.8),
    speed: (16, 20),
    size: (0.025, 0.035),
    tint: Vector3(0.55, 0.62, 0.75),
    envelope: const [(0, 1, 0.5), (0.9, 1, 0.45), (1, 1, 0)],
    additive: false,
    facing: BillboardFacing.velocityStretched,
    stretch: 0.045,
  ),
  .chip: FxSpec(
    capacity: 160,
    life: (1.4, 2.2),
    speed: (3, 7),
    size: (0.6, 1.3),
    tint: Vector3(1, 1, 1),
    envelope: const [(0, 1, 1), (1, 1, 1)],
    gravity: -11,
    spin: 14,
    mesh: true,
  ),
  .splinter: FxSpec(
    capacity: 160,
    life: (1.6, 2.6),
    speed: (3, 8),
    size: (0.7, 1.4),
    tint: Vector3(1, 1, 1),
    envelope: const [(0, 1, 1), (1, 1, 1)],
    gravity: -11,
    spin: 12,
    mesh: true,
  ),
};

/// One kind's world-space particle system. Bursts write particles straight
/// into its storage, so one emitter serves every hit on the island.
final class FxPool(final FxSpec spec, final ParticleSystem system) {
  final math.Random _rng = math.Random(7);

  double _range((double, double) r) =>
      r.$1 + (r.$2 - r.$1) * _rng.nextDouble();

  /// Throws [count] particles from [at], headed along [dir] (up by default)
  /// within [spread] (0 a line, 1 a hemisphere, 2 everywhere).
  void burst(
    Vector3 at, {
    int count = 10,
    Vector3? dir,
    double spread = 0.6,
    double speed = 1,
    double size = 1,
    double life = 1,
    double radius = 0,
    Vector3? tint,
  }) {
    final s = system.storage;
    final colour = tint ?? spec.tint;
    final dx = dir?.x ?? 0, dy = dir?.y ?? 1, dz = dir?.z ?? 0;
    for (var n = 0; n < count; n++) {
      final i = s.spawn();
      if (i < 0) return;
      // A random unit vector, blended toward the direction by the spread.
      final u = _rng.nextDouble() * 2 - 1;
      final a = _rng.nextDouble() * math.pi * 2;
      final r = math.sqrt(1 - u * u);
      var vx = dx + math.cos(a) * r * spread;
      var vy = dy + u * spread;
      var vz = dz + math.sin(a) * r * spread;
      final len = math.sqrt(vx * vx + vy * vy + vz * vz);
      final v = len < 1e-6 ? 0.0 : _range(spec.speed) * speed / len;
      vx *= v;
      vy *= v;
      vz *= v;
      final o = radius * _rng.nextDouble();
      final scale = _range(spec.size) * size;
      s
        ..random01[i] = _rng.nextDouble()
        ..age[i] = 0
        ..lifetime[i] = math.max(0.05, _range(spec.life) * life)
        ..posX[i] = at.x + math.cos(a) * r * o
        ..posY[i] = at.y + u.abs() * o * 0.5
        ..posZ[i] = at.z + math.sin(a) * r * o
        ..velX[i] = vx
        ..velY[i] = vy
        ..velZ[i] = vz
        ..size[i] = scale
        ..baseSize[i] = scale
        ..rotation[i] = _rng.nextDouble() * math.pi * 2
        ..angularVelocity[i] = (_rng.nextDouble() * 2 - 1) * spec.spin
        ..frame[i] = 0
        // A billboard's tint rides the (otherwise unused) axis columns,
        // which the storage keeps in step when it compacts; a mesh tumbles
        // about its axis instead.
        ..axisX[i] = spec.mesh ? math.cos(a) * r : colour.x
        ..axisY[i] = spec.mesh ? u : colour.y
        ..axisZ[i] = spec.mesh ? math.sin(a) * r : colour.z
        ..colorR[i] = colour.x
        ..colorG[i] = colour.y
        ..colorB[i] = colour.z
        ..colorA[i] = 0;
    }
  }

  int get alive => system.storage.aliveCount;
}

/// Every kind's pool; inserted by the startup system when a scene exists.
final class Fx(final Map<FxKind, FxPool> pools) {
  FxPool operator [](FxKind kind) => pools[kind]!;

  /// [FxPool.burst] on [kind].
  void burst(
    FxKind kind,
    Vector3 at, {
    int count = 10,
    Vector3? dir,
    double spread = 0.6,
    double speed = 1,
    double size = 1,
    double life = 1,
    double radius = 0,
    Vector3? tint,
  }) => pools[kind]?.burst(
    at,
    count: count,
    dir: dir,
    spread: spread,
    speed: speed,
    size: size,
    life: life,
    radius: radius,
    tint: tint,
  );
}

/// Colour over life from the per-particle tint and a brightness/alpha
/// envelope: `(t, brightness, alpha)` stops.
final class _TintEnvelope extends ParticleModule {
  const _TintEnvelope(this.stops);

  final List<(double, double, double)> stops;

  @override
  void update(ParticleStorage storage, double dt) {
    final n = storage.aliveCount;
    for (var i = 0; i < n; i++) {
      final life = storage.lifetime[i];
      final t = life > 0 ? storage.age[i] / life : 1.0;
      var b = stops.last.$2, a = stops.last.$3;
      for (var k = 1; k < stops.length; k++) {
        final (t1, b1, a1) = stops[k];
        if (t <= t1) {
          final (t0, b0, a0) = stops[k - 1];
          final f = t1 > t0 ? (t - t0) / (t1 - t0) : 1.0;
          b = b0 + (b1 - b0) * f;
          a = a0 + (a1 - a0) * f;
          break;
        }
      }
      storage
        ..colorR[i] = storage.axisX[i] * b
        ..colorG[i] = storage.axisY[i] * b
        ..colorB[i] = storage.axisZ[i] * b
        ..colorA[i] = a;
    }
  }
}

/// Builds [spec]'s particle system: no spawner of its own, only physics and
/// the over-life modules; bursts fill it.
ParticleSystem fxSystem(FxSpec spec, {AccelerationModule? wind}) =>
    ParticleSystem(
      maxParticles: spec.capacity,
      shape: PointEmitterShape(),
      spawner: Spawner(),
      gravity: Vector3(0, spec.gravity, 0),
      modules: [
        ?wind,
        if (spec.drag > 0) LinearDragModule(spec.drag),
        if (spec.turbulence > 0)
          TurbulenceModule(
            strength: spec.turbulence,
            frequency: 1.4,
            scroll: Vector3(0, 0.8, 0),
            seed: spec.capacity,
          ),
        if (spec.spin > 0) const RotationModule(),
        if (spec.flipbook > 0) FlipbookModule(frameCount: spec.flipbook),
        if (spec.grow case final grow?)
          SizeOverLifeModule(
            CurveFloat(
              ParticleCurve([
                for (final (t, v) in grow) ParticleKeyframe(t, v),
              ]),
            ),
          ),
        _TintEnvelope(spec.envelope),
      ],
    );
