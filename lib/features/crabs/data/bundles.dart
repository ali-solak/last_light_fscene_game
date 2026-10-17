part of '../crabs.dart';

/// Everything a crab of [type] carries. Gameplay only; the model is put on
/// by the visual dressing system when a scene exists.
List<Object> crabBundle(CrabType type, Vector3 at, {bool brood = false}) {
  final stats = crabStats[type]!;
  return [
    Crab(type),
    Health(stats.hp),
    CrabBrain(),
    CrabBody(stats.size, stats.speed),
    LightExposure(),
    if (crabShroudSeconds[type] case final s?) Shroud(s),
    SceneTransform.fromVector(at)..setUniformScale(stats.scale),
    const DespawnOnExit(GameStatus.night),
    ...switch (type) {
      .scuttler => const [HuntsKeeper()],
      .tarback => [const FleesLight(), TarShell()],
      .snuffer => const [
        FleesLight(),
        SnuffsLamps(),
        CowerThreshold(crabSnufferCowerThreshold),
      ],
      .basher => const [FleesLight(), KnocksMirrors()],
      .burrower => const [FleesLight(), Burrows()],
      .mothCrab => const [SeeksLight()],
      .glassback => const [ReflectsBeam()],
      .tideMother => [const Boss(), BossBrain()],
    },
    if (brood) const BroodSpawn(),
  ];
}

List<Object> tarSplatBundle(double x, double y, double z, double yaw) => [
  const TarSplat(),
  SceneTransform(x, y, z)..setRotationY(yaw),
  DespawnAfter(crabDecalSeconds),
  const DespawnOnExit(GameStatus.night),
];
