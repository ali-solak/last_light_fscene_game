part of '../gulls.dart';

/// How many come in, from how far out to sea and how high.
const int gullCount = 6;
const double gullFromSea = 28;
const double gullFromHeight = 9;

/// They land on low dry sand this high, clear of the tower, and well away
/// from the keeper.
const double gullLandMin = 0.2;
const double gullLandMax = 2.5;
const double gullTowerClearance = 8;
const double gullKeeperClearance = 9;

/// Flight: cruise speed, steering force, the slow-down ring on the way
/// in, and how close counts as down.
const double gullSpeed = 7;
const double gullForce = 9;
const double gullSlowing = 4;
const double gullTouchdown = 0.25;

/// The keeper this close spooks one (and the birds near it); it climbs
/// away for this long, then picks somewhere else to land.
const double gullSpook = 4.5;
const double gullSpookSpread = 3;
const double gullFleeSeconds = 3.5;
const double gullClimb = 3.5;

/// Birds in the air keep this far apart.
const double gullSpacing = 1.4;
