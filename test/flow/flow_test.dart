import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/states.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/keeper/keeper.dart';
import 'package:last_light/features/nights/nights.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

void main() {
  test('title → dawn → build → dusk → night, and crabs land', () {
    final game = makeGame();
    expect(game.status, GameStatus.title);
    expect(game.world.entitiesWith<Keeper>().count(), 1);

    game.toDawnBuild();
    expect(game.status, GameStatus.dawnBuild);
    expect(game.world.resource<Run>().boons, hasLength(1));

    game.toNight();
    expect(game.status, GameStatus.night);
    game.seconds(6);
    expect(game.world.query<Crab>().count(), greaterThan(4));
  });
}
