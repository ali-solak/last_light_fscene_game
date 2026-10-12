part of '../fx.dart';

void installFxPools(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _spawnFx,
      reads: const {},
      runIf: hasResource<Scene>().and(hasResource<FxTextures>()),
    )
    ..addSystem(
      Schedules.renderSync,
      _stepFx,
      reads: const {},
      runIf: hasResource<Fx>(),
    );
}

/// The wind pushes each kind by this much of its force (smoke and embers
/// carry, sparks barely).
const Map<FxKind, double> _windCarry = {
  .ember: 1.4,
  .smoke: 1.1,
  .dust: 0.8,
  .fire: 0.5,
  .mist: 1.2,
  .fog: 0.6,
  .rain: 2.4,
};

/// The wind accelerations, one per carried kind.
final class _FxWind(final Map<FxKind, AccelerationModule> modules);

/// Startup, visual: every pool's emitter on one root at the world origin.
void _spawnFx(World world) {
  final textures = world.resource<FxTextures>();
  final root = Node(name: 'fx');
  final pools = <FxKind, FxPool>{};
  final winds = <FxKind, AccelerationModule>{};
  for (final kind in FxKind.values) {
    final spec = fxSpecs[kind]!;
    final wind = _windCarry.containsKey(kind)
        ? (winds[kind] = AccelerationModule(Vector3.zero()))
        : null;
    final system = fxSystem(spec, wind: wind);
    pools[kind] = FxPool(spec, system);
    root.add(Node(name: 'fx_${kind.name}')..addComponent(_emitter(kind, spec,
        system, textures)));
  }
  setRenderLayer(root, RenderLayers.actors);
  world
    ..spawn([NodeRef(root)])
    ..insert(Fx(pools))
    ..insert(_FxWind(winds));
}

Component _emitter(
  FxKind kind,
  FxSpec spec,
  ParticleSystem system,
  FxTextures textures,
) {
  if (spec.mesh) {
    final wood = kind == FxKind.splinter;
    return MeshParticleEmitterComponent(
      system: system,
      geometries: wood
          ? [
              CuboidGeometry(Vector3(0.05, 0.05, 0.28)),
              CuboidGeometry(Vector3(0.09, 0.04, 0.18)),
              WedgeGeometry(Vector3(0.08, 0.05, 0.2)),
            ]
          : [
              WedgeGeometry(Vector3(0.14, 0.05, 0.11)),
              CuboidGeometry(Vector3(0.1, 0.04, 0.08)),
              WedgeGeometry(Vector3(0.08, 0.06, 0.12)),
            ],
      material: PhysicallyBasedMaterial()
        ..baseColorFactor = wood
            ? Vector4(0.34, 0.24, 0.15, 1)
            : Vector4(0.42, 0.12, 0.08, 1)
        ..roughnessFactor = wood ? 0.85 : 0.45
        ..metallicFactor = 0
        ..emissiveFactor = wood
            ? Vector4(0, 0, 0, 1)
            : Vector4(0.25, 0.05, 0.02, 1),
    )..paused = true;
  }
  final texture = switch (kind) {
    .smoke || .dust || .mist || .fog when spec.flipbook > 0 => textures.smoke,
    .fire => textures.flame,
    _ => textures.dot,
  };
  final material = SpriteMaterial(colorTexture: texture)
    ..blendMode = spec.additive ? SpriteBlendMode.additive : SpriteBlendMode.alpha
    ..softDepthFade = spec.softDepth
    // Fog banks thin out as the camera walks into them.
    ..cameraNearFade = kind == FxKind.fog ? 4.0 : 0.0;
  final grid = spec.flipbook >= 64 ? 8 : (spec.flipbook > 0 ? 4 : 1);
  return ParticleEmitterComponent(system: system, material: material)
    ..paused = true
    ..facing = spec.facing
    ..velocityStretch = spec.stretch
    ..flipbookColumns = grid
    ..flipbookRows = grid
    ..flipbookBlend = spec.flipbook > 0
    ..randomFlipX = spec.flipbook > 0;
}

/// Render sync: steps every pool on the game clock (slow motion and
/// hitstop hold the sparks mid-air) and blows the wind through them.
void _stepFx(World world) {
  final fx = world.resource<Fx>();
  final dt = world.delta;
  if (world.tryResource<Wind>() case final wind?) {
    final modules = world.resource<_FxWind>().modules;
    for (final MapEntry(key: kind, value: module) in modules.entries) {
      final carry = _windCarry[kind]! * 2.2;
      module.acceleration.setValues(wind.x * carry, 0, wind.z * carry);
    }
  }
  for (final pool in fx.pools.values) {
    if (pool.alive > 0) pool.system.step(dt);
  }
}
