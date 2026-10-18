part of '../feedback.dart';

void installParticles(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _burstParticles,
    reads: {SceneTransform, Crab, Keeper},
    inSet: GameSets.feedback,
    runIf: hasResource<Fx>(),
  );
}

/// Every hit, kill, landing and blast throws particles: the crunch.
void _burstParticles(World world) {
  final fx = world.resource<Fx>();
  final rig = world.resource<CameraRig>();

  for (final strike in world.events<CrabBashed>()) {
    final p = strike.point;
    fx
      ..burst(FxKind.flash, p, count: 1, size: strike.exposed ? 1.6 : 1.1)
      ..burst(FxKind.spark, p, count: strike.exposed ? 40 : 26, spread: 1.6,
          speed: 1.4, tint: Vector3(3.2, 2.4, 1.3))
      ..burst(FxKind.ember, p, count: 30, spread: 1.4, speed: 2.4)
      ..burst(FxKind.fire, p, count: 6, spread: 0.8, speed: 2.5, size: 0.7)
      ..burst(FxKind.smoke, p + Vector3(0, 0.4, 0), count: 2, size: 0.6);
  }
  // A hunter's leap kicks up sand.
  for (final leap in world.events<CrabLeapt>()) {
    final t = world.tryGet<SceneTransform>(leap.crab);
    if (t == null) continue;
    fx.burst(FxKind.dust, Vector3(t.x, t.y, t.z), count: 5, spread: 0.3,
        dir: Vector3(0, 0.4, 0), speed: 0.9, radius: 0.2, size: 0.45);
  }

  // A bite on the keeper: a flash and a spray off the side it came from.
  final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;
  for (final bite in world.events<KeeperBitten>()) {
    if (keeper == null) break;
    final k = keeper.$2;
    final away = Vector3(k.x - bite.fromX, 0, k.z - bite.fromZ);
    if (away.length2 < 1e-6) away.setValues(0, 0, 1);
    away.normalize();
    final p = Vector3(k.x - away.x * 0.35, k.y + 0.9, k.z - away.z * 0.35);
    fx
      ..burst(FxKind.flash, p, count: 1, size: bite.hurt ? 1.4 : 0.7,
          tint: Vector3(3.0, 0.6, 0.4))
      ..burst(FxKind.droplet, p, count: bite.hurt ? 26 : 10, spread: 0.9,
          dir: away + Vector3(0, 0.6, 0), speed: bite.hurt ? 1.6 : 1.0,
          tint: Vector3(0.7, 0.08, 0.06));
  }
  for (final swing in world.events<LampBashed>()) {
    final p = swing.origin + Vector3(swing.dirX, -0.2, swing.dirZ) * 1.1;
    fx.burst(FxKind.ember, p, count: 8, spread: 0.9, speed: 1.2,
        dir: Vector3(swing.dirX, 0.2, swing.dirZ));
  }

  for (final hit in world.events<HarpoonHit>()) {
    final p = hit.point;
    switch (hit.kind) {
      case HarpoonTargetKind.crab:
        fx
          ..burst(FxKind.flash, p, count: 1, size: 0.9)
          ..burst(FxKind.droplet, p, count: 22, spread: 1.1)
          ..burst(FxKind.chip, p, count: 5, spread: 0.9, size: 0.8)
          ..burst(FxKind.spark, p, count: 10, spread: 1.2);
      case HarpoonTargetKind.mirror:
        fx
          ..burst(FxKind.flash, p, count: 1, size: 0.8)
          ..burst(FxKind.spark, p, count: 26, spread: 1.4,
              tint: Vector3(3.0, 3.0, 3.4));
      case HarpoonTargetKind.flotsam:
        fx
          ..burst(FxKind.splinter, p, count: 3, spread: 1.0, size: 0.6)
          ..burst(FxKind.droplet, p, count: 18, spread: 0.9,
              tint: Vector3(0.45, 0.6, 0.75))
          ..burst(FxKind.mist, p, count: 4, spread: 0.8, size: 0.7);
      case HarpoonTargetKind.prop:
        fx
          ..burst(FxKind.spark, p, count: 24, spread: 1.3)
          ..burst(FxKind.splinter, p, count: 4, spread: 1.0, size: 0.7)
          ..burst(FxKind.dust, p, count: 6, spread: 1.0, size: 0.6);
      case HarpoonTargetKind.ground || HarpoonTargetKind.miss:
        fx.burst(FxKind.dust, p, count: 8, spread: 0.9, size: 0.7);
    }
  }

  for (final killed in world.events<CrabKilled>()) {
    final p = killed.position.clone()..y += 0.4;
    final big = killed.type == CrabType.tideMother;
    fx
      ..burst(FxKind.flash, p, count: 1, size: big ? 3 : 1.4)
      ..burst(FxKind.droplet, p, count: big ? 80 : 36, spread: 1.3,
          speed: big ? 1.5 : 1)
      ..burst(FxKind.chip, p, count: big ? 30 : 10, spread: 1.0)
      ..burst(FxKind.smoke, p, count: big ? 10 : 3, spread: 0.8, size: 0.8);
  }

  for (final crack in world.events<ShellCracked>()) {
    final t = world.tryGet<SceneTransform>(crack.entity);
    if (t == null) continue;
    final p = Vector3(t.x, t.y + 0.6, t.z);
    fx
      ..burst(FxKind.chip, p, count: 14, spread: 1.0)
      ..burst(FxKind.spark, p, count: 20, spread: 1.5)
      ..burst(FxKind.smoke, p, count: 4, size: 0.7);
  }

  for (final exposed in world.events<CrabExposed>()) {
    final t = world.tryGet<SceneTransform>(exposed.entity);
    if (t == null) continue;
    final p = Vector3(t.x, t.y + 0.7, t.z);
    fx
      ..burst(FxKind.flash, p, count: 1, size: 1.8)
      ..burst(FxKind.spark, p, count: 26, spread: 1.6, speed: 1.3)
      ..burst(FxKind.mist, p, count: 8, spread: 1.0, size: 1.1);
  }

  for (final slam in world.events<SlamLanded>()) {
    final p = slam.position;
    fx
      ..burst(FxKind.dust, p, count: 26, spread: 0.15,
          dir: Vector3(0, 0.25, 0), speed: 1.6, radius: 0.8, size: 1.2)
      ..burst(FxKind.chip, p, count: 6, spread: 1.0, tint: null);
  }

  for (final boom in world.events<MothExploded>()) {
    final p = boom.position;
    fx
      ..burst(FxKind.flash, p, count: 2, size: 2.4)
      ..burst(FxKind.fire, p, count: 18, spread: 1.4, speed: 4, size: 1.1)
      ..burst(FxKind.ember, p, count: 40, spread: 1.6, speed: 3)
      ..burst(FxKind.smoke, p, count: 8, spread: 1.2, size: 1.2);
  }

  for (final landed in world.events<KeeperLanded>()) {
    final p = landed.position;
    final hard = landed.height.clamp(0.0, 2.0) / 2;
    fx.burst(FxKind.dust, p, count: 6 + (10 * hard).round(), spread: 0.12,
        dir: Vector3(0, 0.3, 0), speed: 0.8 + hard, radius: 0.3, size: 0.6);
    rig.addTrauma(feedbackLandTrauma * hard);
  }

  for (final broken in world.events<WreckBroken>()) {
    final p = broken.position.clone()..y += 0.5;
    if (broken.barrel) {
      fx
        ..burst(FxKind.flash, p, count: 3, size: 4)
        ..burst(FxKind.fire, p, count: 26, spread: 1.6, speed: 7, size: 1.5)
        ..burst(FxKind.ember, p, count: 60, spread: 1.6, speed: 4)
        ..burst(FxKind.spark, p, count: 40, spread: 1.8, speed: 1.6)
        ..burst(FxKind.splinter, p, count: 10, spread: 1.4, speed: 1.4)
        ..burst(FxKind.smoke, p, count: 12, spread: 1.4, size: 1.6)
        ..burst(FxKind.dust, p, count: 20, spread: 0.2, dir: Vector3(0, 0.2, 0),
            speed: 2.5, radius: 1, size: 1.4);
      rig
        ..addTrauma(feedbackBlastTrauma)
        ..addKick(0.05);
      world.resource<FeedbackState>().freeze(world.clock, feedbackBlastFreeze);
    } else {
      fx
        ..burst(FxKind.splinter, p, count: 12, spread: 1.2)
        ..burst(FxKind.dust, p, count: 10, spread: 1.0, size: 0.8);
      rig.addTrauma(0.12);
    }
  }

  for (final flare in world.events<LampFlare>()) {
    final dir = Vector3(flare.dirX, 0.05, flare.dirZ);
    fx
      ..burst(FxKind.flash, flare.origin + dir, count: 2, size: 3)
      ..burst(FxKind.spark, flare.origin + dir, count: 50, dir: dir,
          spread: 0.45, speed: 1.3, tint: Vector3(3.4, 2.8, 1.8))
      ..burst(FxKind.ember, flare.origin + dir * 2, count: 30, dir: dir,
          spread: 0.6, speed: 2);
    rig
      ..addTrauma(0.25)
      ..addKick(0.03);
  }

  for (final weak in world.events<WeakSpotHit>()) {
    fx
      ..burst(FxKind.flash, weak.point, count: 2, size: 1.6)
      ..burst(FxKind.spark, weak.point, count: 30, spread: 1.6, speed: 1.3,
          tint: Vector3(3.6, 3.0, 1.4))
      ..burst(FxKind.chip, weak.point, count: 8, spread: 1.2, speed: 1.2);
    rig.addTrauma(0.2);
    world.resource<FeedbackState>().freeze(world.clock, 0.06);
  }

  for (final picked in world.events<PickedUp>()) {
    fx.burst(FxKind.spark, picked.position + Vector3(0, 0.6, 0), count: 16,
        spread: 1.6, speed: 0.4,
        tint: picked.heart ? Vector3(3, 0.6, 0.7) : Vector3(3, 2.2, 0.9));
  }

  for (final snuffed in world.events<LampSnuffed>()) {
    final t = world.tryGet<SceneTransform>(snuffed.lamp);
    if (t == null) continue;
    fx.burst(FxKind.smoke, Vector3(t.x, t.y + 2.2, t.z), count: 6, size: 0.6,
        spread: 0.4);
  }

  for (final toppled in world.events<MirrorToppled>()) {
    final t = world.tryGet<SceneTransform>(toppled.mirror);
    if (t == null) continue;
    fx
      ..burst(FxKind.dust, Vector3(t.x, t.y + 0.2, t.z), count: 10, size: 0.8)
      ..burst(FxKind.spark, Vector3(t.x, t.y + 1, t.z), count: 14,
          tint: Vector3(3.0, 3.0, 3.4));
  }
}
