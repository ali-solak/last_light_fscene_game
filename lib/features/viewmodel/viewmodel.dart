/// The first-person hands: the harpoon gun in the right, the oil lamp in
/// the left, drawn up close in front of the eye. They sway behind the
/// mouse, bob with the stride, kick on a shot, dip to reload, come to the
/// centre to aim, and the lamp rises to focus and is gone while thrown.
/// Pose changes are tweens; following motion (sway, bob, recoil) chases
/// with `smoothTo`. Pure visual: gameplay never reads it.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/model_library.dart';
import '../../common/events.dart' show HarpoonFired;
import '../../common/render_layers.dart';
import '../camera/camera.dart' show CameraRig;
import '../fx/fx.dart' show FxTextures;
import '../harpoon/harpoon.dart' show Harpoon, HarpoonMode;
import '../island/island.dart' show Materials, assignNode, setParam;
import '../keeper/keeper.dart' show Keeper, KeeperBrain;
import '../lantern/lantern.dart'
    show
        Lantern,
        lanternBashSwing,
        lanternDryBreath,
        lanternDryGlassWarm,
        lanternGlassWarm;

part 'data/config.dart';
part 'data/resources.dart';
part 'systems/hands.dart';

void installViewmodel(GameBuilder game) {
  installHands(game);
}
