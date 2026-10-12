/// Mirrors: stood anywhere on open ground and aimed at dawn to throw the
/// beam where it is needed (and into the signal braziers); turned,
/// harpoon-dragged and raised at night, toppled by slams.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/clips.dart';
import '../../assets/model_library.dart';
import '../../common/billboard.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/inputs.dart';
import '../../common/interact.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../harpoon/harpoon.dart' show Harpoon, HarpoonMode;
import '../island/island.dart';
import '../keeper/keeper.dart' show Keeper, KeeperBrain, KeeperMode;
import '../fx/fx.dart';
import '../light/light.dart' show CaughtLight;
import '../../ui/world/world_icons.dart';
import '../nights/nights.dart' show Run;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/build.dart';
part 'systems/night.dart';
part 'systems/visuals.dart';

void installMirrors(GameBuilder game) {
  game.world.insert(MirrorGrab());
  installMirrorBuild(game);
  installMirrorNight(game);
  installMirrorVisuals(game);
}
