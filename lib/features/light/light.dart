/// Light, the heart of the game: the lighthouse beam and its bounces, the
/// lantern, lamp posts and burning oil, all rasterised into one `LightMap`
/// every fixed step, and sampled into each crab's `LightExposure`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/grid.dart';
import '../../common/physics_layers.dart';
import '../../common/render_layers.dart';
import '../../common/events.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../boons/boons.dart' show HotWick, Sunfire;
import '../crabs/crabs.dart' show ReflectsBeam, Dead;
import '../fire/fire.dart' show FireField, addFlame, fireLightIntensity, flameSheets;
import '../fx/fx.dart';
import '../island/island.dart';
import '../keeper/keeper.dart' show Keeper, KeeperBody, KeeperBrain, KeeperMode;
import '../lamps/lamps.dart' show LampPost;
import '../lantern/lantern.dart' show Lantern, BurnPuddle;
import '../mirrors/mirrors.dart' show Mirror, PrismMirror;

part 'data/components.dart';
part 'data/config.dart';
part 'data/resources.dart';
part 'data/shaft.dart';
part 'systems/beam.dart';
part 'systems/braziers.dart';
part 'systems/exposure.dart';
part 'systems/light_map.dart';
part 'systems/visuals.dart';

void installLight(GameBuilder game) {
  game.world
    ..insert(Beam())
    ..insert(BeamPath())
    ..insert(LightMap())
    ..insert(BeamScratch());
  installBeam(game);
  installLightMap(game);
  installExposure(game);
  installBeamVisuals(game);
  installBraziers(game);
}
