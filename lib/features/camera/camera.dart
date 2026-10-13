/// The camera: through the keeper's eyes at night (or over his shoulder,
/// in third person), an island overview at dawn, a slow orbit on the
/// title, trauma-driven shake, and the scenery and labels that react to
/// where it looks.
library;

import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show SpringArmComponent;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/billboard.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/inputs.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/settings.dart';
import '../../common/states.dart';
import '../island/island.dart' show HeightGrid, IslandAnchors;
import '../keeper/keeper.dart' show Keeper, KeeperBody, KeeperBrain, KeeperMode;

part 'data/config.dart';
part 'data/resources.dart';
part 'systems/billboards.dart';
part 'systems/first_person.dart';
part 'systems/occluders.dart';
part 'systems/rig.dart';
part 'systems/shake.dart';
part 'systems/view.dart';

void installCamera(GameBuilder game) {
  game.world.insert(CameraRig());
  installCameraRig(game);
  installFirstPerson(game);
  installCameraShake(game);
  installCameraView(game);
  installBillboards(game);
  installOccluderFade(game);
}
