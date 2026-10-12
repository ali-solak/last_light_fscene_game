import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_rapier/flutter_scene_rapier.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math.dart';

import 'app.dart';
import 'assets/glb.dart';
import 'assets/model_library.dart';
import 'common/events.dart';
import 'common/inputs.dart';
import 'features/boons/boons.dart';
import 'features/camera/camera.dart';
import 'features/crabs/crabs.dart' show Crab, Dazzled, Dead, Exposed, crabBundle;
import 'features/fx/fx.dart';
import 'common/settings.dart';
import 'common/states.dart';
import 'features/island/island.dart';
import 'features/keeper/keeper.dart' show Keeper;
import 'features/lantern/lantern.dart' show Lantern;
import 'features/mirrors/mirrors.dart' show Mirror;
import 'game.dart';
import 'warm_up.dart';

const String _saveKey = 'last_light.save';

/// The composition root: load everything, boot the game, run the app.
Future<void> boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A landscape game: either way round, never portrait.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Full screen: the system bars only come back on a swipe.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const LoadingApp());
  try {
    await RapierWorld.ensureInitialized();
    await Scene.initializeStaticResources();

    final prefs = SharedPreferencesAsync();
    final settings = Settings();
    if (await prefs.getString(_saveKey) case final saved?) {
      settings.readJson(jsonDecode(saved) as Map<String, Object?>);
    }
    final save = SaveStore((data) => prefs.setString(_saveKey, jsonEncode(data)));

    final (models, island, materials, fxTextures) = await (
      loadModelLibrary(),
      rootBundle
          .load('assets/models/environment/island.glb')
          .then((data) => IslandAsset(GlbDocument.parse(data.buffer.asUint8List()))),
      loadMaterials(),
      loadFxTextures(),
    ).wait;

    final scene = Scene();
    final game = await SceneGame.boot(
      scene: scene,
      physics: PhysicsWorld(RapierWorld(gravity: Vector3(0, -9.81, 0))),
      strictAccess: true,
      diagnostics: AppDiagnostics(
        profileSystems: kDebugMode,
        slowSystemThreshold: const Duration(milliseconds: 25),
        onSlowSystem: (slow) => debugPrint(
          'last_light: slow system ${slow.timing.debugName} '
          '${slow.elapsed.inMilliseconds} ms',
        ),
      ),
      features: [
        configureGame(
          models,
          island,
          settings: settings,
          save: save,
          materials: materials,
        ),
        (game) => game.world.insert(fxTextures),
        ...lastLightFeatures,
      ],
    );
    // Every shader compiled now, behind the loading screen, not mid-play.
    await warmUpPipelines(scene, models, materials, fxTextures);
    if (kDebugMode) _reportSlowSystems(game);
    if (kDebugMode) _reportHitches(game, scene);
    if (!kReleaseMode) _autoplay(game);
    runApp(GameHost(game: game, child: const LastLightApp()));
  } catch (error, stack) {
    debugPrint('last_light: boot failed: $error\n$stack');
    runApp(LoadingApp(error: error));
  }
}

/// Debug: every 10 s, the five slowest systems by average time (§8).
void _reportSlowSystems(SceneGame game) {
  var since = 0.0;
  game.frameTick.addListener(() {
    since += game.world.unscaledDelta;
    if (since < 10) return;
    since = 0;
    final profiler = game.engine.profiler;
    if (profiler == null) return;
    final timings = profiler.timings.where((t) => t.runs > 0).toList()
      ..sort((a, b) => (b.totalMicros / b.runs).compareTo(a.totalMicros / a.runs));
    debugPrint('last_light: slowest systems (avg µs per run):');
    for (final t in timings.take(5)) {
      debugPrint('  ${t.debugName} [${t.schedule.id}] '
          '${(t.totalMicros / t.runs).toStringAsFixed(1)} µs over ${t.runs} runs');
    }
  });
}

/// Debug: a frame over 80 ms names its slowest render passes and the
/// pipeline cache (a growing cache means shaders compiled mid-play).
void _reportHitches(SceneGame game, Scene scene) {
  var cache = 0;
  game.frameTick.addListener(() {
    final frame = scene.renderStats.latest;
    if (frame == null) return;
    final grew = frame.pipelineCacheSize - cache;
    cache = frame.pipelineCacheSize;
    if (game.world.unscaledDelta < 0.08 && frame.cpuMicros < 40000) return;
    final passes = [for (final v in frame.views) ...v.passes]
      ..sort((a, b) => b.cpuMicros.compareTo(a.cpuMicros));
    debugPrint('last_light: hitch ${(game.world.unscaledDelta * 1000).round()} ms, '
        'render cpu ${frame.cpuMicros ~/ 1000} ms, pipelines +$grew ($cache), '
        'passes ${[for (final p in passes.take(4)) '${p.name} ${p.cpuMicros ~/ 1000}ms']}');
  });
}

