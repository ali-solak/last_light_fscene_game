/// Crabs: flow-field navigation, the light response, attacks, the specials
/// of every type, the Tide Mother, damage and death.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/kit.dart' show Steering;
import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/clips.dart';
import '../../assets/model_library.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../boons/boons.dart'
    show
        BrineLight,
        BrineWave,
        Flashpoint,
        Kindling,
        Riptide,
        SaltRing,
        Undertow;
import '../island/island.dart';
import '../keeper/keeper.dart'
    show Keeper, KeeperBody, KeeperBrain, KeeperMode;
import '../lamps/lamps.dart' show LampPost;
import '../lantern/lantern.dart' show Lantern;
import '../light/light.dart' show LightExposure, LightFlags, LightMap;
import '../mirrors/mirrors.dart' show Mirror;
import '../nights/nights.dart' show Run;

part 'data/boss.dart';
part 'data/bundles.dart';
part 'data/components.dart';
part 'data/config.dart';
part 'data/resources.dart';
part 'systems/boss.dart';
part 'systems/behaviour.dart';
part 'systems/damage.dart';
part 'systems/navigation.dart';
part 'systems/shroud.dart';
part 'systems/specials.dart';
part 'systems/visuals.dart';

void installCrabs(GameBuilder game) {
  game.world.insert(FlowObstacles());
  game.world
    ..insert(FlowField())
    ..insert(SpatialGrid()..clear())
    ..insert(CrabScratch())
    ..insert(CrabPool());
  installCrabNavigation(game);
  installCrabBehaviour(game);
  installCrabSpecials(game);
  installTideMother(game);
  installCrabShroud(game);
  installCrabDamage(game);
  installCrabVisuals(game);
}

final RunCondition _night = inState(GameStatus.night);
final RunCondition _visual =
    hasResource<Scene>().and(hasResource<ModelLibrary>());
