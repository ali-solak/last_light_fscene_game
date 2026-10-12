part of '../camera.dart';

/// The camera's state. The app's `SceneView` builds its camera from it.
final class CameraRig {
  final Vector3 position = Vector3(0, 30, -40);
  final Vector3 target = Vector3.zero();

  /// The horizontal view direction, for camera-relative movement.
  double forwardX = 0, forwardZ = 1;

  /// The title's slow orbit around +Y.
  double orbit = 0;

  /// The player's orbit (yaw around the target) and zoom (× distance).
  double yaw = cameraFollowYaw;
  double yawGoal = cameraFollowYaw;
  double pitch = cameraPitchDeg * degrees2Radians;
  double zoom = 1;

  /// True while the third-person boom owns the camera.
  bool following = false;

  /// 0..1: how far into the harpoon's aim the camera has pulled.
  double aim = 0;

  /// Through the keeper's eyes (the default at night) rather than over his
  /// shoulder.
  bool firstPerson = false;

  /// The view direction in 3D and its right hand, for the viewmodel and
  /// the aim; the head bob offset and the landing dip.
  final Vector3 look = Vector3(0, 0, 1);
  final Vector3 right = Vector3(1, 0, 0);
  final Vector3 bob = Vector3.zero();

  /// Where the first-person gun's muzzle is (the viewmodel writes it).
  final Vector3 muzzle = Vector3.zero();
  double bobPhase = 0;
  double dip = 0;

  /// Which shoulder the camera rides: +1 right, -1 left (holding the lamp
  /// up swings it left, so the lamp and its beam are in view), eased.
  double side = 1;

  /// Radians the boom is tilted up so a hillside behind never swallows
  /// the camera, eased; and more when a wall squeezes the arm short, so
  /// the camera rises over it instead of into his head.
  double lift = 0;
  double squeeze = 0;

  /// 0..1; shake is trauma² × noise. Feedback adds to it.
  double trauma = 0;
  double shakeTime = 0;
  final Vector3 shake = Vector3.zero();

  /// Recoil: radians the view is thrown up, springing back.
  double kick = 0;

  void addTrauma(double amount) => trauma = math.min(1, trauma + amount);

  void addKick(double radians) => kick = math.min(0.3, kick + radians);
}

/// The scene camera: a node carrying a [CameraComponent], placed from the
/// rig every render sync. `SceneView` renders through it, and the controls
/// cast pointer rays with [camera].
final class CameraView(
  final Node node,
  final CameraComponent component,
  final Node boom,
  final SpringArmComponent arm,
) {
  Camera get camera => component.toCamera();
}

/// Hides a big piece of scenery (the tower, the cottage, a boulder) while
/// it stands between the camera and the keeper. [x], [z] is its footprint
/// centre on the ground.
final class CameraFade(final double x, final double z, final double radius);