/// Debug and profile: `--dart-define=LL_AUTOPLAY=boons|build|night` walks
/// the flow on its own (for screenshots and smoke runs): start, pick the first boon,
/// ring the bell, and at night hold the lantern while turning on the spot.
void _autoplay(SceneGame game) {
  const target = String.fromEnvironment('LL_AUTOPLAY');
  if (target.isEmpty) return;
  Future<void> step(int ms, void Function() action) =>
      Future.delayed(Duration(milliseconds: ms), action);
  () async {
    await step(1500, () => game.emit(const GameStarted()));
    if (target == 'boons') return;
    await step(1500, () {
      final offer = game.world.resource<BoonOffer>().boons;
      if (offer.isNotEmpty) game.emit(BoonPicked(offer.first.id));
    });
    // Stand mirrors a few metres in from the braziers, toward the tower.
    await step(800, () {
      game.world.query2<BrazierStand, SceneTransform>().each((_, _, t) {
        final d = math.sqrt(t.x * t.x + t.z * t.z);
        if (d < 1) return;
        game.emit(BuildAt(t.x - t.x / d * 4, t.z - t.z / d * 4, BuildPhase.tap));
      });
    });
    // A salt line and a barricade on the way up from the keeper's door.
    await step(400, () {
      final door = game.world.resource<IslandAnchors>().keeperSpawn;
      final select = game.world.resource<BuildSelection>();
      select.tool = .salt;
      game.emit(BuildAt(door.x + 3, door.z - 4, BuildPhase.tap));
    });
    await step(300, () {
      final door = game.world.resource<IslandAnchors>().keeperSpawn;
      game.world.resource<BuildSelection>().tool = .barricade;
      game.emit(BuildAt(door.x - 3, door.z - 5, BuildPhase.tap));
    });
    if (target == 'build') return;
    await step(1500, () => game.emit(const BellRung()));
    await step(6000, () {
      game.world.buttons<KeeperAction>().press(KeeperAction.focus);
      game.world.axes<KeeperAxis>().setValue(KeeperAxis.moveY, 1);
    });
    await step(900, () {
      game.world.axes<KeeperAxis>().setValue(KeeperAxis.moveY, 0);
      // `LL_SHOT=lamp` keeps the lamp held up for the screenshot.
      if (const String.fromEnvironment('LL_SHOT') != 'lamp') {
        game.world.buttons<KeeperAction>().release(KeeperAction.focus);
      }
      // `--dart-define=LL_SHOT=wide` pulls the camera up and back toward
      // the lighthouse for screenshots of the beam.
      if (const String.fromEnvironment('LL_SHOT') == 'fire') {
        // Set the grass alight a few metres ahead.
        final t = game.world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
        final rig = game.world.resource<CameraRig>();
        if (t != null) {
          game.emit(MothExploded(Vector3(
            t.x + rig.forwardX * 5,
            t.y,
            t.z + rig.forwardZ * 5,
          )));
        }
      }
      if (const String.fromEnvironment('LL_SHOT') == 'bash') {
        // The lamp run dry, a basher held just ahead, swung at again and
        // again: the smoulder, the sparks, the rekindle, the swing.
        final k = game.world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
        final rig = game.world.resource<CameraRig>();
        game.world.query<Lantern>().having<Keeper>().each((_, l) => l.oil = 0);
        if (k != null) {
          final at = Vector3(k.x + rig.forwardX * 1.9, k.y, k.z + rig.forwardZ * 1.9);
          final crab = game.world.spawn(crabBundle(CrabType.basher, at));
          game.world.add(crab, const Dazzled());
        }
        for (var i = 0; i < 40; i++) {
          Future.delayed(Duration(milliseconds: 700 * i), () {
            game.world.buffer<KeeperAction>().record(KeeperAction.bash);
          });
        }
      }
      if (const String.fromEnvironment('LL_SHOT') == 'dry') {
        // The lamp kept dry: the smoulder, the embers, the HUD hint.
        Timer.periodic(const Duration(milliseconds: 100), (_) {
          game.world.query<Lantern>().having<Keeper>().each((_, l) => l.oil = 0);
        });
      }
      if (const String.fromEnvironment('LL_SHOT') == 'demo') _demoPilot(game);
      if (const String.fromEnvironment('LL_SHOT') == 'pause') {
        Future.delayed(const Duration(seconds: 6), () => game.emit(const PauseToggled()));
      }
      if (const String.fromEnvironment('LL_SHOT') == 'mirror') {
        // Stand beside a placed mirror looking at it, then hold interact
        // to aim it (the prompt, the outline and the throw preview).
        final mirror = game.world.query<SceneTransform>().having<Mirror>().firstOrNull?.$2;
        final t = game.world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
        if (mirror != null && t != null) {
          final grid = game.world.resource<HeightGrid>();
          final x = mirror.x + 1.6, z = mirror.z + 0.6;
          t.setTranslation(x, grid.sample(x, z), z);
          final rig = game.world.resource<CameraRig>();
          for (var i = 0; i < 120; i++) {
            Future.delayed(Duration(milliseconds: 50 * i), () {
              rig
                ..pitch = 0.18
                ..yawGoal = math.atan2(mirror.x - x, mirror.z - z) + (i > 60 ? 0.9 : 0);
              if (i == 40) {
                game.world.buttons<KeeperAction>().setPressed(KeeperAction.interact, true);
                game.world.buffer<KeeperAction>().record(KeeperAction.interact);
              }
            });
          }
        }
      }
      if (const String.fromEnvironment('LL_SHOT') == 'tower') {
        // Stand off the tower and look at it, the beam sweeping past.
        final grid = game.world.resource<HeightGrid>();
        final t = game.world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
        const x = 13.0, z = 12.0;
        t?.setTranslation(x, grid.sample(x, z), z);
        final rig = game.world.resource<CameraRig>();
        for (var i = 0; i < 200; i++) {
          Future.delayed(Duration(milliseconds: 50 * i), () {
            rig
              ..zoom = 2.2
              ..pitch = 0.22
              ..yawGoal = math.atan2(-x, -z);
          });
        }
      }
      if (const String.fromEnvironment('LL_SHOT') == 'wide') {
        final rig = game.world.resource<CameraRig>();
        final k = game.world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
        // Held for a while: the controls own the rig every frame otherwise.
        for (var i = 0; i < 80; i++) {
          Future.delayed(Duration(milliseconds: 50 * i), () {
            rig
              ..zoom = 1.8
              ..pitch = 0.95;
            if (k != null) rig.yawGoal = math.atan2(-k.x, -k.z);
          });
        }
      }
    });
    await step(2000, () {
      final view = game.world.query<CameraView>().firstOrNull?.$2;
      final rig = game.world.resource<CameraRig>();
      debugPrint('last_light: camera yaw=${rig.yaw} pitch=${rig.pitch} '
          'target=${rig.target} eye=${rig.position} '
          'arm=${view?.arm.currentLength} node=${view?.node.globalTransform.getTranslation()}');
    });
  }();
}

