/// Juice (§6): reads events, writes only visuals and the clock. No rules.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

import '../../assets/clips.dart';
import '../../assets/model_library.dart';
import '../../common/billboard.dart';
import '../../common/events.dart';
import '../../common/physics_layers.dart';
import '../../common/pooled.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../ui/world/word_pop.dart';
import '../camera/camera.dart' show CameraRig;
import '../crabs/crabs.dart' show Crab, CrabModel, Dead;
import '../fx/fx.dart';
import '../island/island.dart' show Materials, setParam;
import '../keeper/keeper.dart' show Keeper;
import '../lamps/lamps.dart' show LampPost;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/corpses.dart';
part 'systems/debris.dart';
part 'systems/impact.dart';
part 'systems/particles.dart';
part 'systems/puffs.dart';

void installFeedback(GameBuilder game) {
  game.world.insert(FeedbackState());
  installImpact(game);
  installCorpses(game);
  installDebris(game);
  installPuffs(game);
  installParticles(game);
}

final RunCondition _visual =
    hasResource<Scene>().and(hasResource<ModelLibrary>());
