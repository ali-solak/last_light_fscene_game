/// Particles: one world-space particle system per kind (sparks, embers,
/// smoke, fire, brine...), stepped on the game clock so hitstop and slow
/// motion hold them too. Any visual system bursts into them through the
/// `Fx` resource; gameplay never reads them. Absent headless.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_scene/noise.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/render_layers.dart';
import '../../common/wind.dart';

part 'data/pools.dart';
part 'data/textures.dart';
part 'systems/pools.dart';

void installFx(GameBuilder game) {
  installFxPools(game);
}
