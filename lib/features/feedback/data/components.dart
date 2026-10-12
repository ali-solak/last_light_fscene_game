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

/// One pooled floating word.
final class WordSlot(final Node node, final ValueNotifier<String> text) {
  double age = 0;
}

/// The pooled floating words (mounted once at startup).
final class WordPops(final List<WordSlot> slots) {
  int next = 0;
}
