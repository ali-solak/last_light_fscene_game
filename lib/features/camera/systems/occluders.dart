part of '../camera.dart';

void installOccluderFade(GameBuilder game) {
  game.addSystem(
    Schedules.renderSync,
    _fadeOccluders,
    writes: {NodeRef},
    reads: {CameraFade},
    after: [_placeCamera, _faceCamera],
    runIf: hasResource<Scene>(),
  );
}

/// Render sync: scenery standing between the camera and the keeper hides,
/// so nothing blocks the view of the fight.
void _fadeOccluders(World world) {
  final rig = world.resource<CameraRig>();
  final status = world.state<GameStatus>();
  final following = status == GameStatus.night || status == GameStatus.dusk;
  final cx = rig.position.x, cz = rig.position.z;
  final tx = rig.target.x, tz = rig.target.z;
  final sight = math.sqrt((tx - cx) * (tx - cx) + (tz - cz) * (tz - cz));
  world.query2<CameraFade, NodeRef>().each((_, fade, ref) {
    var blocks = false;
    if (following) {
      final d = distToSegment(fade.x, fade.z, cx, cz, tx, tz);
      final toTarget = math.sqrt(
        (fade.x - tx) * (fade.x - tx) + (fade.z - tz) * (fade.z - tz),
      );
      blocks =
          d < fade.radius + cameraFadeMargin &&
          toTarget > fade.radius * 0.5 &&
          toTarget < sight + fade.radius;
    }
    ref.node.visible = !blocks;
  });
}
