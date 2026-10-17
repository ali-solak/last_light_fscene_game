part of '../crabs.dart';

/// Per-type stats (§5.8). [width] is the model's width in metres and
/// [scale] how much bigger the crab is drawn (and collides) than authored.
final class const CrabStats(
  final double hp,
  final double speed,
  final double width,
  final String asset, {
  final double scale = 1,
}) {
  double get size => width * scale;
}

const Map<CrabType, CrabStats> crabStats = {
  .scuttler: CrabStats(18, 3.4, 0.42, 'scuttler', scale: 2.9),
  .tarback: CrabStats(65, 1.5, 1.24, 'tarback', scale: 2.1),
  .snuffer: CrabStats(30, 2.2, 0.6, 'snuffer', scale: 2.6),
  .basher: CrabStats(90, 1.4, 1.2, 'basher', scale: 2.2),
  .burrower: CrabStats(38, 2.0, 0.88, 'burrower', scale: 2.1),
  .mothCrab: CrabStats(20, 3.0, 0.5, 'moth_crab', scale: 2.5),
  .glassback: CrabStats(70, 1.7, 1.0, 'glassback', scale: 2.1),
  .tideMother: CrabStats(1300, 0.9, 6.0, 'tide_mother', scale: 1.7),
};

// Landing.
const double crabLandSeconds = 1.0;
const double crabLandDepth = 1.0;

// Navigation.
const double crabFlowCostSlope = 3;

/// On the trails the going is this much cheaper, so the horde marches up
/// the sand roads where the keeper can see it coming.
const double crabFlowCostRoad = 0.35;
const double crabFlowCostLight = 30;
const double crabFlowCostBeam = 200;
const double crabFlowTargetRadius = 4.5;
const double crabSteerResponse = 8;
const double crabSeparation = 0.6;

/// Steering forces (the kit's seek, separation, alignment and cohesion):
/// how hard a crab turns, and how much the horde shoves apart, moves as
/// one and packs together.
const double crabSteerForce = 14;
const double crabSeparationWeight = 1.3;
const double crabAlignmentWeight = 0.8;
const double crabCohesionWeight = 0.45;

/// A crab heeds the crabs this close (m), at most this many of them.
const double crabNeighbourRadius = 4;
const int crabNeighbourMax = 24;

/// The hurricane: closing on its quarry (the keeper, a target, or the
/// lighthouse base), the horde wheels round it, all one way, strongest
/// between these distances (m), so it circles and spirals in rather than
/// marching straight.
const double crabSwirl = 0.7;
const double crabSwirlNear = 1.5;
const double crabSwirlFar = 12;

/// A crab checks this far (m) along its wheeling way for a beam first.
const double crabSwirlLookAhead = 2;

/// Only the beams kill by light (the lighthouse's and the lantern's focus).
/// In the lantern's glow, a lamp's or a brazier's light a crab moves at
/// this fraction of its speed.
const double crabLightSlow = 0.55;

/// A crab that sees the keeper close by (and is not blinded by light)
/// leaves the flow and hunts him, faster; a hunter (scuttlers) from much
/// further, faster still, light or no light.
const double crabAggroRadius = 7;
const double crabHuntSpeed = 1.25;
const double crabHunterAggroRadius = 30;
const double crabHunterSpeed = 1.5;

/// A hunter this close to the keeper (m) leaps at him: through the air for
/// this long, this high at the top, landing ready to bite; then again
/// after a cooldown between these (s).
const double crabLeapMin = 2.0;
const double crabLeapMax = 8;
const double crabLeapSeconds = 0.42;
const double crabLeapHeight = 1.0;
const double crabLeapCooldownMin = 1.6;
const double crabLeapCooldownMax = 3.2;

/// A hunter caught in a beam (the lighthouse's or the lantern's focus)
/// pushes on at this fraction of its speed.
const double crabBeamSlow = 0.4;

/// The attack's pounce, sprung just before the claw lands.
const double crabLungeSpeed = 7;
const double crabLungeLead = 0.14;

/// A crab making under this share of its speed for this long sidesteps
/// (ignoring the crowd) for a moment, alternating sides.
const double crabStuckShare = 0.25;
const double crabStuckSeconds = 0.7;
const double crabSidestepSeconds = 0.6;
const double crabSidestepAngle = 0.9;

/// Moving but getting no nearer along the flow for this long also counts
/// as stuck (circling a corner).
const double crabNoProgressSeconds = 2.5;

// Defenses: salt slows and stings a crab on it; a crab blocked by a
// barricade chews it (bashers far harder), one bite per attack.
const double crabSaltSlow = 0.45;
const double crabSaltDps = 6;
const double crabChewBite = 8;
const double crabBasherChew = 3;
const double crabChewCooldown = 0.9;
const double crabTurnRate = 10;

/// How long the wanted heading takes to swing halfway to a new way, and
/// how much smaller (radians) the other side's turn must be before a crab
/// switches which side it scuttles on.
const double crabHeadingHalfLife = 0.22;
const double crabSideHysteresis = 0.6;

