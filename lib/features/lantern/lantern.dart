/// The keeper's oil lamp: always-on wide light, a focused hot beam that
/// burns oil, refills in the lighthouse beam, and a lamp to throw (Q) that
/// bursts into burning oil.
library;

import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/model_library.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/inputs.dart';
import '../../common/pooled.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../boons/boons.dart' show Flare, Smash, Wisp;
import '../island/island.dart';
import '../keeper/keeper.dart'
    show Keeper, KeeperBody, KeeperBrain, KeeperMode, KeeperModel;
import '../camera/camera.dart' show CameraRig;
import '../fx/fx.dart';
import '../light/light.dart' show LightMap, aimShaft, lightShaft;
import '../nights/nights.dart' show Run;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/bash.dart';
part 'systems/oil.dart';
part 'systems/visuals.dart';

void installLantern(GameBuilder game) {
  installLanternBash(game);
  installLanternOil(game);
  installLanternVisuals(game);
}
