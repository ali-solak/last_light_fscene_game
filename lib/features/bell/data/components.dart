part of '../bell.dart';

final class const Bell() implements Tag;

/// The ringing swing, decaying over [bellSwingSeconds].
final class BellSwing {
  double time = bellSwingSeconds;
}

final class BellModel(final Node node, final Node? pivot);
