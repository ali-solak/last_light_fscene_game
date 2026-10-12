import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/features/island/island.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;
  setUp(() => game = makeGame());

  HeightGrid grid() => game.world.resource<HeightGrid>();

  test('the HeightGrid at the lighthouse anchor is about 6 m', () {
    final at = game.world.resource<IslandAnchors>().lighthouse;
    expect(at.y, closeTo(6, 0.01));
    expect(grid().sample(at.x, at.z), closeTo(6, 0.3));
  });

  test('the beaches are walkable and the cliffs are not', () {
    // Each beach, just inland of its spawn points.
    for (final beach in Beach.values) {
      final spawns = game.world.resource<SpawnPoints>().of(beach);
      final p = spawns.first;
      final toCentre = Vector3(-p.x, 0, -p.z)..normalize();
      final inland = p + toCentre * 8;
      expect(
        grid().walkableXZ(inland.x, inland.z),
        isTrue,
        reason: '$beach beach at (${inland.x}, ${inland.z})',
      );
      expect(grid().sample(inland.x, inland.z), lessThan(2));
    }
    // The west cliffs: a steep wall between the terrace and the sea.
    var cliffs = 0;
    for (var z = -20.0; z <= 10; z += 1) {
      if (!grid().walkableXZ(-29.5, z)) cliffs++;
    }
    expect(cliffs, greaterThan(12));
  });

  test('there are 8 pedestals and 6 spawns', () {
    expect(game.world.query<BrazierStand>().count(), 8);
    expect(game.world.resource<SpawnPoints>().points, hasLength(6));
  });

  test('the tide-pool path opens only at low tide', () {
    var tidal = 0;
    for (var i = 0; i < grid().tidal.length; i++) {
      if (grid().tidal[i] == 1) {
        tidal++;
        expect(grid().walkableAt(i), isFalse);
        expect(grid().walkableAt(i, lowTide: true), isTrue);
      }
    }
    expect(tidal, greaterThan(50));
  });

  test('the aim ray lands on the ground', () {
    final aim = game.world.resource<AimInput>()
      ..setRay(Vector3(0, 40, -20), Vector3(0, -40, 20));
    game.frame();
    expect(aim.valid, isTrue);
    expect(aim.point.y, closeTo(grid().sample(aim.point.x, aim.point.z), 0.3));
  });
}
