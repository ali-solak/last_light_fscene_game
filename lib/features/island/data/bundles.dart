part of '../island.dart';

List<Object> brazierStandBundle(int index, Vector3 at) => [
  BrazierStand(index),
  SceneTransform.fromVector(at),
];
