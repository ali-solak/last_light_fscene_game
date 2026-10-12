import 'package:vector_math/vector_math.dart';

/// Buttons the controls write into `ButtonInput<KeeperAction>`.
enum KeeperAction { jump, focus, harpoon, interact, throwLamp, bash, fine }

/// Analog movement, camera-relative, in [-1, 1].
enum KeeperAxis { moveX, moveY }

/// The aim, written by the controls widgets.
///
/// Widgets write the pointer ray ([rayOrigin], [rayDirection]); the island
/// feature intersects it with the `HeightGrid` into [point]. Touch controls
/// may write [point] directly through [setGroundPoint].
final class AimInput {
  final Vector3 rayOrigin = Vector3.zero();
  final Vector3 rayDirection = Vector3(0, -1, 0);

  /// True once a ray has been written and not yet resolved.
  bool rayPending = false;

  /// True once any camera ray has arrived (never headless).
  bool hasRay = false;

  /// The aim on the ground, in world space.
  final Vector3 point = Vector3.zero();

  /// False until the first aim arrives.
  bool valid = false;

  void setRay(Vector3 origin, Vector3 direction) {
    rayOrigin.setFrom(origin);
    rayDirection.setFrom(direction);
    rayPending = true;
    hasRay = true;
  }

  void setGroundPoint(double x, double y, double z) {
    point.setValues(x, y, z);
    valid = true;
    rayPending = false;
  }
}

/// Camera input from the controls: zoom steps and orbit, accumulated until
/// the camera system spends them.
final class CameraInput {
  double zoom = 0;
  double orbit = 0;

  /// Held orbit keys: -1, 0 or 1.
  double orbitRate = 0;

  /// Mouse-look movement this frame, in logical pixels (pointer locked).
  double lookX = 0, lookY = 0;
}

/// What a tap on open ground builds at dawn. Tapping a placed mirror or
/// lamp always works on that piece, whichever tool is chosen.
enum BuildTool { mirror, lamp, salt, barricade }

/// The dawn build's chosen tool.
final class BuildSelection {
  BuildTool tool = .mirror;
}
