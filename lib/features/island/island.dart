/// The island: HeightGrid, anchors, spawn points, pedestals, occluders,
/// tide, scenery, sky and the shared `.fmat` materials.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/model_library.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/inputs.dart';
import '../../common/physics_layers.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../camera/camera.dart' show CameraFade;
import '../light/light.dart' show Beam, BeamPath;
import '../lighthouse/lighthouse.dart' show Flame;

part 'data/bundles.dart';
part 'data/components.dart';
part 'data/config.dart';
part 'data/layout.dart';
part 'data/looks.dart';
part 'data/materials.dart';
part 'data/resources.dart';
part 'systems/build.dart';
part 'systems/materials.dart';
part 'systems/scenery.dart';

void installIsland(GameBuilder game) {
  game.world
    ..insert(TideLevel())
    ..insert(SkyTint())
    ..insert(IslandScenery());
  installIslandBuild(game);
  installIslandScenery(game);
  installIslandMaterials(game);
}
