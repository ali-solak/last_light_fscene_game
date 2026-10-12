part of '../harpoon.dart';

const double harpoonSpeed = 42;

/// The bolt drops this much (m/s²) as it flies: a slight arc.
const double harpoonDrop = 3.5;

/// Aimed at open ground, the bolt aims this far above the point (where a
/// crab's body would be).
const double harpoonGroundLift = 0.45;

/// Aim assist: a crab or mirror hook this close to the aimed ground point
/// takes the shot.
const double harpoonAimAssist = 1.0;

// The shot shoves the keeper back a step.
const double harpoonKnockback = 3.2;

/// Triple Bolt: the darts' spread, damage, speed and reach.
const double harpoonDartSpread = 0.2;
const double harpoonDartDamage = 9;
const double harpoonDartSpeed = 46;
const double harpoonDartRange = 18;

/// Whiplash: crabs this close to the chain while it reels take this, and
/// are flung this fast.
const double harpoonLashReach = 1.1;
const double harpoonLashDamage = 18;
const double harpoonLashFling = 9;
const double harpoonRange = 20;
const double harpoonDamage = 26;

/// A bolt into the upper shell (eyes, back) hits a weak spot for this much
/// more.
const double harpoonWeakSpot = 1.75;
const int harpoonBarbedPierce = 3;

/// The bolt leaves from this high, this far ahead of the keeper.
const double harpoonMuzzleHeight = 1.2;
const double harpoonMuzzleForward = 0.6;

/// Hit circles: crabs by half their size plus this; a mirror's hook point.
const double harpoonCrabPad = 0.15;
const double harpoonHookRadius = 0.6;

// Reeling.
const double harpoonReelSpeed = 7;
const double harpoonReelRelease = 1.5;
const double harpoonReelSeconds = 1.2;
const double harpoonMirrorReelSeconds = 0.8;
const double harpoonSelfReelSeconds = 1.5;
const double harpoonSelfReelArrive = 1.0;

/// Fallback reload when the clip is missing; normally the reload is the
/// `Ranged_2H_Reload` clip's length.
const double harpoonReloadFallback = 1.2;

/// The chain: point masses on a verlet rope, a link drawn on each
/// segment. Paid out loose while the bolt flies, taut when reeling.
const int harpoonChainPoints = 56;
const double harpoonVisualScale = 4.0;
const double harpoonChainGravity = 22;
const double harpoonChainDamping = 0.985;
const double harpoonChainThickness = 0.05;
const double harpoonChainSlackFlying = 1.22;
const double harpoonChainSlackHooked = 1.08;
const double harpoonChainSlackReeling = 0.98;
const double harpoonChainRetractSeconds = 0.35;

/// The gun kicks back this far and pitches up this much at full recoil.
const double harpoonGunKick = 0.18;
const double harpoonGunPitch = 0.45;
const double harpoonRecoilHalfLife = 0.07;
