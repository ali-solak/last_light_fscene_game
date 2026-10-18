import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/features/gulls/gulls.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;

  List<(Entity, Gull, SceneTransform)> gulls() =>
      game.world.query2<Gull, SceneTransform>().snapshot();

  setUp(() {
    game = makeGame()..toDawnBuild();
  });

  test('at dawn a flock comes in off the sea and lands', () {
    expect(gulls(), hasLength(gullCount));
    game.seconds(12);
    for (final (_, gull, _) in gulls()) {
      expect(gull.mode.state, GullMode.landed);
    }
  });

  test('walking up scatters them; they settle again somewhere quieter', () {
    game.seconds(12);
    final (_, gull, t) = gulls().first;
    game.placeKeeper(t.x + 1, t.z);
    game.seconds(0.2);
    expect(gull.mode.state, GullMode.fleeing);
    game.seconds(gullFleeSeconds + 12);
    expect(gull.mode.state, GullMode.landed);
    final k = game.keeperAt;
    expect(distSq2(t.x, t.z, k.x, k.z), greaterThan(gullSpook * gullSpook));
  });

  test('they are gone by nightfall', () {
    game.toNight();
    expect(gulls(), isEmpty);
  });
}