/// Debug: `LL_SHOT=demo` plays the night for a recording. He turns to the
/// nearest crab and walks up to it, burns its shroud off with the focused
/// lamp, harpoons it once bare, and swings the lamp at anything close.
void _demoPilot(SceneGame game) {
  final world = game.world;
  const dt = 0.033;
  var held = 0.0, sinceShot = 0.0, sinceBash = 0.0;
  Timer.periodic(const Duration(milliseconds: 33), (_) {
    sinceShot += dt;
    sinceBash += dt;
    final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
    if (keeper == null || world.state<GameStatus>() != GameStatus.night) return;
    final buttons = world.buttons<KeeperAction>();
    final axes = world.axes<KeeperAxis>();

    Entity? crab;
    SceneTransform? at;
    var best = 30.0 * 30.0;
    world.query<SceneTransform>().having<Crab>().without<Dead>().each((e, t) {
      final d = (t.x - keeper.x) * (t.x - keeper.x) + (t.z - keeper.z) * (t.z - keeper.z);
      if (d < best) (crab, at, best) = (e, t, d);
    });
    if ((crab, at) case (final crab?, final at?)) {
      final d = math.sqrt(best);
      final exposed = world.has<Exposed>(crab);
      world.resource<CameraRig>()
        ..yawGoal = math.atan2(at.x - keeper.x, at.z - keeper.z)
        ..pitch = math.atan2(1.3, d).clamp(0.03, 0.5);
      axes.setValue(KeeperAxis.moveY, d > 8 ? 1 : 0);
      buttons.setPressed(KeeperAction.focus, d > 3 && d < 15 && !exposed);
      if (held > 0) {
        held -= dt;
        if (held <= 0) buttons.setPressed(KeeperAction.harpoon, false);
      } else if (exposed && d > 3 && d < 16 && sinceShot > 2) {
        buttons.setPressed(KeeperAction.harpoon, true);
        (held, sinceShot) = (0.3, 0);
      }
      if (d < 2.4 && sinceBash > 0.6) {
        world.buffer<KeeperAction>().record(KeeperAction.bash);
        sinceBash = 0;
      }
    } else {
      axes.setValue(KeeperAxis.moveY, 0);
      buttons.release(KeeperAction.focus);
      world.resource<CameraRig>().yawGoal += 0.01;
    }
  });
}
