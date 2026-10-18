part of '../feedback.dart';

// Hitstop (seconds of frozen wall time) and camera trauma per event.
const double feedbackHarpoonFreeze = 0.05;
const double feedbackShotTrauma = 0.3;
const double feedbackShotKick = 0.07;
const double feedbackLandTrauma = 0.25;
const double feedbackBlastTrauma = 0.7;
const double feedbackBlastFreeze = 0.07;
const double feedbackHarpoonTrauma = 0.25;
const double feedbackCrackFreeze = 0.08;
const double feedbackCrackTrauma = 0.4;
/// A lost heart: a hard shake and kick, a beat of hitstop, his pose held.
/// A nibble: a jolt.
const double feedbackKeeperTrauma = 0.75;
const double feedbackKeeperKick = 0.09;
const double feedbackKeeperFreeze = 0.09;
const double feedbackKeeperHitPause = 0.08;
const double feedbackNibbleTrauma = 0.22;
const double feedbackNibbleKick = 0.04;
const double feedbackBossFreeze = 0.12;
const double feedbackBossTrauma = 0.8;
const double feedbackSlamTrauma = 0.35;

/// Never more than one freeze per this many seconds.
const double feedbackFreezeGuard = 0.15;

/// Kills closer together than this build a streak.
const double feedbackStreakWindow = 1.5;

// Corpses (§5.0): tumble, rest, then dissolve while sinking.
const int feedbackDebrisCap = 40;
const double feedbackCorpseImpulse = 2.2;
const double feedbackCorpseSpin = 6;
const double feedbackCorpseMass = 0.6;
const double feedbackDissolveSeconds = 1.5;

/// Seconds a corpse rests before it starts to dissolve.
const double feedbackCorpseRest = 2.5;

// Tar shards and boat-shell pieces.
const int feedbackTarShards = 5;
const double feedbackShardSpeed = 4;
const double feedbackShardSeconds = 3;
const double feedbackShardScale = 0.25;
const double feedbackShellPieceSeconds = 12;

// Puffs and word pops.
const double feedbackPuffSeconds = 1.0;
const double feedbackWordSeconds = 0.8;
const int feedbackWordPool = 4;
const int feedbackPuffPool = 6;

/// Words rise this fast (m/s).
const double feedbackWordRise = 1.2;

/// A lamp strike: hit-stop (longer on an exposed crab), trauma, kick.
const double feedbackBashFreeze = 0.04;
const double feedbackBashExposedFreeze = 0.08;
const double feedbackBashTrauma = 0.22;
const double feedbackBashKick = 0.03;
