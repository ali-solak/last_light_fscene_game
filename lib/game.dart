import 'package:scene_dash_v2/scene_dash_v2.dart';

import 'assets/model_library.dart';
import 'common/events.dart';
import 'common/inputs.dart';
import 'common/pause.dart';
import 'common/pooled.dart';
import 'common/sets.dart';
import 'common/settings.dart';
import 'common/states.dart';
import 'common/wind.dart';
import 'features/bell/bell.dart';
import 'features/boons/boons.dart';
import 'features/camera/camera.dart';
import 'features/crabs/crabs.dart';
import 'features/defenses/defenses.dart';
import 'features/feedback/feedback.dart';
import 'features/fire/fire.dart';
import 'features/fx/fx.dart';
import 'features/gulls/gulls.dart';
import 'features/harpoon/harpoon.dart';
import 'features/island/island.dart';
import 'features/keeper/keeper.dart';
import 'features/lamps/lamps.dart';
import 'features/lantern/lantern.dart';
import 'features/light/light.dart';
import 'features/lighthouse/lighthouse.dart';
import 'features/mirrors/mirrors.dart';
import 'features/motes/motes.dart';
import 'features/nights/nights.dart';
import 'features/viewmodel/viewmodel.dart';
import 'features/weather/weather.dart';
import 'features/wreckage/wreckage.dart';

/// States, set order, input resources and the loaded assets: everything
/// the features share. The composition root and the tests both use it.
Feature configureGame(
  ModelLibrary models,
  IslandAsset island, {
  Settings? settings,
  SaveStore? save,
  Materials? materials,
  FxTextures? fxTextures,
  int? seed,
}) => (game) {
  game
    ..addState<GameStatus>(GameStatus.title)
    ..addState<Pause>(Pause.running)
    ..configureSets(Schedules.startup, GameSets.fixedOrder)
    ..configureSets(Schedules.fixedUpdate, GameSets.fixedOrder)
    ..configureSets(Schedules.update, GameSets.updateOrder);
  game.world
    ..insert(ButtonInput<KeeperAction>())
    ..insert(AxisInput<KeeperAxis>())
    ..insert(InputBuffer<KeeperAction>(window: 0.15))
    ..insert(AimInput())
    ..insert(BuildSelection())
    ..insert(CameraInput())
    ..insert(models)
    ..insert(island)
    ..insert(settings ?? Settings())
    ..insert(RunSeed(seed))
    ..insert(Wind());
  if (save != null) game.world.insert(save);
  if (materials != null) game.world.insert(materials);
  if (fxTextures != null) game.world.insert(fxTextures);
  configureEvents(game);
  installSettings(game);
  installPause(game);
  installPooled(game);
};

/// Every feature, in install order.
const List<Feature> lastLightFeatures = [
  installIsland,
  installCamera,
  installFx,
  installLight,
  installLighthouse,
  installKeeper,
  installLantern,
  installFire,
  installHarpoon,
  installMirrors,
  installLamps,
  installDefenses,
  installCrabs,
  installNights,
  installBell,
  installBoons,
  installFeedback,
  installViewmodel,
  installWeather,
  installWreckage,
  installMotes,
  installGulls,
];
