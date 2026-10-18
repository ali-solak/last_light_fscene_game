part of '../motes.dart';

/// A spark of light shed by a killed crab, drifting until the lamp takes
/// it or it fades.
final class Mote(final Vector3 velocity) {
  double age = 0;
}

/// The mote glows: a rack of small sprites with a trail.
final class MoteRack(final NodeRack rack);
