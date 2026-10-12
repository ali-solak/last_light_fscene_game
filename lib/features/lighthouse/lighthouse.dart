/// The lighthouse and its Flame: climbing crabs drain it, dawn restores it,
/// and the run ends when it goes out.
library;

import 'dart:math' as math;

import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/model_library.dart';
import '../../common/events.dart';
import '../../common/physics_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../boons/boons.dart' show Preserves;
import '../camera/camera.dart' show CameraFade;
import '../crabs/crabs.dart' show Crab, CrabBrain, CrabMode, Dead, BroodSpawn;
import '../island/island.dart';
import '../light/light.dart'
    show Beam, beamOriginForward, beamOriginHeight, brazierFlameGift;
import '../nights/nights.dart' show Run;

part 'data/config.dart';
part 'data/resources.dart';
part 'systems/flame.dart';
part 'systems/visuals.dart';

void installLighthouse(GameBuilder game) {
  game.world.insert(Flame());
  installFlame(game);
  installLighthouseVisuals(game);
}
