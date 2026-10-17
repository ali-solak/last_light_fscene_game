part of '../light.dart';

// The lighthouse beam.
const double beamDegreesPerSecond = 22;
const double beamLength = 34;
const double beamStep = 0.25;
const double beamHalfWidth = 1.2;
const double beamIntensity = 4.0;
const double beamBounceLoss = 0.15;
const int beamMaxBounces = 4;

/// Ignore hits closer than this, so a bounce never re-hits its own mirror.
const double beamMinHit = 0.05;

/// A placed mirror reflects inside this circle around its pedestal.
const double beamMirrorRadius = 0.7;

/// A mirror struck by the beam keeps throwing it this long, fading out over
/// the last [mirrorFadeSeconds]; a weaker relay than this is dark.
const double mirrorHoldSeconds = 6;
const double mirrorFadeSeconds = 2;
const double beamRelayMinIntensity = 0.5;

/// A glassback reflects inside this circle.
const double beamGlassbackRadius = 0.6;

/// A prism splits the beam into three, this far apart (radians).
const double beamPrismSpread = 0.45;

/// The beam skims this far above the ground it starts from; terrain rising
/// above that stops it (a cliff, the plateau edge).
const double beamClearance = 1.5;

/// `beam_origin` sits this far ahead of the lighthouse axis and this high
/// above the anchor (lamp_head 13.4 + lens 1.5 in `lighthouse.glb`).
const double beamOriginForward = 1.74;
const double beamOriginHeight = 14.9;

// Beam visuals.
const int beamVisualSlots = 16;

/// A relay shaft leaves the mirror face this high above its pedestal.
const double beamMirrorFaceHeight = 1.25;

/// Shaft radius at the far end, as a multiple of the beam half-width, and
/// at the source as a fraction of that.
const double beamShaftWidthLens = 1.35;
const double beamShaftWidthRelay = 1.0;
const double beamShaftStartRadius = 0.28;

/// The ground-light box: a little wider than the lit cells, reaching this
/// far below the lowest and above the highest ground under it.
const double beamStripeWidth = 1.15;
const double beamStripeBelow = 1.5;
const double beamStripeAbove = 3.0;

/// Spot lights thrown from relaying mirrors (the first few cast shadows).
const int beamRelaySpots = 6;
const int beamRelayShadowSpots = 0;
const double beamRelaySpotIntensity = 140;
const double beamRelaySpotInner = 0.1;
const double beamRelaySpotOuter = 0.3;
const double beamRelaySpotReachPad = 6;

/// Warm splash lights where a run ends on a cliff or a rock.
const int beamSplashLights = 6;
const double beamSplashIntensity = 6;
const double beamSplashRange = 5;
const double beamSplashBack = 0.6;
const double beamSplashHeight = 1.0;

// Signal braziers.
/// Thrown light passing this close (and at about its height) kindles one.
const double brazierCatchRadius = 1.1;
const double brazierCatchBelow = 0.5;
const double brazierCatchAbove = 3.5;
const double brazierKindleSeconds = 0.6;

/// A lit brazier's pool of light, its scorching core, and its gift to the
/// Flame.
const double brazierLightRadius = 7;
const double brazierLightCentre = 1.8;
const double brazierLightEdge = 0.6;
const double brazierBurnRadius = 2.2;
const double brazierFlameGift = 4;

/// The fire bowl sits this high on its stand; its light.
const double brazierBowlHeight = 1.25;

/// A lit brazier's flame sheets (times 2 m by 2.4 m).
const double brazierFlameScale = 0.55;
const double brazierLightIntensity = 16;
const double brazierLightRange = 11;

// Lamp posts.
const double lampLightRadius = 5;
const double lampLightCentre = 1.0;
const double lampLightEdge = 0.4;

// The lantern (§5.4).
const double lanternWideRange = 7;
const double lanternWideAngleDeg = 70;
const double lanternWideIntensity = 1.0;
const double lanternFocusRange = 10;
const double lanternFocusAngleDeg = 22;
const double lanternFocusIntensity = 3.0;

/// The lantern sits slightly ahead of the keeper's feet.
const double lanternConeOffset = 0.3;

// Burning oil (Smash).
const double burnLightIntensity = 1.0;

// Damage from light, per second (§5.4, §5.5, §5.8).
const double lightHurtThreshold = 0.8;
const double lightWideDps = 6;
const double lightFocusDps = 30;
const double lightBeamDps = 15;
const double lightBurnDps = 8;
const double hotWickMultiplier = 1.5;
const double sunfireMultiplier = 1.5;
