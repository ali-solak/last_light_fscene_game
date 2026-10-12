import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/common/states.dart';
import 'package:last_light/features/boons/boons.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/harpoon/harpoon.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/lamps/lamps.dart';
import 'package:last_light/features/lantern/lantern.dart';
import 'package:last_light/features/light/light.dart';
import 'package:last_light/features/lighthouse/lighthouse.dart';
import 'package:last_light/features/mirrors/mirrors.dart';
import 'package:last_light/features/nights/nights.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

const double alongX = -math.pi / 2;
const double turnXtoZ = 3 * math.pi / 4;
const double turnZtoX = -math.pi / 4;

void main() {
  late TestGame game;

  /// A quiet night on flat ground with the beam off and [boon] taken.
  void stage(String boon, {bool beam = false}) {
    game = makeGame()
      ..quietNight()
      ..flatGround()
      ..pinBeam(yaw: alongX, on: beam);
    boonById(boon)!.apply(game.world);
    game.frame();
  }

  Health health(Entity e) => game.world.get<Health>(e);

  void dodge() {
    game.world.buffer<KeeperAction>().record(KeeperAction.jump);
    game.frame();
  }

  test('every boon in the table is reachable by id', () {
    expect(allBoons, hasLength(23));
    for (final boon in allBoons) {
      expect(boonById(boon.id), same(boon));
    }
  });

  test('Hot Wick: focus damage +50 %', () {
    stage('hot_wick');
    game.placeKeeper(0, 10);
    final crab = game.crab(CrabType.basher, 0, 14);
    game.aimAt(0, 14);
    game.world.buttons<KeeperAction>().press(KeeperAction.focus);
    // Long enough for him to turn round to the aim.
    game.seconds(0.6);
    expect(game.world.get<LightExposure>(crab).dps,
        closeTo(lightFocusDps * hotWickMultiplier, 1e-9));
  });

  test('Kindling: lit crabs keep burning after the light', () {
    stage('kindling');
    game.world.spawn([LampPost(), SceneTransform(10, 0, 20)]);
    final crab = game.crab(CrabType.basher, 10, 20);
    game.seconds(0.3);
    expect(game.world.has<Burning>(crab), isTrue);
    game.world.get<SceneTransform>(crab).setTranslation(30, 0, 30);
    game.seconds(0.3);
    final before = health(crab).current;
    game.seconds(1);
    expect(before - health(crab).current, closeTo(crabBurnDps, 0.3));
  });

  test('Firebomb: the thrown lamp makes a burning puddle and is relit sooner', () {
    stage('smash');
    game.aimAt(game.keeperAt.x - 4, game.keeperAt.z);
    game.world.buffer<KeeperAction>().record(KeeperAction.throwLamp);
    game.frame();
    // It flies its arc, then bursts.
    game.seconds(lanternThrowSeconds + 0.1);
    game.frame();
    expect(game.world.query<BurnPuddle>().count(), 1);
    final lantern = game.world.get<Lantern>(game.keeper);
    expect(lantern.lit, isFalse);
    game.seconds(lanternSmashAway);
    expect(lantern.lit, isTrue);
  });

  test('Flashpoint: a jump cowers crabs within 3 m', () {
    stage('flashpoint');
    final k = game.keeperAt;
    // Inside the flash, just out of a big glassback's claw reach.
    final crab = game.crab(CrabType.glassback, k.x + 2.9, k.z);
    dodge();
    game.frame();
    expect(game.world.has<Dazzled>(crab), isTrue);
    game.frame();
    expect(game.world.get<CrabBrain>(crab).mode.state, CrabMode.cowering);
  });

  test('Barbed: the harpoon pierces three crabs', () {
    final hits = <HarpoonHit>[];
    game = makeGame(probes: [collect(hits)])
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false);
    boonById('barbed')!.apply(game.world);
    game.frame();
    final k = game.keeperAt;
    final crabs = [
      for (var i = 0; i < 3; i++) game.crab(CrabType.basher, k.x - 4 - i * 2, k.z),
    ];
    game.aimAt(k.x - 12, k.z);
    game.world.buttons<KeeperAction>().press(KeeperAction.harpoon);
    game.seconds(0.1);
    game.world.buttons<KeeperAction>().release(KeeperAction.harpoon);
    game.seconds(0.5);
    game.frame();
    expect(hits.where((h) => h.kind == HarpoonTargetKind.crab).map((h) => h.target),
        crabs);
    for (final c in crabs) {
      expect(health(c).max - health(c).current,
          greaterThanOrEqualTo(harpoonDamage));
    }
  });

  test("Whaler's Reel: harpooning a rock reels the keeper to it", () {
    stage('whalers_reel');
    final k = game.keeperAt;
    game.world.insert(Occluders([Occluder(k.x - 10, k.z, 1)]));
    // Headless, the harpoon's world hits come from the occluder circles.
    game.aimAt(k.x - 10, k.z);
    game.world.buttons<KeeperAction>().press(KeeperAction.harpoon);
    game.seconds(0.1);
    game.world.buttons<KeeperAction>().release(KeeperAction.harpoon);
    game.seconds(0.4);
    final harpoon = game.world.get<Harpoon>(game.keeper);
    expect(harpoon.reelSelfTo, isNotNull);
    final startX = k.x;
    game.seconds(0.6);
    expect(game.keeperAt.x, lessThan(startX - 3));
  });

  test('Undertow: a jump knocks crabs back 2 m', () {
    stage('undertow');
    final k = game.keeperAt;
    final crab = game.crab(CrabType.glassback, k.x + 1.5, k.z);
    final startX = game.world.get<SceneTransform>(crab).x;
    dodge();
    // Flung, then dazed (before it gathers itself and comes back).
    game.seconds(0.8);
    final c = game.world.get<SceneTransform>(crab);
    expect(c.x - startX, greaterThan(1.8));
  });

  test('Riptide: the beam pushes crabs outward', () {
    stage('riptide', beam: true);
    final crab = game.crab(CrabType.glassback, 15, 0);
    final body = game.world.get<CrabBody>(crab);
    body.knockTime = 0;
    game.seconds(0.5);
    // A glassback walks the beam unharmed; outward is +X here.
    final with_ = game.world.get<SceneTransform>(crab).x;
    expect(with_, greaterThan(15 - 0.5 * 1.6 + 0.3));
  });

  test('Brine Light: lit crabs move 30 % slower', () {
    stage('brine_light');
    game.world.spawn([LampPost(), SceneTransform(20, 0, 25)]);
    final crab = game.crab(CrabType.glassback, 20, 23);
    game.seconds(1);
    final v = game.world.get<CrabBody>(crab).velocity.length;
    expect(v, closeTo(1.6 * 0.7, 0.15));
  });

  test('Salted Wicks: snuffed lamps relight after 6 s', () {
    stage('salted_wicks');
    final lamp = game.world.spawn(lampBundle(20, 0, 20));
    game.frame();
    game.emit(LampStruck(lamp));
    game.frame();
    expect(game.world.get<LampPost>(lamp).lit, isFalse);
    game.seconds(6.1);
    expect(game.world.get<LampPost>(lamp).lit, isTrue);
  });

  test('Preserves: dawn restores 25 Flame instead of 15', () {
    stage('preserves');
    final flame = game.world.resource<Flame>()..current = 50;
    game.world.setState(GameStatus.dawnBoons);
    game.frame();
    expect(flame.current, 75);
  });

  test('Salt Ring: crabs cannot climb for the first 10 s', () {
    stage('salt_ring');
    final crab = game.crab(CrabType.scuttler, 0, 3.8);
    game.seconds(2);
    expect(game.world.get<CrabBrain>(crab).mode.state, isNot(CrabMode.climbing));
    game.seconds(9);
    expect(game.world.get<CrabBrain>(crab).mode.state, CrabMode.climbing);
  });

  test('Spare Mirror: one more mirror', () {
    stage('spare_mirror');
    expect(game.world.resource<Run>().mirrorsOwned, 3);
  });

  test('Polished: a 4-bounce beam keeps intensity 4.0', () {
    stage('polished', beam: true);
    for (final (x, z, yaw) in const [
      (6.0, 0.0, turnXtoZ),
      (6.0, 5.0, turnZtoX),
      (11.0, 5.0, turnXtoZ),
      (11.0, 10.0, turnZtoX),
    ]) {
      game.world.spawn([Mirror(yaw), SceneTransform(x, 0, z)]);
    }
    game.frame();
    final path = game.world.resource<BeamPath>();
    expect(path.bounces, 4);
    expect(path.segments.last.intensity, 4.0);
  });

  test('Lens Grind: the beam is 40 % wider', () {
    stage('lens_grind', beam: true);
    expect(game.world.resource<Beam>().halfWidth, closeTo(1.2 * 1.4, 1e-9));
    game.frame();
    expect(game.world.resource<LightMap>().beamAt(15, 1.6), isTrue);
  });

  test('Prism: a placed mirror splits the beam in three', () {
    stage('prism', beam: true);
    game.world.spawn([
      Mirror(turnXtoZ),
      SceneTransform(10, 0, 0),
      const PrismMirror(),
    ]);
    game.frame();
    final path = game.world.resource<BeamPath>();
    expect(path.segments.where((s) => s.depth == 1), hasLength(3));
  });

  test('Sunfire: bounced beam segments do 50 % more damage', () {
    stage('sunfire', beam: true);
    game.world.spawn([Mirror(turnXtoZ), SceneTransform(10, 0, 0)]);
    final crab = game.crab(CrabType.basher, 10, 6);
    game.frame();
    expect(game.world.get<LightExposure>(crab).beamDps, closeTo(45, 1e-9));
  });

  test('Brine Wave: Undertow also slows crabs for 2 s', () {
    stage('undertow');
    boonById('brine_wave')!.apply(game.world);
    game.frame();
    final k = game.keeperAt;
    final crab = game.crab(CrabType.glassback, k.x + 1.5, k.z);
    dodge();
    game.frame();
    expect(game.world.has<Slowed>(crab), isTrue);
    game.seconds(3);
    expect(game.world.has<Slowed>(crab), isFalse);
  });

  test('the offer is three distinct boons; duos need both families', () {
    final g = makeGame()..toDawnBuild();
    g.world.setState(GameStatus.dawnBoons);
    g.frame();
    final offer = g.world.resource<BoonOffer>().boons;
    expect(offer, hasLength(3));
    expect(offer.map((b) => b.id).toSet(), hasLength(3));
    expect(offer.where((b) => b.family == BoonFamily.duo), isEmpty);
  });

  test('Flare: letting a held focus go burns and dazzles the cone', () {
    stage('flare');
    game.placeKeeper(0, 10);
    final crab = game.crab(CrabType.basher, 0, 15);
    game.aimAt(0, 15);
    final health = game.world.get<Health>(crab);
    game.world.buttons<KeeperAction>().press(KeeperAction.focus);
    game.seconds(0.9);
    final before = health.current;
    game.world.buttons<KeeperAction>().release(KeeperAction.focus);
    game.seconds(0.1);
    expect(before - health.current, greaterThan(crabFlareDamage * 0.9));
    expect(game.world.has<Dazzled>(crab), isTrue);
  });

  test('Triple Bolt: two darts fan out beside the bolt', () {
    final hits = <HarpoonHit>[];
    game = makeGame(probes: [collect(hits)])
      ..quietNight()
      ..flatGround()
      ..pinBeam(on: false);
    boonById('triple_bolt')!.apply(game.world);
    game.frame();
    final k = game.keeperAt;
    // Off to either side of the aim line, where only a dart reaches.
    final left = game.crab(CrabType.basher, k.x - 10, k.z + 2);
    final right = game.crab(CrabType.basher, k.x - 10, k.z - 2);
    // Aimed between and past them, clear of aim assist.
    game.aimAt(k.x - 14, k.z);
    game.world.buttons<KeeperAction>().press(KeeperAction.harpoon);
    game.seconds(0.1);
    game.world.buttons<KeeperAction>().release(KeeperAction.harpoon);
    game.seconds(0.6);
    final struck = hits.map((h) => h.target).toSet();
    expect(struck, containsAll([left, right]));
  });

  test('Whiplash: the reeled chain lashes crabs it sweeps through', () {
    stage('whiplash');
    final k = game.keeperAt;
    final hooked = game.crab(CrabType.basher, k.x - 8, k.z);
    // Standing beside the line the chain is reeled along.
    final bystander = game.crab(CrabType.glassback, k.x - 4, k.z + 2.0);
    final health = game.world.get<Health>(bystander);
    game.aimAt(k.x - 8, k.z);
    game.world.buttons<KeeperAction>().press(KeeperAction.harpoon);
    game.seconds(0.1);
    game.world.buttons<KeeperAction>().release(KeeperAction.harpoon);
    game.seconds(0.8);
    expect(health.current, lessThan(health.max - harpoonLashDamage + 1e-6));
    expect(game.world.get<Health>(hooked).current, lessThan(
        game.world.get<Health>(hooked).max));
  });
}
