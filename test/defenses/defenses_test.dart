import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/defenses/defenses.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;
  setUp(() {
    game = makeGame()
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false);
    game.placeKeeper(-40, -40);
    game.frame();
  });

  bool walled(double x, double z) =>
      game.world.resource<FlowObstacles>().wall[gridIndexAt(x, z)] == 1;

  test('a barricade walls off its cells; crabs chew it down', () {
    // Across the way to the tower (running along X), 8 m out.
    final wall = game.world.spawn([
      Barricade(math.pi / 2),
      SceneTransform(0, 0, 8),
    ]);
    game.seconds(0.1);
    expect(walled(0, 8), isTrue);
    expect(walled(1.2, 8), isTrue);
    expect(walled(0, 10), isFalse);
    // A crab walks round a lone barricade, never through it.
    final round = game.crab(CrabType.scuttler, 0, 11);
    for (var i = 0; i < 60 * 4; i++) {
      game.pumpFixed(steps: 1);
      final t = game.world.get<SceneTransform>(round);
      expect(walled(t.x, t.z), isFalse);
    }
    game.world.despawn(round);

    // Boxed in, a basher has no way round: it chews through.
    for (final (x, z, yaw) in const [
      (0.0, 12.6, math.pi / 2),
      (-2.0, 10.6, 0.0),
      (2.0, 10.6, 0.0),
    ]) {
      game.world.spawn([Barricade(yaw), SceneTransform(x, 0, z)]);
    }
    game.crab(CrabType.basher, 0, 10.6);
    final barricade = game.world.get<Barricade>(wall);
    final hp = barricade.hp;
    game.seconds(4);
    expect(game.world.tryGet<Barricade>(wall)?.hp ?? 0, lessThan(hp));
  });

  test('salt costs the crossing crab and wears away under it', () {
    final salt = game.world.spawn([
      SaltLine(math.pi / 2),
      SceneTransform(0, 0, 8),
    ]);
    game.seconds(0.1);
    expect(
      game.world.resource<FlowObstacles>().cost[gridIndexAt(0, 8)],
      greaterThan(0),
    );
    final crab = game.crab(CrabType.scuttler, 0, 8);
    final health = game.world.get<Health>(crab);
    final strength = game.world.get<SaltLine>(salt).strength;
    game.seconds(1);
    expect(health.current, lessThan(health.max));
    expect(game.world.tryGet<SaltLine>(salt)?.strength ?? 0, lessThan(strength));
  });
}
