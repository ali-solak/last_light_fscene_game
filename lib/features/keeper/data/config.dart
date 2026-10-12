part of '../keeper.dart';

// Movement (§5.3).
const double keeperRunSpeed = 6.2;
const double keeperAcceleration = 48;
const double keeperTurnRate = 16;
const double keeperFocusSpeedFactor = 0.5;
const double keeperAimSpeedFactor = 0.55;
const double keeperReloadSpeedFactor = 0.4;
const double keeperInteractSpeedFactor = 0;
const double keeperWalkBelow = 2.6;
const double keeperStride = 4.2;

// The jump: a quick leap that carries his run (or hops him forward from
// standing), steerable a little in the air, i-framed on the way up.
const double keeperJumpSpeed = 7.2;
const double keeperGravity = 24;
const double keeperJumpCarry = 6.4;
const double keeperJumpHop = 3.0;
const double keeperAirControl = 0.35;
const double keeperIFrameStart = 0.02;
const double keeperIFrameEnd = 0.3;
const double keeperJumpCooldown = 0.15;

/// The landing clip plays this long after touching down.
const double keeperLandSeconds = 0.22;

// The close call.
const double keeperCloseCallRadius = 1.5;
const double keeperSlowScale = 0.35;
const double keeperSlowSeconds = 0.35;
const double keeperSlowRecover = 0.25;

// Hearts.
const int keeperHearts = 5;
const double keeperHitInvuln = 1.0;
const double keeperHitStagger = 0.4;
const double keeperDownedSeconds = 4;

// Reeling himself to a harpooned rock (Whaler's Reel).
const double keeperReelSpeed = 11;

/// Ground raycast from this high above the feet, this far down.
const double keeperGroundProbe = 1.5;
const double keeperGroundReach = 4;

/// The keeper's collision capsule.
const double keeperRadius = 0.35;
const double keeperHalfHeight = 0.55;

/// Dusk: his post is this far (m) out from the tower toward the first
/// landing, on open ground found within this many cells of it.
const double keeperPostDistance = 9;
const int keeperPostSearch = 6;
