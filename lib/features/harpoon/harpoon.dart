/// The harpoon gun: hold to aim, release to fire. The bolt casts each step;
/// the first hit decides: a crab is speared and reeled in, a mirror's hook
/// is dragged round, flotsam is hauled ashore, a rock (Whaler's Reel)
/// hauls the keeper over.
library;

import 'dart:math' as math;

import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/model_library.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/inputs.dart';
import '../../common/physics_layers.dart';
import '../../common/pooled.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../boons/boons.dart' show Barbed, TripleBolt, WhalersReel, Whiplash;
import '../camera/camera.dart' show CameraRig;
import '../crabs/crabs.dart' show Crab, CrabBody, Dead, Hooked;
import '../fx/fx.dart';
import '../island/island.dart';
import '../keeper/keeper.dart'
    show Keeper, KeeperBody, KeeperBrain, KeeperMode, KeeperModel;
import '../mirrors/mirrors.dart' show Mirror;
import '../wreckage/wreckage.dart'
    show Flotsam, flotsamCentre, flotsamHookRadius;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/fire.dart';
part 'systems/visuals.dart';

void installHarpoon(GameBuilder game) {
  installHarpoonFire(game);
  installHarpoonVisuals(game);
}
