import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/lamps/lamps.dart';
import 'package:last_light/features/lantern/lantern.dart';
import 'package:last_light/features/light/light.dart';
import 'package:last_light/features/lighthouse/lighthouse.dart';
import 'package:last_light/features/mirrors/mirrors.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;
  final snuffed = <LampSnuffed>[];
  final toppled = <MirrorToppled>[];
  final cracked = <ShellCracked>[];

  setUp(() {
    snuffed.clear();
    toppled.clear();
    cracked.clear();
    game = makeGame(
      probes: [collect(snuffed), collect(toppled), collect(cracked)],
    )
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false);
    // Keep the keeper (and his lantern) well away from the stage.
    game.placeKeeper(-40, -40);
  });

  Entity lamp(double x, double z) =>
      game.world.spawn([LampPost(), SceneTransform(x, 0, z)]);

  CrabBrain brain(Entity e) => game.world.get<CrabBrain>(e);
  SceneTransform at(Entity e) => game.world.get<SceneTransform>(e);

  test('crabs path around a lit lane', () {
    // A band of lamp light between the beach and the lighthouse.
    for (var x = -9.0; x <= 9; x += 3) {
      lamp(x, 12);
    }
    game.frame();
    final crab = game.crab(CrabType.scuttler, 0, 26);
    final map = game.world.resource<LightMap>();
    var brightest = 0.0;
    for (var i = 0; i < 60 * 25 && brain(crab).mode.state == CrabMode.advancing; i++) {
      game.frame();
      final t = at(crab);
      if (map.intensityAt(t.x, t.z) > brightest) {
        brightest = map.intensityAt(t.x, t.z);
      }
    }
    expect(brightest, lessThan(crabCowerThreshold));
    expect(brain(crab).mode.state, CrabMode.climbing);
  });

  test('the beam makes a crab cower, and cowering stops movement', () {
    game.pinBeam(yaw: -1.5707963267948966);
    final crab = game.crab(CrabType.basher, 15, 0);
    game.seconds(0.3);
    expect(brain(crab).mode.state, CrabMode.cowering);
    final before = at(crab).translation.clone();
    game.seconds(1);
    expect(at(crab).translation.distanceTo(before), lessThan(1e-6));
  });

  test("the lantern's focus cowers and burns a crab like the beam", () {
    final crab = game.crab(CrabType.basher, 0, 20);
    game.placeKeeper(0, 14);
    game.aimAt(0, 20);
    game.world.buttons<KeeperAction>().press(KeeperAction.focus);
    game.seconds(1.5);
    expect(brain(crab).mode.state, CrabMode.cowering);
    final health = game.world.get<Health>(crab);
    expect(health.current, lessThan(health.max - 10));
  });

  test('lamp light never hurts a crab or stops it, only slows it', () {
    lamp(10, 20);
    final crab = game.crab(CrabType.basher, 10, 20);
    game.seconds(1);
    final health = game.world.get<Health>(crab);
    expect(health.current, health.max);
    expect(brain(crab).mode.state, isNot(CrabMode.cowering));
    expect(
      game.world.get<CrabBody>(crab).velocity.length,
      lessThanOrEqualTo(crabStats[CrabType.basher]!.speed * crabLightSlow * 1.1 + 1e-6),
    );
  });

  test('a tarback in the beam takes 0 damage until the lantern cracks it',
      () {
    game.pinBeam(yaw: -1.5707963267948966);
    final crab = game.crab(CrabType.tarback, 15, 0);
    game.placeKeeper(15, -6);
    game.aimAt(15, 0);
    game.world.buttons<KeeperAction>().press(KeeperAction.focus);
    game.seconds(1.3);
    final health = game.world.get<Health>(crab);
    expect(health.current, health.max);
    expect(cracked, isEmpty);
    // He turns to it first, so the shell takes the full 1.5 s from then.
    game.seconds(0.6);
    game.frame();
    expect(cracked.single.entity, crab);
    game.seconds(1);
    expect(health.current, lessThan(health.max - 10));
  });

  test('the lamp burns a shroud through and the harpoon bites the exposed',
      () {
    final exposed = <CrabExposed>[];
    game = makeGame(probes: [collect(exposed)])
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false)
      ..placeKeeper(0, 14);
    final crab = game.crab(CrabType.glassback, 0, 20, shrouded: true);
    final health = game.world.get<Health>(crab);
    double bite(double amount) {
      final before = health.current;
      game.emit(CrabDamaged(crab, amount, DamageSource.harpoon));
      game.frame();
      return before - health.current;
    }

    // Shrouded, the harpoon glances.
    expect(bite(10), closeTo(10 * harpoonShroudedFactor, 0.6));
    game.aimAt(0, 20);
    game.world.buttons<KeeperAction>().press(KeeperAction.focus);
    for (var i = 0; i < 60 * 3 && exposed.isEmpty; i++) {
      game.frame();
    }
    expect(exposed.single.entity, crab);
    expect(game.world.has<Exposed>(crab), isTrue);
    expect(game.world.has<Dazzled>(crab), isTrue);
    // Exposed, it bites deep.
    expect(bite(10), closeTo(10 * harpoonExposedFactor, 0.6));
    // And the window closes.
    game.seconds(crabExposedSeconds + 0.2);
    expect(game.world.has<Exposed>(crab), isFalse);
  });

  test('a snuffer snuffs a lamp at the Spit event', () {
    final target = lamp(10, 20);
    final crab = game.crab(CrabType.snuffer, 10, 23);
    final eventAt = headlessModels.clip('snuffer', 'Spit')!.eventAt!;
    var spitting = 0.0;
    for (var i = 0; i < 120 && snuffed.isEmpty; i++) {
      game.frame();
      if (brain(crab).special == 'Spit') spitting = brain(crab).mode.elapsed;
      if (snuffed.isEmpty && brain(crab).special == 'Spit') {
        expect(game.world.get<LampPost>(target).lit,
            spitting < eventAt ? isTrue : isFalse);
      }
    }
    expect(snuffed.single.lamp, target);
    expect(spitting, closeTo(eventAt, 0.05));
  });

  test('a basher topples a mirror', () {
    final mirror = game.world.spawn([Mirror(0), SceneTransform(10, 0, 20)]);
    game.crab(CrabType.basher, 10, 21.2);
    game.seconds(2.5);
    game.frame();
    expect(toppled.single.mirror, mirror);
    expect(game.world.get<Mirror>(mirror).upright, isFalse);
  });

  test('burrowers are immune underground', () {
    final crab = game.crab(CrabType.burrower, 10, 20);
    game.world.add(crab, const Underground());
    game.frame();
    game.emit(CrabDamaged(crab, 50, DamageSource.harpoon));
    game.frame();
    final health = game.world.get<Health>(crab);
    expect(health.current, health.max);
    game.world.remove<Underground>(crab);
    game.frame();
    game.emit(CrabDamaged(crab, 10, DamageSource.harpoon));
    game.frame();
    expect(health.current, health.max - 10);
  });

  test('climbing crabs drain the Flame', () {
    final flame = game.world.resource<Flame>();
    final crab = game.crab(CrabType.scuttler, 0, 3.8);
    game.seconds(0.2);
    expect(brain(crab).mode.state, CrabMode.climbing);
    final before = flame.current;
    game.seconds(2);
    expect(before - flame.current, closeTo(2 * flameDrainScuttler, 0.1));
  });

  test('a killed crab emits CrabKilled once and despawns after its corpse', () {
    final killed = <CrabKilled>[];
    final g = makeGame(probes: [collect(killed)])
      ..quietNight()
      ..flatGround()
      ..placeKeeper(-40, -40);
    final crab = g.crab(CrabType.scuttler, 10, 20);
    g.emit(CrabDamaged(crab, 100, DamageSource.harpoon));
    g.seconds(0.5);
    g.frame();
    expect(killed, hasLength(1));
    expect(g.world.has<Dead>(crab), isTrue);
    g.seconds(6);
    expect(g.world.isAlive(crab), isFalse);
  });

  test('the beam does its damage per second', () {
    game.pinBeam(yaw: -1.5707963267948966);
    final crab = game.crab(CrabType.basher, 15, 0);
    game.seconds(1);
    final health = game.world.get<Health>(crab);
    expect(health.max - health.current, closeTo(lightBeamDps, 2));
  });

  test('the flow field leads to the lighthouse', () {
    game.seconds(0.3);
    final flow = game.world.resource<FlowField>();
    final d = flow.dist[1000];
    expect(d.isFinite, isTrue);
    expect(game.world.resource<HeightGrid>().walkable[1000], 1);
  });

  test('the horde marches up the sand trails', () {
    final g = makeGame()..quietNight();
    final grid = g.world.resource<HeightGrid>();
    expect(grid.road.where((r) => r == 1).length, greaterThan(80));
    final field = g.world.resource<FlowField>();
    // Follow the flow from the north and east landings (the south beach
    // has no trail) to the lighthouse.
    for (final spawn in g.world.resource<SpawnPoints>().points.take(4)) {
      var i = gridIndexAt(spawn.x, spawn.z);
      var steps = 0, onRoad = 0;
      while (i >= 0 && field.next[i] >= 0 && steps < 400) {
        i = field.next[i];
        steps++;
        if (grid.road[i] == 1) onRoad++;
      }
      expect(onRoad / steps, greaterThan(0.5), reason: 'from $spawn');
    }
  });

  test('crabs from every beach reach the tower without sticking', () {
    final g = makeGame()..quietNight();
    // The keeper well out of the way, the beam off; snuffers, which do not
    // hunt him from afar the way scuttlers do.
    g.world.get<SceneTransform>(g.keeper).setTranslation(-6, 2, 14.5);
    g.world.resource<Beam>().on = false;
    g.world.get<Lantern>(g.keeper).away = 1e6;
    final crabs = <Entity>[];
    for (final p in g.world.resource<SpawnPoints>().points) {
      for (var k = 0; k < 2; k++) {
        crabs.add(g.crab(CrabType.snuffer, p.x + k * 1.5, p.z + k));
      }
    }
    // Climbers go up out of reach, so note each one as it gets there.
    final reached = <Entity>{};
    final flame = g.world.resource<Flame>();
    for (var i = 0; i < 60 * 120; i++) { // snuffers walk slower than scuttlers
      // Climbers drain the Flame; keep the night going.
      flame.current = flame.max;
      g.pumpFixed(steps: 1);
      for (final c in crabs) {
        if (g.world.tryGet<CrabBrain>(c)?.mode.state == CrabMode.climbing) {
          reached.add(c);
        }
      }
    }
    final arrived = reached.length;
    final stuck = [
      for (final c in crabs.where((c) => !reached.contains(c)))
        if (g.world.tryGet<SceneTransform>(c) case final t?)
          '(${t.x.toStringAsFixed(1)}, ${t.z.toStringAsFixed(1)})',
    ];
    expect(arrived, greaterThanOrEqualTo(crabs.length - 1),
        reason: 'stuck at ${stuck.join(', ')}');
  });
}
