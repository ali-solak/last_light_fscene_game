import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/features/lantern/lantern.dart';
import 'package:last_light/features/motes/motes.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;
  late Lantern lantern;

  setUp(() {
    game = makeGame()
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false)
      ..placeKeeper(0, 0);
    lantern = game.world.get<Lantern>(game.keeper);
  });

  void kill(double x, double z) {
    final crab = game.crab(CrabType.scuttler, x, z);
    game.emit(CrabKilled(crab, CrabType.scuttler, Vector3(x, 0, z), Vector3.zero()));
    game.frame();
  }

  test('a kill near the keeper streams its motes into the lamp', () {
    lantern.oil = 50;
    kill(2.5, 0);
    expect(game.world.query<Mote>().count(), moteCount);
    game.seconds(2.5);
    expect(game.world.query<Mote>().count(), 0);
    expect(lantern.oil, closeTo(50 + moteCount * moteOil, 1e-9));
  });

  test('a full lamp takes none: the motes hang there and fade', () {
    lantern.oil = lanternOilMax;
    kill(2.5, 0);
    game.seconds(2.5);
    expect(game.world.query<Mote>().count(), moteCount);
    game.seconds(moteSeconds);
    expect(game.world.query<Mote>().count(), 0);
  });

  test('motes out of reach wait for him', () {
    lantern.oil = 50;
    kill(15, 0);
    game.seconds(3);
    expect(lantern.oil, 50);
    game.placeKeeper(14, 0);
    game.seconds(2.5);
    expect(lantern.oil, greaterThan(50));
  });
}
