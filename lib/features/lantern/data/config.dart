part of '../lantern.dart';

const double lanternOilMax = 100;
const double lanternFocusDrain = 12;
const double lanternBeamRefill = 20;
const double lanternDawnRefill = 40;
const double lanternSputterBelow = 20;

// The thrown lamp (Q): it arcs to the aim, shatters into burning oil, and
// a new one is lit after a while. Smash makes the blast bigger and the
// relight quicker.
const double lanternThrowRange = 11;
const double lanternThrowSeconds = 0.55;
const double lanternThrowArc = 2.6;
const double lanternPuddleRadius = 2.2;
const double lanternPuddleSeconds = 5;
const double lanternAwaySeconds = 6;
const double lanternThrowAnimSeconds = 0.6;
const double lanternSmashRadius = 3.4;
const double lanternSmashAway = 3.5;

/// Flare: hold the focus at least this long, and it costs this much oil.
const double lanternFlareHold = 0.6;
const double lanternFlareOil = 12;

/// How long a flare's blaze takes to fade.
const double lanternFlareFlash = 0.35;

// Visuals.
const double lanternFlickerHz = 9;
const double lanternFlickerAmount = 0.08;

/// The lamp's own warm glow around the keeper.
const double lanternGlowIntensity = 2.2;
const double lanternGlowRange = 5;

/// The lamp is held this far ahead of him and this high.
const double lanternHandForward = 0.35;
const double lanternHandHeight = 1.1;

/// The real light: a shadow-casting spot. Wide, a soft pool a few metres
/// ahead; focused, a hot narrow beam driven at the aim point.
const double lanternSpotWide = 16;
const double lanternSpotWideRange = 13;
const double lanternWideInner = 0.3;
const double lanternWideOuter = 0.62;
const double lanternWideDrop = 4.5;
const double lanternSpotFocus = 140;
const double lanternSpotFocusRange = 18;
const double lanternFocusInner = 0.04;
const double lanternFocusOuter = 0.13;

/// How far the focused light reaches (third person aims within this).
const double lanternFocusLength = 10;


/// Seconds to swing between wide and focused.
const double lanternFocusHalfLife = 0.06;

/// Embers shaken off the hot focused lamp, per second.
const double lanternFocusEmbers = 14;

/// Sparks per second off where the focused beam lands.
const double lanternHotspotSparks = 10;

/// First person: the lamp's light leaves from the left hand (metres right,
/// up, forward of the eye) and, held low, aims this far below the view.
final Vector3 lanternFpHand = Vector3(-0.22, -0.2, 0.4);
const double lanternFpWideDip = 0.12;

/// First person: the lamp's warm glow sits this far ahead (and low), at
/// this share of its strength.
const double lanternFpGlowAhead = 1.0;
const double lanternFpGlowScale = 0.55;

/// The focused beam: a thin shaft of lit dust from the lamp to where it
/// lands. Its width at the far end and at the lamp, how bright (times the
/// eased focus), how near the eye it fades out entirely (so looking down
/// it never blinds), and how far ahead of the hand it starts in first
/// person.
const double lanternBeamRadius = 0.14;
const double lanternBeamStartShare = 0.2;
const double lanternBeamIntensity = 3.2;
const double lanternBeamNearFade = 2.4;
const double lanternBeamAhead = 0.9;

/// First person: the spot's apex this far ahead of the lamp hand, past
/// the gun's muzzle.
const double lanternFpSpotAhead = 0.75;

// The bash: the lamp swung as a club. How often, how long the swing
// lasts, how much oil each crab struck rekindles, and how hard the lamp
// flares as it catches.
const double lanternBashCooldown = 0.55;
const double lanternBashSwing = 0.28;
const double lanternBashKindle = 7;
const double lanternBashFlare = 0.6;

/// The lamp's light, warm when it burns.
final Vector3 lanternSpotColor = Vector3(1.0, 0.74, 0.45);
final Vector3 lanternGlowColor = Vector3(1.0, 0.68, 0.36);
final Vector3 lanternFlameCore = Vector3(1.5, 1.2, 0.6);
final Vector3 lanternFlameTip = Vector3(1.0, 0.35, 0.08);

/// Out of oil the lamp smoulders, unmistakably: its light turns ember red
/// and breathes slowly (the spot at a small share, its own glow at more,
/// so the keeper stands in a red pool), the flame shrinks to a steady
/// coal, and embers rise off it. How fast it turns, and its colours.
const double lanternDrySpot = 0.22;
const double lanternDryGlow = 0.8;
const double lanternDryFlame = 0.75;
const double lanternDryBreathHz = 1.2;
const double lanternDryEmbers = 7;
const double lanternDryHalfLife = 0.12;
final Vector3 lanternDryLight = Vector3(1.0, 0.3, 0.06);
final Vector3 lanternDryFlameCore = Vector3(1.6, 0.4, 0.06);
final Vector3 lanternDryFlameTip = Vector3(0.7, 0.1, 0.02);
final Vector3 lanternGlassWarm = Vector3(1.3, 0.85, 0.4);
final Vector3 lanternDryGlassWarm = Vector3(1.7, 0.32, 0.05);
const double lanternDryGlass = 1.2;

/// The smoulder's slow breath at [time], 0.55 .. 1.
double lanternDryBreath(double time) =>
    0.775 + 0.225 * math.sin(time * lanternDryBreathHz * math.pi * 2);
