import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/fire/fire.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/keeper/keeper.dart';
import 'package:last_light/features/lantern/lantern.dart';
import 'package:last_light/features/wreckage/wreckage.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../support/harness.dart';

void main() {
  test('each night washes up wreckage on low ground, new every night', () {
    final game = makeGame()..quietNight();
    final grid = game.world.resource<HeightGrid>();
    final wrecks = game.world.query2<Wreck, SceneTransform>().snapshot();
    expect(wrecks.length, greaterThanOrEqualTo(wreckBase));
    for (final (_, _, t) in wrecks) {
      expect(grid.walkableXZ(t.x, t.z), isTrue);
      expect(t.y, inInclusiveRange(wreckMinHeight - 0.3, wreckMaxHeight + 0.3));
    }
  });

  group('on flat ground', () {
    late TestGame game;
    final broken = <WreckBroken>[];
    setUp(() {
      broken.clear();
      game = makeGame(probes: [collect(broken)])
        ..quietNight()
        ..flatGround()
        ..pinBeam(on: false);
      game.world.query<Wreck>().each((e, _) => game.world.despawn(e));
      game.placeKeeper(-40, -40);
      game.frame();
    });

    Entity wreck(WreckKind kind, double x, double z) {
      final e = game.world.spawn([Wreck(kind), SceneTransform(x, 0, z)]);
      game.frame();
      return e;
    }

    test('a harpoon hit smashes a crate', () {
      wreck(WreckKind.crate, 10, 10);
      game.emit(HarpoonHit(.prop, null, Vector3(10.5, 0.5, 10)));
      game.frame();
      game.frame();
      expect(game.world.query<Wreck>().count(), 0);
      expect(broken.single.barrel, isFalse);
    });

    test('a barrel blast burns and flings crabs, lights the grass, and sets '
        'off the next barrel', () {
      wreck(WreckKind.barrel, 10, 10);
      wreck(WreckKind.barrel, 12.5, 10);
      final crab = game.crab(CrabType.basher, 10, 12);
      final hp = game.world.get<Health>(crab);
      game.emit(HarpoonHit(.prop, null, Vector3(10, 0.5, 10)));
      game.seconds(0.6);
      expect(broken.where((b) => b.barrel), hasLength(2));
      expect(hp.current, lessThan(hp.max - barrelBlastDamage * 0.5));
      expect(game.world.resource<FireField>().count, greaterThan(0));
    });

    test('landing on a crate stamps it in; walking over spilled oil fills '
        'the lamp', () {
      wreck(WreckKind.crate, -40, -40);
      final lantern = game.world.get<Lantern>(game.keeper)..oil = 10;
      game.emit(KeeperLanded(Vector3(-40, 0, -40), 1));
      game.frame();
      game.frame();
      expect(game.world.query<Wreck>().count(), 0);
      // The crate spilled something (or nothing); drop oil by hand to
      // check the pickup itself.
      game.world.spawn([Pickup(PickupKind.oil), SceneTransform(-40, 0, -40)]);
      game.seconds(0.2);
      expect(lantern.oil, greaterThan(10));
    });

    test('a barrel too close to the keeper hurts him', () {
      wreck(WreckKind.barrel, -39, -40);
      final hearts = game.world.get<Hearts>(game.keeper);
      final before = hearts.current;
      game.emit(MothExploded(Vector3(-39, 0, -40)));
      game.seconds(0.3);
      expect(hearts.current, before - 1);
    });
  });
}
