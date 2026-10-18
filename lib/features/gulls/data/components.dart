part of '../gulls.dart';

enum GullMode { flying, landed, fleeing }

/// One gull: where it means to land, and how it is moving.
final class Gull(final Vector3 landing) {
  final Machine<GullMode> mode = Machine(.flying);
  final Vector3 velocity = Vector3.zero();

  @override
  String toString() => mode.toString();
}

/// The flock's birds, built once.
final class GullRack(final NodeRack rack);

/// A gull model's moving parts: the body (it pecks) and the wing pivots.
final class GullParts(final Node body, final Node left, final Node right) {
  double time = 0;
}
