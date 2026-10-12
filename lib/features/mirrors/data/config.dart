part of '../mirrors.dart';

/// A tap or drag this close to a placed mirror works on it.
const double mirrorPickRadius = 1.4;

/// Mirrors stand on open walkable ground: this far from each other, from
/// a brazier, and from the tower.
const double mirrorMinSpacing = 2.2;
const double mirrorBrazierClearance = 1.8;
const double mirrorTowerClearance = 5.5;
const double mirrorSnapDeg = 15;

/// A new mirror stands this far off facing the lighthouse (radians), so it
/// turns the beam a right angle instead of throwing it straight back.
const double mirrorDefaultTurn = math.pi / 4;

/// The glint flare on a mirror holding light.
const double mirrorFlareSize = 2.2;
const double mirrorFlareHeight = 1.25;
const int mirrorCatchSparks = 18;
const double mirrorFineSnapDeg = 1;

/// Night turning (§5.7).
const double mirrorTurnStepDeg = 45;
const double mirrorTurnHold = 0.4;
const double mirrorRaiseHold = 1.2;
const double mirrorInteractRange = 2.2;

/// Holding interact on an upright mirror: how fast its light swings to
/// where the keeper looks.
const double mirrorAimDegPerSecond = 240;

/// The throw preview: a dashed line of light along where the mirror sends
/// its light, from [mirrorPreviewStart] to [mirrorPreviewEnd] metres out.
const double mirrorPreviewStart = 0.9;
const double mirrorPreviewEnd = 9;
const double mirrorPreviewDash = 0.45;
const double mirrorPreviewGap = 0.3;
const double mirrorPreviewHeight = 0.3;
const double mirrorPreviewWidth = 0.07;

/// Outlines: the mirror he would use, and the one he is aiming (linear
/// RGBA); the preview's colour when only in reach and while aiming.
final Vector4 mirrorOutlineReach = Vector4(1.0, 0.75, 0.35, 0.5);
final Vector4 mirrorOutlineAim = Vector4(1.0, 0.85, 0.5, 1.0);
final Vector4 mirrorPreviewReach = Vector4(0.7, 0.5, 0.25, 1);
final Vector4 mirrorPreviewAim = Vector4(1.6, 1.15, 0.55, 1);

/// Harpoon drag: how fast a hooked mirror swings toward the keeper.
const double mirrorDragDegPerSecond = 160;

/// `yaw` eases to `targetYaw` with this half-life.
const double mirrorEaseHalfLife = 0.08;

/// The toppled-mirror icon floats this high.
const double mirrorAlertHeight = 2.4;
const int mirrorIconPool = 10;

/// Whether placed mirrors render a live planar reflection, and at what
/// fraction of the screen.
const bool mirrorLiveReflections = false;
const double mirrorReflectionScale = 0.3;
