import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/common/states.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/feedback/feedback.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/lighthouse/lighthouse.dart';
import 'package:last_light/features/nights/nights.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../support/harness.dart';

void main() {
  group('nights', () {
    test('night 1 lands three waves of 6–8 scuttlers on the north beach', () {
      final waves = <WaveLanded>[];
      final started = <NightStarted>[];
      final game = makeGame(probes: [collect(waves), collect(started)])
        ..toDawnBuild()
        ..toNight();
      game.placeKeeper(-40, -40);
      for (var i = 0; i < 60 * 50 && waves.length < 3; i++) {
        game.frame();
      }
      expect(started.single.night, 1);
      expect(waves, hasLength(3));
      for (final wave in waves) {
        expect(wave.beach, Beach.north);
        expect(wave.count, inInclusiveRange(6, 8));
      }
    });

    test('counts scale with the night', () {
      int total(int night) {
        final plan = nightPlan(night, math.Random(1));
        var n = 0;
        void walk(Step<NightStep> step) => switch (step) {
          Sequence<NightStep>(:final children) => children.forEach(walk),
          Land(:final crabs) => n += crabs.values.fold(0, (a, b) => a + b),
          _ => null,
        };
        walk(plan);
        return n;
      }

      expect(total(9), greaterThan(total(1) * 1.5));
    });

    test('a cleared night goes to dawn: NightCleared, next night, +15 Flame',
        () {
      final cleared = <NightCleared>[];
      final game = makeGame(probes: [collect(cleared)])..quietNight();
      game.world.resource<Flame>().current = 40;
      game.world.resource<NightDirector>().routine = Routine(
        const Sequence<NightStep>([UntilCleared()]),
      );
      game.seconds(1.5);
      game.frame();
      expect(cleared.single.night, 1);
      expect(game.status, GameStatus.dawnBoons);
      expect(game.world.resource<Run>().night, 2);
      expect(game.world.resource<Flame>().current, 55);
    });

    test('clearing night 10 wins the run', () {
      final game = makeGame()..quietNight();
      game.world.resource<Run>().night = 10;
      game.world.resource<NightDirector>().routine = Routine(
        const Sequence<NightStep>([UntilCleared()]),
      );
      game.seconds(1.5);
      game.frame();
      expect(game.status, GameStatus.won);
    });

    test('low tide opens the tide-pool path for the night', () {
      final game = makeGame()..quietNight();
      game.world.resource<NightDirector>().routine = Routine(
        const Sequence<NightStep>([Tide(TideState.low), Wait(5)]),
      );
      game.frame();
      expect(game.world.resource<TideLevel>().low, isTrue);
    });
  });

  group('lighthouse', () {
    test('FlameLow fires once; at 0 the run is lost', () {
      final low = <FlameLow>[];
      final game = makeGame(probes: [collect(low)])
        ..quietNight()
        ..flatGround();
      game.world.resource<Flame>().current = 31;
      for (var i = 0; i < 6; i++) {
        game.crab(CrabType.tarback, math.cos(i) * 3.8, math.sin(i) * 3.8);
      }
      game.seconds(1);
      game.frame();
      expect(low, hasLength(1));
      game.seconds(3);
      game.frame();
      game.frame();
      expect(game.status, GameStatus.lost);
      expect(low, hasLength(1));
    });
  });

  group('pause', () {
    test('pausing freezes the clock; resuming thaws it', () {
      final game = makeGame()..quietNight();
      game.emit(const PauseToggled());
      game.frame();
      game.frame();
      expect(game.world.state<Pause>(), Pause.paused);
      expect(game.clock.paused, isTrue);
      final tick = game.world.resource<FixedTime>().tick;
      game.seconds(1);
      expect(game.world.resource<FixedTime>().tick, tick);
      game.emit(const PauseToggled());
      game.frame();
      game.frame();
      expect(game.clock.paused, isFalse);
    });
  });

  group('feedback', () {
    test('the hitstop guard allows one freeze per 0.15 s', () {
      final clock = GameClock();
      final state = FeedbackState();
      state.freeze(clock, 0.05);
      expect(clock.freezeRemaining, 0.05);
      state.wallTime += 0.1;
      state.freeze(clock, 0.08);
      expect(clock.freezeRemaining, 0.05);
      state.wallTime += 0.1;
      state.freeze(clock, 0.08);
      expect(clock.freezeRemaining, 0.08);
    });
  });

  group('integration (M2)', () {
    test('night 1 with a scripted keeper is survivable with Flame > 50', () {
      final killed = <CrabKilled>[];
      final game = makeGame(probes: [collect(killed)])
        ..toDawnBuild()
        ..toNight();
      // He holds the lighthouse's north side and works the lantern.
      game.placeKeeper(0, 5.5);
      final buttons = game.world.buttons<KeeperAction>();
      for (var i = 0; i < 60 * 140 && game.status == GameStatus.night; i++) {
        final k = game.keeperAt;
        Entity? nearest;
        var best = double.infinity;
        game.world.query<SceneTransform>().having<Crab>().without<Dead>().each(
          (e, t) {
            final d = distSq2(t.x, t.z, k.x, k.z);
            if (d < best) (nearest, best) = (e, d);
          },
        );
        if (nearest != null) {
          final t = game.world.get<SceneTransform>(nearest!);
          game.aimAt(t.x, t.z);
          buttons.setPressed(KeeperAction.focus, best < 9 * 9);
        } else {
          buttons.release(KeeperAction.focus);
        }
        game.frame();
      }
      expect(game.status, GameStatus.dawnBoons);
      expect(killed.length, greaterThanOrEqualTo(18));
      expect(game.world.resource<Flame>().current, greaterThan(50));
    });
  });
}
