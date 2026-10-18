part of '../feedback.dart';

/// The hitstop guard and the kill streak.
final class FeedbackState {
  double wallTime = 0;
  double lastFreeze = -1;
  double lastKill = -10;
  int streak = 0;

  /// Freezes the clock unless one happened within the guard window.
  void freeze(GameClock clock, double seconds) {
    if (wallTime - lastFreeze < feedbackFreezeGuard) return;
    lastFreeze = wallTime;
    clock.freezeFor(seconds);
  }
}

/// A dead crab's body: tumbling, then dissolving. Restores the shell
/// materials when the crab is released.
final class Corpse(
  final Node node,
  final PreprocessedMaterial? dissolve,
  final Map<MeshPrimitive, Material> original,
  final double dissolveAt,
) {
  double age = 0;

  /// While physics drives [node] (position and rotation only), the crab's
  /// scale rides on this node between it and the model's parts.
  Node? scaled;
}

/// A short-lived visual: a shard, a puff, a word, a broken shell piece.
final class Fleeting(final Node node, final double seconds) {
  double age = 0;
  final Vector3 velocity = Vector3.zero();
  double rise = 0;
}

/// The floating words: a rack of widget quads, and the text each shows.
final class WordPops(
  final NodeRack rack,
  final Map<Node, ValueNotifier<String>> texts,
);

/// The snuffed-lamp puffs: a rack of flame cards.
final class Puffs(final NodeRack rack);
