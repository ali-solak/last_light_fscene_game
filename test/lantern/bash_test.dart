import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/keeper/keeper.dart';
import 'package:last_light/features/lantern/lantern.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;
  final struck = <CrabBashed>[];
  final exposed = <CrabExposed>[];

  setUp(() {
    struck.clear();
    exposed.clear();
    game = makeGame(probes: [collect(struck), collect(exposed)])
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false)
      ..placeKeeper(0, 10);
  });

  Lantern lantern() => game.world.get<Lantern>(game.keeper);

  /// Faces the keeper at (x, z) and swings.
  void bashToward(double x, double z) {
    final k = game.keeperAt;
    game.world.get<KeeperBody>(game.keeper).facing = yawToward(x - k.x, z - k.z);
    game.world.buffer<KeeperAction>().record(KeeperAction.bash);
    game
      ..frame()
      ..frame();
  }

  test('the lamp strikes the crab in front: hurt, knocked back, alight, '
      'and its sparks rekindle the dry lamp', () {
    final crab = game.crab(CrabType.basher, 0, 11.6);
    final health = game.world.get<Health>(crab);
    lantern().oil = 0;
    bashToward(0, 11.6);
    expect(struck.single.crab, crab);
    expect(health.current, closeTo(health.max - crabBashDamage, 0.5));
    expect(game.world.get<CrabBody>(crab).knockTime, greaterThan(0));
    expect(game.world.has<Burning>(crab), isTrue);
    expect(lantern().oil, closeTo(lanternBashKindle, 1e-6));
  });

  test('nothing behind him is struck, and the swing waits for its cooldown',
      () {
    // Both held cowering, so neither walks in or bites.
    final behind = game.crab(CrabType.basher, 0, 8.6);
    final front = game.crab(CrabType.basher, 0, 11.6);
    for (final crab in [behind, front]) {
      game.world.add(crab, const Dazzled());
    }
    bashToward(0, 20);
    expect(struck.map((s) => s.crab), [front]);
    game.world.despawn(behind);
    bashToward(0, 11.6);
    expect(struck.length, 1, reason: 'still cooling down');
    // The early press stays buffered and swings (at air) the moment the
    // cooldown ends; wait that one out too.
    game.seconds(lanternBashCooldown * 2.2);
    // The first strike knocked it away; bring it back within reach.
    game.world.get<SceneTransform>(front).setTranslation(0, 0, 11.6);
    bashToward(0, 11.6);
    expect(struck.length, greaterThan(1));
  });

  test('an exposed crab takes the hard hit', () {
    final crab = game.crab(CrabType.basher, 0, 11.6);
    game.world.add(crab, const Exposed());
    final health = game.world.get<Health>(crab);
    bashToward(0, 11.6);
    expect(struck.single.exposed, isTrue);
    expect(health.current,
        closeTo(health.max - crabBashDamage * crabBashExposedFactor, 0.5));
  });

  test('one strike knocks a scuttler shroud away; a basher takes more', () {
    final scuttler = game.crab(CrabType.scuttler, -0.5, 11.4, shrouded: true);
    final basher = game.crab(CrabType.basher, 0.6, 11.6, shrouded: true);
    bashToward(0, 11.5);
    expect(exposed.map((e) => e.entity), [scuttler]);
    expect(game.world.has<Exposed>(basher), isFalse);
    expect(game.world.get<Shroud>(basher).value,
        closeTo(crabShroudSeconds[CrabType.basher]! - crabBashShroud, 0.02));
  });
}
