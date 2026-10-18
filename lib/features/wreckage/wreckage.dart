/// Wreckage: every night the sea washes crates and powder barrels up the
/// beaches (a seeded Poisson-disc scatter, different each night). Crates
/// stand in the beam's way and break under a harpoon, a slam, a blast or
/// the keeper landing on them, spilling oil or a heart. Barrels blow up:
/// crabs flung and burned, the grass set alight, the next barrel set off.
/// More drifts offshore through the night: harpoon it and haul it in.
library;

import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show PoissonDiscSampler;
import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../assets/model_library.dart';
import '../../common/events.dart';
import '../../common/grid.dart';
import '../../common/physics_layers.dart';
import '../../common/pooled.dart';
import '../../common/render_layers.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../crabs/crabs.dart' show Crab, CrabBody, Dead, Hooked;
import '../fire/fire.dart' show FireField;
import '../fx/fx.dart';
import '../island/island.dart';
import '../keeper/keeper.dart' show Hearts, Keeper;
import '../lantern/lantern.dart' show Lantern, lanternOilMax;
import '../nights/nights.dart' show Run, RunSeed;

part 'data/components.dart';
part 'data/config.dart';
part 'systems/scatter.dart';
part 'systems/smash.dart';
part 'systems/tide.dart';
part 'systems/visuals.dart';

void installWreckage(GameBuilder game) {
  installWreckScatter(game);
  installWreckSmash(game);
  installWreckTide(game);
  installWreckVisuals(game);
}
