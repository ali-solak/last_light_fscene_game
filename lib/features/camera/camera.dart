/// The camera rig: a high three-quarter follow camera at night, an island
/// overview at dawn, a slow orbit on the title, and trauma-driven shake.
library;

import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show SpringArmComponent;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/billboard.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/inputs.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/settings.dart';
import '../../common/states.dart';
import '../island/island.dart' show HeightGrid, IslandAnchors;
import '../keeper/keeper.dart'
    show Keeper, KeeperBody, KeeperBrain, KeeperMode;

part 'data/config.dart';
part 'data/resources.dart';
part 'systems/rig.dart';

void installCamera(GameBuilder game) {
  game.world.insert(CameraRig());
  installCameraRig(game);
}
