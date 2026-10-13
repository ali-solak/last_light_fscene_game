part of '../camera.dart';

// The night camera: third person over the keeper's shoulder on a spring
// arm that pulls in when terrain or a building would block the view.
const double cameraPitchDeg = 16;
const double cameraPitchMinDeg = 2;
const double cameraPitchMaxDeg = 65;
const double cameraDistance = 5.6;
const double cameraFollowHalfLife = 0.06;
const double cameraLookHeight = 1.7;
const double cameraShoulder = 0.6;
const double cameraArmMin = 1.2;
const double cameraArmProbe = 0.25;

/// Mouse-look sensitivity, radians per logical pixel.
const double cameraLookSensitivity = 0.0035;

/// The camera starts looking along +Z (from the cottage side toward the
/// lighthouse); the player orbits it from there.
const double cameraFollowYaw = 0;

// Player zoom and orbit.
const double cameraZoomMin = 0.55;
const double cameraZoomMax = 2.4;
const double cameraZoomStep = 0.1;
const double cameraOrbitHalfLife = 0.08;
const double cameraOrbitDegPerSecond = 110;

// The dawn overview.
const double cameraOverviewPitchDeg = 58;
const double cameraOverviewDistance = 62;
const double cameraOverviewHalfLife = 0.4;

// The title orbit.
const double cameraTitlePitchDeg = 32;
const double cameraTitleDistance = 58;
const double cameraTitleOrbitDegPerSecond = 4;

// Shake: offset = trauma² × noise, decaying on wall time.
const double cameraTraumaDecay = 1.5;
const double cameraShakeMetres = 0.6;
const double cameraShakeFrequency = 22;

const double cameraFovDeg = 45;

// First person: eyes at head height, a ~90° horizontal view (60° vertical
// at 16:9), a near plane close enough for the hands, pitch short of
// straight up and down. Aiming narrows the view; focusing the lamp a
// little. Head bob follows the stride; landing dips the view.
const double fpEyeHeight = 1.6;

/// Where the view starts on entering first person: just below level, the
/// gun's muzzle and the shore ahead both in view.
const double fpStartPitchDeg = 3;
const double fpFovDeg = 62;
const double fpAimFovDeg = 44;
const double fpFocusFovDeg = 54;
const double fpNear = 0.04;
const double fpPitchLimitDeg = 82;
const double fpLookSensitivity = 0.0028;

/// Steps per second never pass this however fast he runs (a quick run is
/// longer strides, not a faster patter), and a step covers this much.
const double fpStepsMax = 1.9;
const double fpStepLength = 1.3;
const double fpBobUp = 0.022;
const double fpBobSide = 0.014;
const double fpDipPerMetre = 0.09;
const double fpDipHalfLife = 0.12;

/// Shake in first person turns the view (radians per metre of shake).
const double fpShakeTurn = 0.08;

/// Terrain avoidance: the eye keeps this high over the ground under and
/// behind it, tilting the boom up (eased) rather than crashing into the
/// slope.
const double cameraGroundClearance = 1.1;
const double cameraLiftHalfLife = 0.12;

/// When a wall squeezes the arm below this fraction short, the boom tilts
/// up by this much per unit of squeeze (eased), to look over it.
const double cameraSqueezeStart = 0.3;
const double cameraSqueezeLift = 1.4;
const double cameraSqueezeHalfLife = 0.2;

/// Recoil kick springs back with this half-life.
const double cameraKickHalfLife = 0.09;

// Aiming down the harpoon: the arm pulls in over the shoulder, the lens
// narrows and the look slows, eased in and out. Lantern focus leans in a
// little.
const double cameraAimFovDeg = 30;
const double cameraAimArm = 0.45;
const double cameraAimShoulder = 1.0;
const double cameraAimRaise = 0.12;
const double cameraAimLookScale = 0.55;
const double cameraAimHalfLife = 0.07;
const double cameraFocusAim = 0.65;
const double cameraSideHalfLife = 0.14;

/// Occluders fade when the camera's sight line passes this close inside
/// their radius.
const double cameraFadeMargin = 0.6;
