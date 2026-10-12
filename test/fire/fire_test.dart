import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/common/wind.dart';
import 'package:last_light/features/fire/fire.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/light/light.dart';
import 'package:last_light/features/weather/weather.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../support/harness.dart';

/// A steady wind toward +X (the weather turns the wind each step, so the
/// weather is what is set).
void windToward(TestGame game, {required bool storm}) {
  game.world.resource<Weather>()
    ..heading = -math.pi / 2
    ..headingGoal = -math.pi / 2
    ..stormGoal = storm ? 1 : 0;
  game.world.resource<Wind>().storm = storm ? 1 : 0;
}

void main() {
  late TestGame game;
  setUp(() {
    game = makeGame()
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false);
    game.placeKeeper(-40, -40);
    windToward(game, storm: false);
  });

  FireField fire() => game.world.resource<FireField>();

  /// How far the burnt-or-burning ground reaches from x = 0 along X.
  (double, double) reach() {
    var minX = 0.0, maxX = 0.0;
    for (var i = 0; i < gridCellCount; i++) {
      if (fire().burn[i] <= 0 && fire().scorched[i] == 0) continue;
      final x = gridCenterX(i % gridCells);
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
    }
    return (minX, maxX);
  }

  test('a moth blast lights the grass and it creeps faster downwind', () {
    game.emit(MothExploded(Vector3(0, 0, 0)));
    game.frame();
    expect(fire().count, greaterThan(5));
    game.seconds(10);
    final (minX, maxX) = reach();
    expect(maxX, greaterThan(-minX + 1.5));
  });

  test('burning grass is light that scorches, then burns out', () {
    game.emit(MothExploded(Vector3(0, 0, 0)));
    game.frame();
    game.frame();
    final map = game.world.resource<LightMap>();
    expect(map.flagsAt(0, 0) & LightFlags.burn, isNot(0));
    game.seconds(fireBurnMax + 1);
    expect(fire().burningAt(0, 0), isFalse);
    expect(fire().scorched[gridIndexAt(0, 0)], 1);
  });

  test('no fuel, no fire: sand and scorched ground never catch', () {
    final grid = game.world.resource<HeightGrid>();
    grid.grass.fillRange(0, gridCellCount, 0);
    game.emit(MothExploded(Vector3(0, 0, 0)));
    game.frame();
    expect(fire().count, 0);
  });

  test('a storm damps the spread', () {
    windToward(game, storm: true);
    game.emit(MothExploded(Vector3(0, 0, 0)));
    game.frame();
    game.seconds(10);
    final (_, stormy) = reach();
    final calm = makeGame()
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false);
    calm.placeKeeper(-40, -40);
    windToward(calm, storm: false);
    calm.emit(MothExploded(Vector3(0, 0, 0)));
    calm.frame();
    calm.seconds(10);
    var calmMax = 0.0;
    final f = calm.world.resource<FireField>();
    for (var i = 0; i < gridCellCount; i++) {
      if (f.burn[i] > 0 || f.scorched[i] == 1) {
        calmMax = calmMax > gridCenterX(i % gridCells)
            ? calmMax
            : gridCenterX(i % gridCells);
      }
    }
    expect(stormy, lessThan(calmMax));
  });
}
