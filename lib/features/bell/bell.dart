/// The bell by the cottage: ring it at dawn (interact or the UI button) to
/// call the dusk.
library;

import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/model_library.dart';
import '../../common/events.dart';
import '../../common/interact.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../island/island.dart';

part 'data/components.dart';
part 'data/config.dart';
part 'systems/bell.dart';

void installBell(GameBuilder game) {
  installBellRinging(game);
}
