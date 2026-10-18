import 'package:scene_dash_v2/scene_dash_v2.dart' show Entity, GameBuilder;
import 'package:vector_math/vector_math.dart';

import 'interact.dart';

/// The three landing beaches. Spawns 0–1 north, 2–3 east, 4–5 south.
enum Beach { north, east, south }

/// Every crab in the roster.
enum CrabType {
  scuttler,
  tarback,
  snuffer,
  basher,
  burrower,
  mothCrab,
  glassback,
  tideMother,
}

/// Where a point of crab damage came from; immunities key off it.
enum DamageSource { light, beam, harpoon, slam, explosion, burn, bash }

/// What the harpoon bolt struck first.
enum HarpoonTargetKind { crab, mirror, flotsam, prop, ground, miss }

/// The phases of a dawn-build pointer gesture.
enum BuildPhase { tap, dragStart, drag, dragEnd }

// ---------------------------------------------------------------- from UI

final class const GameStarted();

final class const BellRung();

final class const BoonPicked(final String id);

final class const PauseToggled();

final class const RestartRequested();

final class const QuitRequested();

/// One pointer gesture during the dawn build, as a ray from the camera.
/// The island feature resolves it onto the ground as a [BuildAt].
final class BuildPointer(
  final Vector3 origin,
  final Vector3 direction,
  final BuildPhase phase, {
  final bool fine = false,
});

/// A dawn-build gesture resolved onto the ground plane.
final class const BuildAt(
  final double x,
  final double z,
  final BuildPhase phase, {
  final bool fine = false,
});

/// A settings toggle from the settings screen.
final class const SettingChanged(final SettingKey key, final bool value);

enum SettingKey {
  haptics,
  screenShake,
  holdToToggleFocus,
  thirdPerson,
}

// ---------------------------------------------------------------- nights

final class const NightStarted(final int night);

final class const NightCleared(final int night);

final class const WaveLanded(final Beach beach, final int count);

// ---------------------------------------------------------------- crabs

final class const CrabDamaged(
  final Entity entity,
  final double amount,
  final DamageSource source,
);

final class CrabKilled(
  final Entity entity,
  final CrabType type,
  final Vector3 position,
  final Vector3 from,
);

final class const ShellCracked(final Entity entity);

/// The lamp burnt a crab's shroud through: it reels, exposed.
final class const CrabExposed(final Entity entity);

/// A crab's attack connected with the keeper (its clip event, in range). A
/// swarmling's is a [nibble]: enough of them cost a heart.
final class const CrabAttackLanded(
  final Entity crab,
  final int hearts, {
  final bool nibble = false,
});

/// A hunter leapt at the keeper.
final class const CrabLeapt(final Entity crab);

/// A crab's bite got through to the keeper, from ([fromX], [fromZ]); [hurt]
/// when it cost a heart (else a nibble).
final class const KeeperBitten(
  final double fromX,
  final double fromZ,
  final bool hurt,
);

/// An area slam (basher, Tide Mother): hurts within [damageRadius] and
/// topples mirrors and snuffs lamps within [toppleRadius].
final class SlamLanded(
  final Entity source,
  final Vector3 position,
  final double damageRadius,
  final double toppleRadius,
);

/// A basher's slam aimed at one mirror.
final class const MirrorSlammed(final Entity mirror);

/// A snuffer spit or a moth explosion reached one lamp.
final class const LampStruck(final Entity lamp);

final class MothExploded(final Vector3 position);

/// The Tide Mother lost a boat-shell piece (0..2).
final class const BossPhase(final Entity boss, final int phase);

// ---------------------------------------------------------------- rules

final class const FlameDrained(final double amount);

final class const FlameLow();

final class const KeeperHit(final int amount);

final class const KeeperDowned();

final class const KeeperRespawned();

/// The keeper leapt; [closeCall] when a crab was within reach.
final class JumpStarted(final Vector3 position, final bool closeCall);

/// The keeper came down from a jump, [height] metres above where he landed
/// at the top of it.
final class KeeperLanded(final Vector3 position, final double height);

/// The keeper finished an interaction hold on [target].
final class const Interacted(
  final Entity target,
  final InteractKind kind,
  final double aimX,
  final double aimZ,
);

// ---------------------------------------------------------------- harpoon

final class const HarpoonFired();

final class HarpoonHit(
  final HarpoonTargetKind kind,
  final Entity? target,
  final Vector3 point,
);

final class const HarpoonReeled();

// ---------------------------------------------------------------- placeables

final class const LampSnuffed(final Entity lamp);

final class const LampRelit(final Entity lamp);

final class const MirrorToppled(final Entity mirror);

