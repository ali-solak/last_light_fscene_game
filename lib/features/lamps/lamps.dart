/// Lamp posts: placed and moved at dawn, snuffed by spit, blasts and slams,
/// relit by the keeper (or by themselves, with Salted Wicks).
library;

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
import '../boons/boons.dart' show SaltedWicks;
import '../island/island.dart';
import '../../ui/world/world_icons.dart';
import '../nights/nights.dart' show Run;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/lamps.dart';
part 'systems/visuals.dart';

void installLamps(GameBuilder game) {
  game.world.insert(LampGrab());
  installLampRules(game);
  installLampVisuals(game);
}
