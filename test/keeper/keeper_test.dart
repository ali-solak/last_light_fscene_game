import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/inputs.dart';
import 'dart:math' as math;

import 'package:last_light/common/grid.dart';
import 'package:last_light/common/states.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/keeper/keeper.dart';
import 'package:last_light/features/nights/nights.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;
  final hits = <KeeperHit>[];
  final downs = <KeeperDowned>[];
  final respawns = <KeeperRespawned>[];
  final dodges = <JumpStarted>[];
  final landings = <KeeperLanded>[];

  setUp(() {
    hits.clear();
    downs.clear();
    respawns.clear();
    dodges.clear();
    landings.clear();
    game = makeGame(
      probes: [
        collect(hits),
        collect(downs),
        collect(respawns),
        collect(dodges),
        collect(landings),
      ],
    )..quietNight();
  });

  Hearts hearts() => game.world.get<Hearts>(game.keeper);
  KeeperBrain brain() => game.world.get<KeeperBrain>(game.keeper);

  void attack() {
    game.emit(CrabAttackLanded(game.keeper, 1));
    game.frame();
  }

  void jump() {
    game.world.buffer<KeeperAction>().record(KeeperAction.jump);
    game.frame();
  }

  test('moving costs no hearts', () {
    final start = game.keeperAt.translation.clone();
    game.world.axes<KeeperAxis>().setValue(KeeperAxis.moveX, -1);
    game.seconds(1);
    expect(game.keeperAt.translation.distanceTo(start), greaterThan(2));
    expect(hearts().current, 5);
    expect(hits, isEmpty);
  });

  test('an attack costs a heart, then 1 s of i-frames', () {
    attack();
    expect(hearts().current, 4);
    attack();
    expect(hearts().current, 4);
    game.seconds(1.1);
    attack();
    expect(hearts().current, 3);
    expect(hits, hasLength(2));
  });

  test('a jump leaves the ground, carries forward and lands', () {
    final start = game.keeperAt.translation.clone();
    final ground = start.y;
    jump();
    game.seconds(0.25);
    expect(game.keeperAt.y, greaterThan(ground + 0.6));
    expect(brain().mode.state, KeeperMode.jumping);
    game.seconds(0.6);
    game.frame();
    expect(brain().mode.state, isNot(KeeperMode.jumping));
    expect(landings, hasLength(1));
    expect(landings.single.height, greaterThan(0.9));
    final moved = game.keeperAt.translation - start;
    expect(moved.x * moved.x + moved.z * moved.z, greaterThan(1));
  });

  test('jump i-frames block an attack', () {
    jump();
    game.seconds(0.1);
    expect(brain().iFramed, isTrue);
    attack();
    expect(hearts().current, 5);
    expect(hits, isEmpty);
  });

  test('downed → respawn at the spawn after 4 s with full hearts', () {
    hearts().current = 1;
    attack();
    expect(brain().mode.state, KeeperMode.downed);
    expect(downs, hasLength(1));
    game.seconds(3.8);
    expect(brain().mode.state, KeeperMode.downed);
    game.seconds(0.3);
    game.frame();
    expect(brain().mode.state, isNot(KeeperMode.downed));
    expect(hearts().current, 5);
    expect(respawns, hasLength(1));
  });

  test('slow motion triggers only on a close call', () {
    jump();
    game.frame();
    expect(game.clock.timeScale, 1);
    expect(dodges.single.closeCall, isFalse);

    game.seconds(1.2);
    final k = game.keeperAt;
    game.crab(CrabType.scuttler, k.x + 1, k.z);
    jump();
    expect(game.clock.timeScale, closeTo(0.35, 1e-9));
    expect(dodges.last.closeCall, isTrue);
    // Wall-time hold, then eased back.
    for (var i = 0; i < 60; i++) {
      game.frame();
    }
    expect(game.clock.timeScale, closeTo(1, 1e-6));
  });

  test('at dusk he takes his post on open ground toward the first landing, '
      'looking at it', () {
    final fresh = makeGame()..toDawnBuild();
    fresh
      ..emit(const BellRung())
      ..frame()
      ..frame();
    expect(fresh.status, GameStatus.dusk);
    final t = fresh.keeperAt;
    final grid = fresh.world.resource<HeightGrid>();
    expect(grid.walkable[gridIndexAt(t.x, t.z)], 1);
    final tower = fresh.world.resource<IslandAnchors>().lighthouse;
    final landing = fresh.world.resource<SpawnPoints>().of(nightFirstBeach(1));
    final beach = landing.reduce((a, b) => a + b) / landing.length.toDouble();
    double dist(double x, double z) =>
        math.sqrt(distSq2(x, z, beach.x, beach.z));
    expect(dist(t.x, t.z), lessThan(dist(tower.x, tower.z)));
    final facing = fresh.world.get<KeeperBody>(fresh.keeper).facing;
    expect(
      angleDelta(facing, yawToward(beach.x - t.x, beach.z - t.z)).abs(),
      lessThan(1e-6),
    );
  });
}
