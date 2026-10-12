part of '../nights.dart';

const int nightCount = 10;

/// Wave sizes grow ×(1 + 0.12 × (night − 1)).
const double nightCountGrowth = 0.12;

/// The dusk title card.
const double nightDuskSeconds = 2.5;

/// Landing crabs scatter this far around their spawn point.
const double nightLandingSpread = 2.5;

/// `UntilCleared` waits at least this long, so a landing has spawned.
const double nightClearGrace = 1.0;

/// The run's starting supplies.
const int nightStartMirrors = 2;
const int nightStartLamps = 2;
const int nightStartSalt = 2;
const int nightStartBarricades = 2;

/// Dawn gives one more lamp every this many nights.
const int nightLampEvery = 3;
