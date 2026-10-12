part of '../lighthouse.dart';

const double flameMax = 100;
const double flameLowMark = 30;
const double flameDawnRestore = 15;
const double flamePreservesRestore = 25;

/// Flame drained per second by each climbing crab (§5.6).
const double flameDrainScuttler = 1;
const double flameDrainTarback = 2.5;
const double flameDrainOther = 1.5;
const double flameDrainBrood = 1;

/// The tower's collider: a cylinder this wide and tall.
const double lighthouseRadius = 3.4;
const double lighthouseHeight = 18;

/// The lantern room's own glow.
const double lighthouseLightIntensity = 4;
const double lighthouseLightRange = 14;

/// The beam's real light: a shadow-casting spot from the lens, swept with
/// the head and aimed down at the ground this far out, so every crab and
/// rock it crosses throws a long moving shadow.
const double lighthouseSpotIntensity = 1500;
const double lighthouseSpotRange = 75;
const double lighthouseSpotAim = 24;
const double lighthouseSpotInner = 0.06;
const double lighthouseSpotOuter = 0.19;

/// Below this Flame fraction the beam stutters.
const double lighthouseFlickerBelow = 0.3;
