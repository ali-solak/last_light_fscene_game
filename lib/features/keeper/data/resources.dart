part of '../keeper.dart';

/// The close-call slow motion: held on wall time, then eased back to 1.
final class SlowMotion {
  double hold = 0;
  GameTween<double>? recover;
}