/// Burrowers tunnel at this speed and surface this close to the lighthouse.
const double crabBurrowSpeed = 3.0;
const double crabBurrowSurfaceRadius = 6;

// Light response.
const double crabCowerThreshold = 0.8;
const double crabSnufferCowerThreshold = 1.4;
const double crabCowerRelease = 0.3;
const double crabBrineSlow = 0.7;
const double crabRiptidePush = 1.0;

// Climbing (§5.8): the tower wall sits at the lighthouse radius.
const double crabClimbStartRadius = 4.0;
const double crabClimbWallRadius = 3.5;
const double crabClimbSpeed = 0.8;
const double crabGalleryHeight = 13;
const double crabSaltRingSeconds = 10;

// Attacking.
const double crabAttackReachFactor = 1.1;
const double crabKeeperRadius = 0.35;
const double crabAttackStillInRange = 1.4;
const double crabAttackCooldown = 0.5;

// Specials.
const double crabSnufferSeek = 14;
const double crabSpitRange = 4;
const double crabBasherSeek = 18;
const double crabSlamReach = 1.6;
const double crabBasherSlamDamage = 1.2;
const double crabBasherSlamRadius = 2.0;
const double crabMothSeek = 12;
const double crabMothExplodeReach = 0.8;
const double crabMothBlastRadius = 1.6;
const double crabMothFlutterRange = 3;

// Dodge reactions (boons).
const double crabFlashRadius = 3;
const double crabFlashSeconds = 1;
const double crabUndertowRadius = 2.5;
const double crabUndertowDistance = 2;
const double crabKnockSeconds = 0.3;
const double crabKnockDaze = 0.6;
const double crabBrineWaveSeconds = 2;

// A flare (the Flare boon): its cone, its burn, the daze and the shove.
const double crabFlareRange = 7;
const double crabFlareHalfAngle = 0.45;
const double crabFlareDamage = 35;
const double crabFlareDazzle = 1.5;
const double crabFlarePush = 1.2;
const double crabSlowFactor = 0.5;

// Damage.
const double crabKindlingSeconds = 3;
const double crabBurnDps = 4;
const double crabShellCrackSeconds = 1.5;
const double crabHitStagger = 0.3;

// Death: the corpse lingers this long after the Death clip (tumble, rest,
// sink), then the entity despawns and the model returns to the pool.
const double crabCorpseSeconds = 4.0;
const double crabDecalSeconds = 12;

// The Tide Mother.
const List<double> tideMotherPhaseAt = [0.67, 0.34, 0.05];
const double tideMotherSlamDamage = 4;
const double tideMotherSlamTopple = 6;
const int tideMotherBrood = 6;
const double tideMotherBroodPortBack = 1.53;
const double tideMotherLighthouseStop = 7;

/// Swarmlings: the horde types, alive at most this many at once (no more
/// than their pool), whose bites only nibble (keeperNibblesPerHeart).
const Set<CrabType> crabHordeTypes = {.scuttler};
const int crabHordeCap = 120;

// The pool, pre-warmed at boot (§4).
const Map<CrabType, int> crabPoolSizes = {
  .scuttler: crabHordeCap,
  .tarback: 8,
  .snuffer: 10,
  .basher: 6,
  .burrower: 10,
  .mothCrab: 12,
  .glassback: 6,
  .tideMother: 1,
};

// The brine shroud (Alan Wake's darkness shield): seconds of focused lamp
// to burn through, per type. Tar shells, moths and the Tide Mother's
// boat shell have their own answers and no shroud.
const Map<CrabType, double> crabShroudSeconds = {
  .scuttler: 0.35,
  .snuffer: 0.6,
  .basher: 1.1,
  .burrower: 0.6,
  .glassback: 0.9,
};

/// Burn rates (shroud seconds per second): the focused lamp, the beam, and
/// the wide glow (times the light's intensity).
const double crabShroudFocusBurn = 1;
const double crabShroudBeamBurn = 1.4;
const double crabShroudGlowBurn = 0.12;

/// Out of the light the shroud regrows, as a fraction of max per second.
const double crabShroudRegrow = 0.35;

/// Exposed: how long the harpoon bites deep, and how long the flash
/// staggers it.
const double crabExposedSeconds = 3;
const double crabExposedStagger = 0.8;

/// Harpoon damage against a shrouded and an exposed crab.
const double harpoonShroudedFactor = 0.4;
const double harpoonExposedFactor = 1.6;

/// Outline colours (linear RGBA): the shroud burning, the crab exposed.
final Vector4 crabOutlineBurning = Vector4(1.0, 0.38, 0.08, 0.55);
final Vector4 crabOutlineExposed = Vector4(1.0, 0.95, 0.8, 1.0);

// The swung lamp (`LampBashed`): its reach and half-arc, the knock (m),
// the hit (times this when the crab is already exposed), how long it
// burns, and how much shroud (seconds of focus) one strike knocks away.
const double crabBashRange = 2.3;
const double crabBashHalfAngle = 1.0;
const double crabBashShove = 2.2;
const double crabBashDamage = 5;
const double crabBashExposedFactor = 5;
const double crabBashBurnSeconds = 2.5;
const double crabBashShroud = 0.4;
