/// Boons: one of three at each dawn. A boon is a component (or a resource
/// tweak) plus the systems elsewhere that check for it. No framework.
library;

import 'dart:math' as math;

import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../common/sets.dart';
import '../../common/states.dart';
import '../keeper/keeper.dart' show Keeper;
import '../light/light.dart' show Beam;
import '../nights/nights.dart' show Run;

part 'data/boons.dart';
part 'data/components.dart';
part 'data/config.dart';
part 'data/resources.dart';
part 'systems/offer.dart';

void installBoons(GameBuilder game) {
  game.world.insert(BoonOffer());
  installBoonOffer(game);
}
