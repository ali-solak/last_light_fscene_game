import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_rapier/flutter_scene_rapier.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math.dart';

import 'app.dart';
import 'assets/model_library.dart';
import 'common/settings.dart';
import 'features/fx/fx.dart' show loadFxTextures;
import 'features/island/island.dart' show IslandAsset, loadMaterials;
import 'game.dart';
import 'warm_up.dart';

const String _saveKey = 'last_light.save';

/// Loads everything behind a loading screen, boots the game, and runs it.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape either way round, full screen.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const LoadingScreen());

  try {
    await RapierWorld.ensureInitialized();
    await Scene.initializeStaticResources();

    // Settings and the best night, kept between runs.
    final prefs = SharedPreferencesAsync();
    final settings = Settings();
    if (await prefs.getString(_saveKey) case final saved?) {
      settings.readJson(jsonDecode(saved) as Map<String, Object?>);
    }
    final save = SaveStore((data) => prefs.setString(_saveKey, jsonEncode(data)));

    final (models, materials, fxTextures) = await (
      loadModelLibrary(),
      loadMaterials(),
      loadFxTextures(),
    ).wait;

    final island = IslandAsset.fromModel(models.instance('island'));
    final scene = Scene();
    final game = await SceneGame.boot(
      scene: scene,
      physics: PhysicsWorld(RapierWorld(gravity: Vector3(0, -9.81, 0))),
      strictAccess: true,
      features: [
        configureGame(
          models,
          island,
          settings: settings,
          save: save,
          materials: materials,
          fxTextures: fxTextures,
        ),
        ...lastLightFeatures,
      ],
    );

    // Compile every shader now, not the first time something is drawn.
    await warmUpPipelines(scene, models, materials, fxTextures);
    runApp(LastLightApp(game));
  } catch (error, stack) {
    debugPrint('last_light: boot failed: $error\n$stack');
    runApp(LoadingScreen(error: error));
  }
}
