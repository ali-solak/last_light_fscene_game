import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/lamps/lamps.dart';
import 'package:last_light/features/light/light.dart';
import 'package:last_light/features/mirrors/mirrors.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../support/harness.dart';

/// The beam pointing along +X from the origin.
const double alongX = -math.pi / 2;

/// Mirror yaws that turn +X into +Z, and +Z into +X.
const double turnXtoZ = 3 * math.pi / 4;
const double turnZtoX = -math.pi / 4;

void main() {
  late TestGame game;
  setUp(() {
    game = makeGame()
      ..flatGround()
      ..pinBeam(yaw: alongX);
  });

  Entity mirror(double x, double z, double yaw) =>
      game.world.spawn([Mirror(yaw), SceneTransform(x, 0, z)]);

  BeamPath path() => game.world.resource<BeamPath>();

  test('the beam stops at a rock', () {
    game.world.insert(Occluders([const Occluder(10, 0, 1)]));
    game.frame();
    final first = path().segments.first;
    expect(first.x1, closeTo(9, 0.05));
    expect(path().segments, hasLength(1));
  });

  test('one mirror at 45° bounces the beam 90°', () {
    mirror(10, 0, turnXtoZ);
    game.frame();
    final segments = path().segments;
    expect(segments, hasLength(2));
    final bounced = segments[1];
    final dx = bounced.x1 - bounced.x0, dz = bounced.z1 - bounced.z0;
    final len = math.sqrt(dx * dx + dz * dz);
    expect(dx / len, closeTo(0, 1e-6));
    expect(dz / len, closeTo(1, 1e-6));
  });

  test('the beam bounces 4 times at most', () {
    final m = [
      mirror(6, 0, turnXtoZ),
      mirror(6, 5, turnZtoX),
      mirror(11, 5, turnXtoZ),
      mirror(11, 10, turnZtoX),
      mirror(16, 10, turnXtoZ),
    ];
    game.frame();
    expect(path().bounces, 4);
    expect(path().mirrorsHit, m.sublist(0, 4));
    expect(path().segments.last.intensity, closeTo(4 * math.pow(0.85, 4), 1e-6));
  });

  test('a toppled mirror does not reflect', () {
    final e = mirror(10, 0, turnXtoZ);
    game.frame();
    expect(path().segments, hasLength(2));
    game.world.get<Mirror>(e).upright = false;
    game.frame();
    expect(path().segments, hasLength(1));
  });

  group('mirror relay', () {
    /// A mirror at (10, 0) turning the beam toward +Z; the beam caught on it
    /// for a moment, then swung away.
    Entity caughtThenSwungAway() {
      final e = mirror(10, 0, turnXtoZ);
      game.frame();
      game.frame();
      expect(game.world.get<CaughtLight>(e).live, isTrue);
      game.world.resource<Beam>().yaw = alongX + math.pi;
      game.frame();
      return e;
    }

    bool lit(double x, double z) =>
        game.world.resource<LightMap>().beamAt(x, z);

    test('a caught mirror keeps throwing the light after the beam leaves', () {
      final e = caughtThenSwungAway();
      expect(game.world.get<CaughtLight>(e).live, isFalse);
      expect(lit(10, 8), isTrue);
      game.seconds(mirrorHoldSeconds - mirrorFadeSeconds - 0.5);
      expect(lit(10, 8), isTrue);
      game.seconds(mirrorFadeSeconds + 1);
      expect(lit(10, 8), isFalse);
    });

    test('turning a mirror swings the light it holds', () {
      final e = caughtThenSwungAway();
      game.world.get<Mirror>(e)
        ..yaw = turnXtoZ + math.pi / 2
        ..targetYaw = turnXtoZ + math.pi / 2;
      game.frame();
      expect(lit(10, 8), isFalse);
      expect(lit(10, -8), isTrue);
    });

    test('a relay lights the next mirror in the chain', () {
      mirror(10, 0, turnXtoZ);
      final second = mirror(10, 10, turnZtoX);
      game.frame();
      game.frame();
      game.world.resource<Beam>().yaw = alongX + math.pi;
      game.seconds(1);
      expect(game.world.get<CaughtLight>(second).live, isTrue);
      expect(lit(16, 10), isTrue);
    });

    test('two facing mirrors cannot hold each other lit forever', () {
      mirror(10, 0, turnXtoZ);
      // Faces straight back down: the light ping-pongs between the two.
      mirror(10, 10, 0);
      game.frame();
      game.frame();
      game.world.resource<Beam>().yaw = alongX + math.pi;
      game.seconds(mirrorHoldSeconds + 1);
      expect(lit(10, 5), isFalse);
    });

    test('a toppled mirror drops what it holds', () {
      final e = caughtThenSwungAway();
      game.world.get<Mirror>(e).upright = false;
      game.frame();
      expect(lit(10, 8), isFalse);
      expect(game.world.get<CaughtLight>(e).hold, 0);
    });
  });

  group('signal braziers', () {
    final lit = <BrazierLit>[];
    setUp(() {
      lit.clear();
      game = makeGame(probes: [collect(lit)])
        ..quietNight()
        ..flatGround()
        ..pinBeam(yaw: alongX);
      game.placeKeeper(-40, -40);
    });

    Entity brazier(double x, double z) {
      final e = game.world.spawn([const BrazierStand(1), SceneTransform(x, 0, z)]);
      game.frame();
      return e;
    }

    test('the lighthouse sweep alone never kindles one', () {
      final b = brazier(15, 0);
      game.seconds(2);
      expect(game.world.get<Brazier>(b).lit, isFalse);
      expect(lit, isEmpty);
    });

    test('thrown light kindles it; it burns on and lights the ground', () {
      mirror(10, 0, turnXtoZ);
      final b = brazier(10, 9);
      game.seconds(1);
      game.frame();
      expect(game.world.get<Brazier>(b).lit, isTrue);
      expect(lit.single.brazier, b);
      // The beam swings away; the fire stays.
      game.world.resource<Beam>().yaw = alongX + math.pi;
      game.seconds(mirrorHoldSeconds + 2);
      expect(game.world.get<Brazier>(b).lit, isTrue);
      final map = game.world.resource<LightMap>();
      expect(map.intensityAt(10, 9), greaterThan(1.5));
      expect(map.flagsAt(10, 9) & LightFlags.burn, isNot(0));
      expect(map.intensityAt(10 + brazierLightRadius - 1, 9), greaterThan(0));
    });

    test('a beam skimming far above the bowl misses it', () {
      mirror(10, 0, turnXtoZ);
      final b = brazier(10, 9);
      game.world.get<SceneTransform>(b).y = -6;
      game.seconds(1);
      expect(game.world.get<Brazier>(b).lit, isFalse);
    });
  });

  test('snuffed lamps add no light', () {
    final lamp = game.world.spawn([LampPost(), SceneTransform(20, 0, 20)]);
    game.frame();
    final map = game.world.resource<LightMap>();
    expect(map.intensityAt(20, 20), greaterThan(0.9));
    game.world.get<LampPost>(lamp).lit = false;
    game.frame();
    expect(map.intensityAt(20, 20), 0);
    expect(map.intensityAt(22, 20), 0);
  });

  test('exposure sampling matches the cells', () {
    game.world.spawn([LampPost(), SceneTransform(20, 0, 20)]);
    final crab = game.world.spawn(crabBundle(CrabType.scuttler, Vector3(22, 0, 21)));
    game.frame();
    game.frame();
    final map = game.world.resource<LightMap>();
    final exposure = game.world.get<LightExposure>(crab);
    expect(exposure.intensity, map.intensityAt(22, 21));
    expect(exposure.intensity, greaterThan(0.4));
    expect(exposure.beam, isFalse);
  });

  test('cells in the beam carry the beam flag at intensity 4', () {
    game.frame();
    final map = game.world.resource<LightMap>();
    expect(map.beamAt(15, 0), isTrue);
    expect(map.intensityAt(15, 0), 4);
    expect(map.beamAt(15, 3), isFalse);
  });
}
