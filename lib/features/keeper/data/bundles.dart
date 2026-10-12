part of '../keeper.dart';

/// The keeper's gameplay body. The lantern and harpoon features add their
/// own components when a [Keeper] appears.
List<Object> keeperBundle(Vector3 at) => [
  const Keeper(),
  KeeperBody(),
  KeeperBrain(),
  Hearts(),
  SceneTransform.fromVector(at),
];
