/// Old Bram, the keeper: movement, dodge (with the close-call slow motion),
/// interactions, hearts, downed and respawn, and his animation.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter/widgets.dart' show Size;

import 'package:flutter_scene/physics.dart';
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
import '../../common/physics_layers.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/settings.dart';
import '../../common/states.dart';
import '../camera/camera.dart' show CameraRig;
import '../crabs/crabs.dart' show Crab, Dead;
import '../harpoon/harpoon.dart'
    show Harpoon, HarpoonMode, harpoonReloadFallback;
import '../island/island.dart';
import '../lantern/lantern.dart' show Lantern;
import '../../ui/world/world_icons.dart';
import '../nights/nights.dart' show Run, nightFirstBeach;

part 'data/bundles.dart';
part 'data/components.dart';
part 'data/config.dart';
part 'data/resources.dart';
part 'systems/animation.dart';
part 'systems/dusk.dart';
part 'systems/hearts.dart';
part 'systems/modes.dart';
part 'systems/movement.dart';

void installKeeper(GameBuilder game) {
  game.world.insert(SlowMotion());
  installKeeperHearts(game);
  installKeeperDusk(game);
  installKeeperModes(game);
  installKeeperMovement(game);
  installKeeperAnimation(game);
}
