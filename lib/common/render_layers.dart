import 'package:flutter_scene/scene.dart';

/// Render layers. Everything renders; the camera boom only collides with
/// [world] (terrain, buildings, rocks), never with actors or effects.
abstract final class RenderLayers {
  static const int world = kRenderLayerDefault;
  static const int actors = 1 << 1;
}

/// Puts [root] and every node under it on [layers] (not inherited).
void setRenderLayer(Node root, int layers) {
  root.layers = layers;
  for (final child in root.children) {
    setRenderLayer(child, layers);
  }
}
