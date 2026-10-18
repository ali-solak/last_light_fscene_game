/// Gulls at dawn: once the night is beaten a small flock comes in off the
/// sea, lands on the sand and picks at it. Walk up and they scatter, wheel
/// round and settle somewhere quieter. They are gone by dusk. No rules.
library;

import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show Steering;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/grid.dart';
import '../../common/pooled.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../island/island.dart' show HeightGrid, IslandAnchors;
import '../keeper/keeper.dart' show Keeper;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/flock.dart';
part 'systems/visuals.dart';

void installGulls(GameBuilder game) {
  installGullFlock(game);
  installGullVisuals(game);
}
