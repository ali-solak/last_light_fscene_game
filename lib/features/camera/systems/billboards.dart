part of '../camera.dart';

void installBillboards(GameBuilder game) {
  game.addSystem(
    Schedules.renderSync,
    _faceCamera,
    reads: {Billboard, NodeRef, CameraView},
    after: [_placeCamera],
    runIf: hasResource<Scene>(),
  );
}

/// Render sync: world labels turn about Y to face the eye (a quad facing
/// +Z reads mirrored from behind otherwise).
void _faceCamera(World world) {
  final view = world.query<CameraView>().firstOrNull?.$2;
  if (view == null) return;
  final eye = view.node.globalTransform.getTranslation();
  world.query<NodeRef>().having<Billboard>().each((_, ref) {
    final node = ref.node;
    if (!node.visible) return;
    final p = node.globalTransform.getTranslation();
    node.rotation = Quaternion.axisAngle(
      Vector3(0, 1, 0),
      math.atan2(eye.x - p.x, eye.z - p.z),
    );
  });
}
