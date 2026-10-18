import 'package:flutter_scene/kit.dart' show NodePool;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

/// A [NodePool] pre-warmed to its full size, spawning under one [root]
/// mounted once. Taken nodes hang off the root (so a bound [NodeRef] never
/// mounts or unmounts them); idle ones are detached and cost nothing.
final class NodeRack extends NodePool {
  NodeRack(super.factory, this.root, {required int size})
    : super(initialSize: size, maxSize: size);

  final Node root;

  /// An idle node attached under [root], or null when every one is out:
  /// nothing is built during play unless [grow] says a missing visual
  /// would be worse than the hitch.
  Node? take({bool grow = false}) =>
      idleCount == 0 && !grow ? null : spawn(parent: root);
}

/// Builds a rack of [size] nodes from [factory] under a fresh root named
/// [name], and mounts the root.
NodeRack mountRack(
  World world,
  String name,
  Node Function() factory, {
  required int size,
}) {
  final root = Node(name: name);
  world.spawn([NodeRef(root)]);
  return NodeRack(factory, root, size: size);
}

/// A node on loan from [rack]; it goes back when this component leaves
/// its entity, despawn included.
final class Pooled(final NodeRack rack, final Node node);

void installPooled(GameBuilder game) {
  game.observe<Pooled>(onRemove: (_, _, p) => p.rack.despawn(p.node));
}
