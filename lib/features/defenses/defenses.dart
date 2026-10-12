/// Defenses the keeper lays out at dawn for the coming night: salt lines
/// (the horde goes round them if it can, and is slowed and stung where it
/// must cross, wearing them away) and driftwood barricades (a wall the
/// horde must chew through). They shape the paths the crabs take, so they
/// work with the light: herd the horde into the beam.
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
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../crabs/crabs.dart' show FlowObstacles;
import '../fx/fx.dart';
import '../island/island.dart';
import '../nights/nights.dart' show Run;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/build.dart';
part 'systems/night.dart';
part 'systems/visuals.dart';

void installDefenses(GameBuilder game) {
  game.world.insert(DefenseGrab());
  installDefenseBuild(game);
  installDefenseNight(game);
  installDefenseVisuals(game);
}
