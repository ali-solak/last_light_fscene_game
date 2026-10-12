part of '../viewmodel.dart';

/// The hands' nodes and their pose state.
final class Hands(
  final Node gun,
  final Node lamp,
  final Node? gunMuzzle,
  final Sprite? halo,
  final PreprocessedMaterial? glass,
) {
  /// Poses, 0 .. 1: the gun aimed, the lamp raised, the gun dipped for the
  /// reload, the lamp gone (thrown).
  final aim = GameTween.number(0, 0, handAimSeconds, curve: Curves.easeOutCubic);
  final raise =
      GameTween.number(0, 0, handRaiseSeconds, curve: Curves.easeOutBack);
  final reload =
      GameTween.number(0, 0, handReloadSeconds, curve: Curves.easeOutCubic);
  final gone = GameTween.number(0, 0, handGoneSeconds, curve: Curves.easeOutCubic);

  /// 0 burning .. 1 the lamp dry and smouldering.
  final dry = GameTween.number(0, 0, handDrySeconds, curve: Curves.easeOutCubic);

  List<GameTween<double>> get poses => [aim, raise, reload, gone, dry];

  /// How far the hands trail the view (eye-frame metres), and the shot's
  /// kick (1 just fired, settling to 0).
  final Vector2 sway = Vector2.zero();
  double kick = 0;

  /// Last frame's view, to measure the turn.
  double lastYaw = 0, lastPitch = 0;
  double time = 0;
}

extension on GameTween<double> {
  /// Heads for [goal] from wherever it is now, unless already going there.
  void ease(double goal) {
    if (to != goal) retarget(goal);
  }
}

/// The eye's frame (right, up, forward), for placing things in view space.
final class _Eye(final CameraRig rig) {
  late final Vector3 forward = rig.look.normalized();
  late final Vector3 right = rig.right.normalized();
  late final Vector3 up = forward.cross(right)..normalize();

  /// [world] (a direction) in eye-frame coordinates.
  Vector3 local(Vector3 world) =>
      Vector3(world.dot(right), world.dot(up), world.dot(forward));

  /// A transform at [local] in front of the eye, turned by [pitch] and
  /// [roll], at [scale]. Props face local -Z after import, so -Z looks
  /// along the view.
  Matrix4 pose(
    Vector3 local, {
    double pitch = 0,
    double roll = 0,
    required double scale,
  }) {
    final at = rig.position + right * local.x + up * local.y + forward * local.z;
    return Matrix4.columns(
          Vector4(right.x, right.y, right.z, 0),
          Vector4(up.x, up.y, up.z, 0),
          Vector4(-forward.x, -forward.y, -forward.z, 0),
          Vector4(at.x, at.y, at.z, 1),
        ) *
        (Matrix4.rotationX(pitch)..rotateZ(roll)) *
        Matrix4.diagonal3Values(scale, scale, scale);
  }
}
