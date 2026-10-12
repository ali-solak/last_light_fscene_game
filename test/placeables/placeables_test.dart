import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/common/interact.dart';
import 'package:last_light/common/states.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/harpoon/harpoon.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/keeper/keeper.dart' show KeeperBrain, KeeperMode;
import 'package:last_light/features/lamps/lamps.dart';
import 'package:last_light/features/light/light.dart';
import 'package:last_light/features/mirrors/mirrors.dart';
import 'package:last_light/features/nights/nights.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../support/harness.dart';

void main() {
  group('mirrors', () {
    late TestGame game;
    setUp(() => game = makeGame()..toDawnBuild());

    /// Open walkable ground near the keeper's spawn, spots 3 m apart.
    List<(double, double)> openGround() {
      final grid = game.world.resource<HeightGrid>();
      final spawn = game.world.resource<IslandAnchors>().keeperSpawn;
      final spots = <(double, double)>[];
      for (var dz = -8.0; dz <= 8 && spots.length < 4; dz += 3) {
        for (var dx = -8.0; dx <= 8 && spots.length < 4; dx += 3) {
          final x = spawn.x + dx, z = spawn.z + dz;
          if (!grid.walkableXZ(x, z) || grid.sample(x, z) < 0.5) continue;
          final clear = !game.world
              .query<SceneTransform>()
              .having<BrazierStand>()
              .any((_, t) => distSq2(t.x, t.z, x, z) < 9);
          if (clear) spots.add((x, z));
        }
      }
      return spots;
    }

    void tap(double x, double z) {
      game.emit(BuildAt(x, z, BuildPhase.tap));
      game.frame();
      game.frame();
    }

    test('placing is limited by mirrorsOwned', () {
      expect(game.status, GameStatus.dawnBuild);
      final p = openGround();
      expect(p.length, greaterThanOrEqualTo(3));
      tap(p[0].$1, p[0].$2);
      tap(p[1].$1, p[1].$2);
      tap(p[2].$1, p[2].$2);
      expect(game.world.query<Mirror>().count(), 2);
      // A spare mirror lets the third go down.
      game.world.resource<Run>().mirrorsOwned = 3;
      tap(p[2].$1, p[2].$2);
      expect(game.world.query<Mirror>().count(), 3);
      // Tapping a placed one picks it back up.
      tap(p[0].$1, p[0].$2);
      expect(game.world.query<Mirror>().count(), 2);
    });

    test('the lamp tool never stands a mirror', () {
      game.world.resource<BuildSelection>().tool = BuildTool.lamp;
      final p = openGround().first;
      tap(p.$1, p.$2);
      expect(game.world.query<Mirror>().count(), 0);
    });

    test('mirrors keep off the water and away from each other', () {
      final p = openGround().first;
      tap(p.$1, p.$2);
      tap(p.$1 + 1.8, p.$2); // too close, but not on it
      expect(game.world.query<Mirror>().count(), 1);
      final spawn = game.world.resource<SpawnPoints>().points.first;
      tap(spawn.x, spawn.z); // the landing point is out in the surf
      expect(game.world.query<Mirror>().count(), 1);
    });

    test('dragging sets where the light goes, in 15° steps, and the mirror '
        'turns to throw it exactly there', () {
      // Open flat ground in full view of the lighthouse.
      game
        ..flatGround(1)
        ..pinBeam(on: false);
      const p = (10.0, 4.0);
      tap(p.$1, p.$2);
      game.emit(BuildAt(p.$1 + 0.2, p.$2, BuildPhase.dragStart));
      game.frame();
      game.emit(BuildAt(p.$1 + 3, p.$2 + 1, BuildPhase.drag));
      game.frame();
      game.seconds(1);
      final (entity, mirror) = game.world.query<Mirror>().single;
      final step = 15 * math.pi / 180;
      final throwYaw = mirror.throwYaw!;
      expect((throwYaw / step - (throwYaw / step).round()).abs(), lessThan(1e-9));
      expect(mirror.yaw, closeTo(mirror.targetYaw, 0.01));
      // At dawn the lighthouse primes it: the light leaves along the throw.
      final out = game.world
          .resource<BeamPath>()
          .segments
          .where((s) => s.from == entity)
          .firstOrNull;
      expect(out, isNotNull);
      final dx = out!.x1 - out.x0, dz = out.z1 - out.z0;
      final len = math.sqrt(dx * dx + dz * dz);
      expect(dx / len, closeTo(yawDirX(throwYaw), 0.02));
      expect(dz / len, closeTo(yawDirZ(throwYaw), 0.02));
    });
  });

  group('night', () {
    late TestGame game;
    setUp(() => game = makeGame()..quietNight());

    test('harpooning a mirror drags its targetYaw toward the keeper', () {
      final e = game.world.spawn([
        Mirror(0),
        SceneTransform(game.keeperAt.x - 8, game.keeperAt.y, game.keeperAt.z),
        Interactable(InteractKind.mirror),
      ]);
      game.frame();
      final mirror = game.world.get<Mirror>(e);
      final before = mirror.targetYaw;
      final t = game.world.get<SceneTransform>(e);
      game.aimAt(t.x, t.z);
      game.world.buttons<KeeperAction>().press(KeeperAction.harpoon);
      game.seconds(0.2);
      game.world.buttons<KeeperAction>().release(KeeperAction.harpoon);
      game.seconds(0.6);
      final want = yawToward(game.keeperAt.x - t.x, game.keeperAt.z - t.z);
      expect(mirror.targetYaw, isNot(closeTo(before, 0.01)));
      expect(angleDelta(mirror.targetYaw, want).abs(),
          lessThan(angleDelta(before, want).abs()));
    });

    test('holding interact on a mirror swings its light to where he looks, '
        'and letting go sets it', () {
      final k = game.keeperAt;
      final e = game.world.spawn([
        Mirror(0, throwYaw: 0),
        SceneTransform(k.x + 1, k.y, k.z),
        Interactable(InteractKind.mirror, continuous: true),
      ]);
      // Look off to his left (−X): the light should go that way.
      game
        ..aimAt(k.x - 8, k.z)
        ..frame();
      final buttons = game.world.buttons<KeeperAction>()
        ..setPressed(KeeperAction.interact, true);
      game.world.buffer<KeeperAction>().record(KeeperAction.interact);
      game.seconds(1);
      final mirror = game.world.get<Mirror>(e);
      expect(mirror.throwYaw!, closeTo(math.pi / 2, 1e-3));
      buttons.setPressed(KeeperAction.interact, false);
      game.seconds(0.2);
      expect(game.world.get<KeeperBrain>(game.keeper).mode.state,
          isNot(KeeperMode.interacting));
      game.aimAt(k.x + 8, k.z);
      game.seconds(0.5);
      expect(mirror.throwYaw!, closeTo(math.pi / 2, 1e-3));
    });

    test('a slam topples mirrors and snuffs lamps around it', () {
      final mirror = game.world.spawn([Mirror(0), SceneTransform(10, 0, 10)]);
      final lamp = game.world.spawn([LampPost(), SceneTransform(11, 0, 10)]);
      game.frame();
      game.emit(SlamLanded(mirror, Vector3(10, 0, 9), 4, 6));
      game.frame();
      expect(game.world.get<Mirror>(mirror).upright, isFalse);
      expect(game.world.get<LampPost>(lamp).lit, isFalse);
    });

    test('a snuffed lamp relights when the keeper holds interact', () {
      final relit = <LampRelit>[];
      final g = makeGame(probes: [collect(relit)])..quietNight();
      final k = g.keeperAt;
      final lamp = g.world.spawn(lampBundle(k.x + 1, k.y, k.z));
      g.frame();
      g.emit(LampStruck(lamp));
      g.frame();
      expect(g.world.get<LampPost>(lamp).lit, isFalse);
      g.world.buffer<KeeperAction>().record(KeeperAction.interact);
      g.seconds(1);
      g.frame();
      expect(g.world.get<LampPost>(lamp).lit, isTrue);
      expect(relit, hasLength(1));
    });

    test('the harpoon spears a crab, damages it and reels it in', () {
      final hits = <HarpoonHit>[];
      final g = makeGame(probes: [collect(hits)])..quietNight();
      final k = g.keeperAt;
      final crab = g.crab(CrabType.basher, k.x - 8, k.z);
      g.aimAt(k.x - 8, k.z);
      g.world.buttons<KeeperAction>().press(KeeperAction.harpoon);
      g.seconds(0.1);
      g.world.buttons<KeeperAction>().release(KeeperAction.harpoon);
      g.seconds(0.3);
      g.frame();
      expect(hits.first.kind, HarpoonTargetKind.crab);
      expect(hits.first.target, crab);
      final health = g.world.get<Health>(crab);
      expect(health.current, closeTo(health.max - harpoonDamage, 0.5));
      g.seconds(1.2);
      final c = g.world.get<SceneTransform>(crab);
      expect(math.sqrt(distSq2(c.x, c.z, k.x, k.z)), lessThan(5));
      final harpoon = g.world.get<Harpoon>(g.keeper);
      g.seconds(2);
      expect(harpoon.mode.state, HarpoonMode.ready);
    });
  });

  group('lamps', () {
    test('placement keeps lamps 3 m apart and within the supply', () {
      final game = makeGame()..toDawnBuild();
      game.world.resource<BuildSelection>().tool = BuildTool.lamp;
      final grid = game.world.resource<HeightGrid>();
      // Open plateau ground near the lighthouse.
      const x = 6.0, z = 6.0;
      expect(grid.walkableXZ(x, z), isTrue);
      void tap(double x, double z) {
        game.emit(BuildAt(x, z, BuildPhase.tap));
        game.frame();
        game.frame();
      }

      tap(x, z);
      tap(x + 1.5, z); // too close
      expect(game.world.query<LampPost>().count(), 1);
      tap(x + 4, z);
      tap(x + 8, z); // over the supply of 2
      expect(game.world.query<LampPost>().count(), 2);
    });
  });

  group('bell', () {
    test('ringing the bell at dawn calls the dusk, then the night', () {
      final game = makeGame()..toDawnBuild();
      game.emit(const BellRung());
      game.frame();
      game.frame();
      expect(game.status, GameStatus.dusk);
      game.seconds(2.6);
      game.frame();
      expect(game.status, GameStatus.night);
    });
  });
}
