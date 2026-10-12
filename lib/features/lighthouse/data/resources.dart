part of '../lighthouse.dart';

/// The lighthouse Flame. At 0 the run is lost.
final class Flame {
  double current = flameMax;
  final double max = flameMax;

  /// [FlameLow] fires once per descent below the mark.
  bool lowWarned = false;

  double get fraction => current / max;
}

/// The lighthouse model's moving parts.
final class LighthouseModel(
  final Node lampHead,
  final Node? lens,
  final PointLight light,
  final Node spotNode,
  final SpotLight spot,
) {
  double flicker = 0;
}
