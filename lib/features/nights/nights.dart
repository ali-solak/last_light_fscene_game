/// Nights: the run, the night director (a data-driven `Routine`), the dusk
/// card, landings, tide, and the dawn/won/lost transitions.
library;

import 'dart:math' as math;

import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../../common/events.dart';
import '../../common/sets.dart';
import '../../common/settings.dart';
import '../../common/states.dart';
import '../crabs/crabs.dart' show Crab, Dead, crabBundle;
import '../island/island.dart';

part 'data/config.dart';
part 'data/nights.dart';
part 'data/resources.dart';
part 'systems/director.dart';
part 'systems/run.dart';

void installNights(GameBuilder game) {
  game.world
    ..insert(Run(0))
    ..insert(NightDirector())
    ..insert(DuskTimer());
  installRun(game);
  installNightDirector(game);
}
