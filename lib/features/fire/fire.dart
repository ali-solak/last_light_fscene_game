/// Grass fire: burning oil, moth blasts and powder barrels set the grass
/// alight; fire creeps cell to cell on the 1 m grid, leaning with
/// the wind, burns a few seconds and leaves scorched ground. Burning cells
/// are light (the horde goes round them) and they scorch crabs. Storms
/// damp it down. Gameplay is headless; the flames are instanced cards.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../../common/wind.dart';
import '../fx/fx.dart';
import '../island/island.dart';

part 'data/config.dart';
part 'data/resources.dart';
part 'systems/spread.dart';
part 'systems/visuals.dart';

void installFire(GameBuilder game) {
  game.world.insert(FireField());
  installFireSpread(game);
  installFireVisuals(game);
}
