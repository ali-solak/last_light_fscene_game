part of '../light.dart';

/// What light an entity stands in, sampled every fixed step. Crab systems
/// read this and nothing else, so light rules stay in the light feature.
final class LightExposure {
  double intensity = 0;
  int flags = 0;

  /// Seconds continuously in any light.
  double seconds = 0;

  /// Seconds continuously in the focused lantern (tar shells crack at 1.5).
  double focusSeconds = 0;

  /// Damage per second from lantern, lamp and burning oil.
  double dps = 0;

  /// Damage per second from the beam (glassbacks are immune to this part).
  double beamDps = 0;

  bool get beam => flags & LightFlags.beam != 0;
  bool get focus => flags & LightFlags.focus != 0;
  bool get lit => intensity > 0;

  @override
  String toString() =>
      'light ${intensity.toStringAsFixed(1)}${beam ? ' beam' : ''}';
}

/// A signal brazier on its stone stand. Only light thrown by a mirror (not
/// the lighthouse's own sweep) is focused enough to kindle it; once lit it
/// burns the rest of the night, a big pool of light the horde must go
/// round, scorching crabs that come close. At dawn, [reachable] previews
/// whether the mirrors as set would reach it.
final class Brazier {
  bool lit = false;
  double charge = 0;
  bool reachable = false;

  /// Thrown light is on it this step.
  bool touched = false;

  @override
  String toString() => lit ? 'brazier lit' : 'brazier ${charge.toStringAsFixed(1)}';
}

/// A brazier's model, fire and light.
final class BrazierVisual(
  final Node coals,
  final PointLight light,
  final PhysicallyBasedMaterial coalMaterial,
  final InstancedMesh? flames,
) {
  double time = 0;
  double heat = 0;
  double fire = 0;
  double fireDebt = 0;
}

/// One segment's visuals: the shaft of lit air and the light it paints on
/// the ground.
final class BeamSlot(
  final Node shaft,
  final PreprocessedMaterial? shaftMaterial,
  final DecalNode? stripe,
  final PreprocessedMaterial? stripeMaterial,
) {
  void hide() {
    shaft.visible = false;
    stripe?.visible = false;
  }
}

/// A spot light thrown from a relaying mirror.
final class BeamSpot(final SpotLight light) {
  late final Node node = Node(name: 'beam_spot')
    ..visible = false
    ..addComponent(SpotLightComponent(light));
}

/// The beam's visible pieces: a slot per traced segment, the relay spot
/// lights, and splash lights where a run ends on a blocker.
final class BeamVisual(
  final List<BeamSlot> slots,
  final List<BeamSpot> relays,
  final List<(Node, PointLight)> splashes,
);

/// Light a mirror caught from the beam. It keeps throwing it for
/// [mirrorHoldSeconds] after the sweep has passed (fading over the last
/// [mirrorFadeSeconds]), so a mirror is a relay the player aims, not a
/// flicker as the beam goes by.
final class CaughtLight {
  /// The direction the light arrived along.
  double inX = 0, inZ = 0;
  double intensity = 0;
  int depth = 0;
  double hold = 0;

  /// Struck by a traced beam this step (not relaying on its own).
  bool live = false;

  double get fade => (hold / mirrorFadeSeconds).clamp(0.0, 1.0);

  /// What the mirror throws now.
  double get strength => intensity * (1 - beamBounceLoss) * fade;
  bool get lit => hold > 0 && strength >= beamRelayMinIntensity;

  /// A beam arriving along (dx, dz) strikes the mirror.
  void take(double dx, double dz, double intensity, int depth, double hold) {
    inX = dx;
    inZ = dz;
    this.intensity = intensity;
    this.depth = depth;
    this.hold = hold;
    live = true;
  }

  @override
  String toString() => 'caught ${hold.toStringAsFixed(1)} s';
}