final class const MirrorRaised(final Entity mirror);

final class const MirrorAimed(final Entity mirror);

/// A bolt struck a crab's weak spot (the upper shell).
final class WeakSpotHit(final Entity crab, final Vector3 point);

/// Something flung a crab (a whipping chain): along (dirX, dirZ) at
/// [speed] for a moment.
final class const CrabShoved(
  final Entity crab,
  final double dirX,
  final double dirZ,
  final double speed,
);

/// The keeper swung the lamp: a short arc in front of him from [origin]
/// along (dirX, dirZ). Needs no oil.
final class LampBashed(final Vector3 origin, final double dirX, final double dirZ);

/// The swung lamp struck [crab] at [point], striking sparks (and it was
/// already [exposed]: the hard hit).
final class CrabBashed(final Entity crab, final Vector3 point, final bool exposed);

/// The keeper let a held focus go in a flare: a short, hot cone of light
/// from [origin] along (dirX, dirZ).
final class LampFlare(final Vector3 origin, final double dirX, final double dirZ);

/// A thrown lamp burst where it landed, spilling burning oil over [radius].
final class LampShattered(final Vector3 position, final double radius);

/// A washed-up crate or barrel broke (a barrel: it blew up).
final class WreckBroken(final bool barrel, final Vector3 position);

/// The keeper walked over a spill from a crate: lamp oil, or a heart.
final class PickedUp(final bool heart, final Vector3 position);

/// Hauled flotsam came ashore at [position] (a [barrel], or a crate).
final class FlotsamLanded(final bool barrel, final Vector3 position);

/// A light mote reached the keeper's lamp at [position].
final class MoteGathered(final Vector3 position);

/// Something other than a crab's claw hurt the keeper (a barrel blast).
final class const KeeperStruck(final int hearts);

/// Thrown light kindled a signal brazier.
final class const BrazierLit(final Entity brazier);

// ---------------------------------------------------------------- clips

/// A clip's authored event moment was crossed (clips.json `event_frame_s`).
final class const AnimEvent(
  final Entity entity,
  final String clip,
  final String name,
);

/// Opens every event channel at install, so run conditions like
/// `hasEvents<T>()` can ask before the first emit.
void configureEvents(GameBuilder game) {
  game
    ..configureEvent<GameStarted>()
    ..configureEvent<BellRung>()
    ..configureEvent<BoonPicked>()
    ..configureEvent<PauseToggled>()
    ..configureEvent<RestartRequested>()
    ..configureEvent<QuitRequested>()
    ..configureEvent<BuildPointer>()
    ..configureEvent<BuildAt>()
    ..configureEvent<SettingChanged>()
    ..configureEvent<NightStarted>()
    ..configureEvent<NightCleared>()
    ..configureEvent<WaveLanded>()
    ..configureEvent<CrabDamaged>()
    ..configureEvent<CrabKilled>()
    ..configureEvent<ShellCracked>()
    ..configureEvent<CrabExposed>()
    ..configureEvent<CrabAttackLanded>()
    ..configureEvent<SlamLanded>()
    ..configureEvent<MirrorSlammed>()
    ..configureEvent<LampStruck>()
    ..configureEvent<MothExploded>()
    ..configureEvent<BossPhase>()
    ..configureEvent<FlameDrained>()
    ..configureEvent<FlameLow>()
    ..configureEvent<KeeperHit>()
    ..configureEvent<KeeperBitten>()
    ..configureEvent<CrabLeapt>()
    ..configureEvent<KeeperDowned>()
    ..configureEvent<KeeperRespawned>()
    ..configureEvent<JumpStarted>()
    ..configureEvent<KeeperLanded>()
    ..configureEvent<Interacted>()
    ..configureEvent<HarpoonFired>()
    ..configureEvent<HarpoonHit>()
    ..configureEvent<HarpoonReeled>()
    ..configureEvent<LampSnuffed>()
    ..configureEvent<LampRelit>()
    ..configureEvent<MirrorToppled>()
    ..configureEvent<BrazierLit>()
    ..configureEvent<WreckBroken>()
    ..configureEvent<LampShattered>()
    ..configureEvent<CrabShoved>()
    ..configureEvent<WeakSpotHit>()
    ..configureEvent<LampFlare>()
    ..configureEvent<LampBashed>()
    ..configureEvent<CrabBashed>()
    ..configureEvent<PickedUp>()
    ..configureEvent<MoteGathered>()
    ..configureEvent<FlotsamLanded>()
    ..configureEvent<KeeperStruck>()
    ..configureEvent<MirrorRaised>()
    ..configureEvent<MirrorAimed>()
    ..configureEvent<AnimEvent>();
}
