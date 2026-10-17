part of '../keeper.dart';

final class const Keeper() implements Tag;

enum KeeperMode {
  idle,
  moving,
  jumping,
  focusing,
  aiming,
  reeling,
  interacting,
  hit,
  downed,
}

/// Velocity and facing (yaw; the model faces −Z at 0).
final class KeeperBody {
  final Vector3 velocity = Vector3.zero();
  double facing = 0;

  /// A jump: height above the ground, vertical speed, the highest point
  /// reached, and how long since he came down (the landing clip).
  double air = 0;
  double rise = 0;
  double apex = 0;
  double sinceLanding = 10;
  double jumpCooldown = 0;

  bool get airborne => air > 0 || rise > 0;
}

/// The keeper's mode, plus what he is interacting with.
final class KeeperBrain {
  final Machine<KeeperMode> mode = Machine(.idle);

  /// The nearest interactable in range (drives the prompt).
  Entity? inReach;

  /// The interactable being worked, and how long it takes.
  Entity? interacting;
  double interactSeconds = 0;

  /// Seconds of post-hit invulnerability left.
  double invulnerable = 0;

  /// Lantern focus latched on (the hold-to-toggle setting).
  bool focusToggled = false;

  bool get iFramed =>
      mode.state == KeeperMode.jumping &&
      mode.elapsed >= keeperIFrameStart &&
      mode.elapsed < keeperIFrameEnd;

  bool get canAct => switch (mode.state) {
    .idle || .moving || .focusing => true,
    _ => false,
  };

  @override
  String toString() => mode.toString();
}

final class Hearts {
  int current = keeperHearts;
  final int max = keeperHearts;

  /// Swarmling nibbles toward the next lost heart.
  int nibbles = 0;
}

/// The floating "E — turn" prompt.
final class InteractPromptView(
  final Node node,
  final ValueNotifier<PromptVerb?> verb,
);

/// The keeper's model and its weapon nodes.
final class KeeperModel(
  final Node node,
  final Node? lamp,
  final Node? gun,
  final Node? flame,
  final PreprocessedMaterial? glass,
) {
  bool paused = false;

  /// True from a respawn until he first leaves idle (plays Spawn_Ground).
  bool respawning = false;

  /// The held stance (aiming, holding the lamp up), kept with hysteresis
  /// so it never flickers between clips at the speed threshold.
  int stance = 0;

  /// Seconds left of lowering the lamp, or of bringing the harpoon down,
  /// after he lets go.
  double lowering = 0;
  double aimingOut = 0;

  /// Drawn as a shadow only (first person), last applied.
  bool shadowOnly = false;
}
