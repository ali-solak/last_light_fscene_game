part of '../weather.dart';

/// Nights that roll in as storms (1-based).
const Set<int> weatherStormNights = {4, 7, 9, 10};

/// The breeze on a calm night and the gale in a storm (0..1), and how
/// much the gusts add.
const double weatherCalmWind = 0.3;
const double weatherStormWind = 0.75;
const double weatherGustCalm = 0.35;
const double weatherGustStorm = 0.8;

/// How fast the weather turns (half-life, seconds), and how fast the wind
/// veers (radians per second at most).
const double weatherEase = 6;
const double weatherVeer = 0.03;

// Lightning: seconds between strikes, the flash, and the thunder after.
const double weatherBoltMin = 5;
const double weatherBoltMax = 13;
const double weatherFlashSeconds = 0.45;
const double weatherThunderDelay = 0.7;
const double weatherThunderTrauma = 0.35;

// Rain falls in a box round the camera.
const double weatherRainPerSecond = 520;
const double weatherRainBox = 14;
const double weatherRainHeight = 9;

// Sea fog banks drift round the camera, this many at a time.
const int weatherFogBanks = 26;
const double weatherFogNear = 6;
const double weatherFogFar = 34;
