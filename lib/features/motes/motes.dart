/// Light motes: a killed crab gives up a few sparks of the light it fed on.
/// They hang where it died, then stream into the keeper's lamp when he is
/// close, a little oil each. A full lamp takes none: they hover and fade.
library;

import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show Steering;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/events.dart';
import '../../common/pooled.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../fx/fx.dart';
import '../island/island.dart' show HeightGrid;
import '../keeper/keeper.dart' show Keeper, KeeperBrain, KeeperMode;
import '../lantern/lantern.dart' show Lantern, lanternOilMax;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/drift.dart';
part 'systems/visuals.dart';

void installMotes(GameBuilder game) {
  installMoteDrift(game);
  installMoteVisuals(game);
}
