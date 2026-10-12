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
