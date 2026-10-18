part of '../motes.dart';

/// Motes per kill (the Tide Mother gives up a flood), and the oil each
/// puts back in the lamp.
const int moteCount = 3;
const int moteBossCount = 14;
const double moteOil = 2;

/// Thrown off the body this fast, slowed by this drag, hanging this high
/// over the ground; gone after this long, fading over the last second.
const double moteBurst = 2.4;
const double moteDrag = 2.6;
const double moteHover = 1.1;
const double moteSeconds = 9;

/// After this long they answer the lamp: within the pull radius they steer
/// into it, taken at the reach.
const double moteSettle = 0.5;
const double motePull = 5;
const double motePullSpeed = 9;
const double motePullForce = 28;
const double moteReach = 0.7;

/// The lamp is held about this high.
const double moteLampHeight = 1.1;

/// Glows kept ready.
const int moteRackSize = 40;
