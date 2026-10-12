part of '../crabs.dart';

final class const Crab(final CrabType type);

final class Health(final double max) {
  double current = max;

  double get fraction => current / max;

  @override
  String toString() => 'hp ${current.toStringAsFixed(0)}/${max.toInt()}';
}

enum CrabMode {
  landing,
  advancing,
  cowering,
  attacking,
  climbing,
  special,
  hit,
  dying,
}

/// A crab's mode, its current target, and the clip a `special` plays.
final class CrabBrain {
  /// Seconds into the Attack clip when the claw lands (its event).
  double attackAt = 0.3;

  final Machine<CrabMode> mode = Machine(.landing);

  /// A lamp, mirror or the keeper, for the crabs that seek one.
  Entity? target;

  /// Seconds out of the light while cowering.
  double outOfLight = 0;

  /// Seconds until the crab may attack again.
  double cooldown = 0;

  /// The special clip being played, and whether its event has fired.
  String special = '';
  bool specialFired = false;

  @override
  String toString() => '${mode.state.name} ${special.isEmpty ? '' : special}';
}

/// Movement state. Crabs scuttle sideways: the body faces 90° from travel
/// and [scuttleSign] says whether local +X (1) or −X (−1) leads.
final class CrabBody(final double size, final double speed) {
  final Vector3 velocity = Vector3.zero();
  double facing = 0;
  double scuttleSign = 1;

  /// The way it means to go, eased: the flow shifts as lights sweep, and
  /// a mass that snapped to every shift would shimmy left and right.
  final Vector2 heading = Vector2.zero();

  /// A decaying knockback impulse (Undertow, Riptide, Slam), then seconds
  /// of daze before it gathers itself.
  double knockX = 0, knockZ = 0, knockTime = 0;
  double dazed = 0;

  /// Metres up the tower while climbing.
  double climb = 0;

  /// Seconds it has been pushing without getting anywhere, and seconds
  /// left of a sidestep along whatever is in the way.
  double stuck = 0;
  double sidestep = 0;

  /// Seconds until the next bite at a barricade.
  double chew = 0;

  /// The nearest it has got to the tower along the flow (metres of path),
  /// how long since it last got nearer, and which way it last sidestepped.
  double bestFlow = double.infinity;
  double noProgress = 0;
  double sideSign = 1;

  /// The attack's pounce: which way it springs, and whether it has.
  double lungeX = 0, lungeZ = 0;
  bool lunged = false;

  /// Where the last discrete hit came from, for the corpse's tumble.
  double hitFromX = 0, hitFromZ = 0;
}

/// Overrides the cower threshold (snuffers cower less).
final class const CowerThreshold(final double value);

/// A tarback's shell: immune to everything until 1.5 s of focus cracks it.
final class TarShell {
  bool cracked = false;

  /// 0..1 toward cracking; drives `tar.fmat` `crack`.
  double progress = 0;
}

// Behaviour tags, composed per type in the bundles.
final class const FleesLight() implements Tag;

final class const SeeksLight() implements Tag;

final class const SnuffsLamps() implements Tag;

final class const KnocksMirrors() implements Tag;

final class const Burrows() implements Tag;

final class const ReflectsBeam() implements Tag;

final class const Boss() implements Tag;

final class const BroodSpawn() implements Tag;

// Transient state tags.

/// Killed: ignored by every gameplay system until the corpse despawns.
final class const Dead() implements Tag;

/// A burrower tunnelling: immune, ignores light.
final class const Underground() implements Tag;

/// Flashpoint: cowers regardless of light.
final class const Dazzled() implements Tag;

/// The brine shroud the dark wraps a crab in (seconds of focused lamp to
/// burn through). While it holds, the harpoon only glances off.
final class Shroud(final double max) {
  late double value = max;

  /// Light is eating at it this step.
  bool burning = false;

  double get fraction => value / max;
}

/// Burnt bare: the harpoon bites deep. Added with `removeAfter`.
final class const Exposed() implements Tag;

/// Brine Wave: moves at half speed.
final class const Slowed() implements Tag;

/// Kindling: burns after leaving the light.
final class const Burning() implements Tag;

/// Speared by the harpoon; the harpoon moves it.
final class const Hooked() implements Tag;

/// Refreshed while the beam is on the crab (feedback tints it).
final class const HitFlash() implements Tag;

/// The Tide Mother's plan, and which shell pieces she has lost.
final class BossBrain {
  final Routine<BossStep> routine = Routine(tideMotherPlan);
  int phase = 0;
  double advanced = 0;

  /// Set while a shell break interrupts the plan.
  int breaking = -1;
}

/// A tar splat decal left where a crab died.
final class const TarSplat() implements Tag;

/// The pooled model a crab wears; handed back to the pool on removal.
final class CrabModel(
  final CrabType type,
  final Node node,
  final Clips clips,
  final Node? mound,
  final Map<String, Node> parts,
) {
  /// True while a hit pause holds the current clip.
  bool paused = false;

  /// The outline last put on the meshes (0 none, 1 burning, 2 exposed).
  int outline = 0;

  /// Every mesh node under the model (outlines are per node).
  late final List<Node> meshes = [..._meshesUnder(node)];
}

Iterable<Node> _meshesUnder(Node node) sync* {
  if (node.mesh != null) yield node;
  for (final child in node.children) {
    yield* _meshesUnder(child);
  }
}
