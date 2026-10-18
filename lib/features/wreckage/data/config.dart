part of '../wreckage.dart';

/// How much wreckage a night washes up: a few, plus one per night, this
/// far apart, on low ground near the sea, clear of the tower and the
/// keeper's door. About this share are barrels.
const int wreckBase = 4;
const double wreckSpacing = 5;
const double wreckMinHeight = 0.4;
const double wreckMaxHeight = 3.2;
const double wreckTowerClearance = 9;
const double wreckDoorClearance = 5;
const double wreckBrazierClearance = 2.5;
const double wreckBarrelShare = 0.35;

/// A hit this close to a wreck breaks it; the keeper landing this close
/// stamps a crate in.
const double wreckHitRadius = 1.3;
const double wreckStompRadius = 1.1;

// The barrel: its blast, what it does to crabs and the keeper, and the
// fuse a neighbouring blast (or fire under it) lights.
const double barrelBlastRadius = 3.6;
const double barrelBlastDamage = 45;
const double barrelKnock = 7;
const double barrelKnockSeconds = 0.35;
const double barrelKeeperRadius = 2.2;
const double barrelFireRadius = 3;
const double barrelChainFuse = 0.25;
const double barrelBurnFuse = 1.0;

// Crate spills.
const double crateOilChance = 0.6;
const double crateHeartChance = 0.2;
const double pickupOil = 35;
const double pickupRadius = 1.4;
const double pickupSeconds = 40;

/// Spill glows kept ready per kind.
const int pickupRack = 6;

// Flotsam: wreckage still at sea, off a landing beach, past this depth,
// this far out from the beach. The first comes in this long into a night,
// then another this often, never more than a few at once; it drifts
// along the shore this fast and sinks after a while. Hauled up onto ground
// this high, it is beached.
const double flotsamFirst = 8;
const double flotsamEvery = 18;
const int flotsamMax = 3;
const double flotsamBarrelShare = 0.4;
const double flotsamOffshore = 5;
const double flotsamDepth = -1.2;
const double flotsamDriftSpeed = 0.35;
const double flotsamSeconds = 45;
const double flotsamBeachHeight = -0.6;
