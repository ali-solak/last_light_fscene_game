/// Weather: the wind (a steady breeze with gusts, turning slowly), storm
/// nights (rain, lightning, thunder, a thicker cloud deck), and the sea
/// fog banks that drift over the island. Gameplay reads only the `Wind`
/// resource (fire spread); the rest is look.
library;

import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/sets.dart';
import '../../common/states.dart';
import '../../common/wind.dart';
import '../camera/camera.dart' show CameraRig;
import '../fx/fx.dart';
import '../island/island.dart';
import '../nights/nights.dart' show Run, RunSeed;

part 'data/config.dart';
part 'data/resources.dart';
part 'systems/wind.dart';
part 'systems/sky.dart';

void installWeather(GameBuilder game) {
  game.world.insert(Weather());
  installWind(game);
  installSky(game);
}
