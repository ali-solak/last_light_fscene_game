part of '../island.dart';

/// A signal brazier's stone stand, from `mirror_pedestal_1..8` in the
/// island document. The light feature kindles it with thrown light.
final class const BrazierStand(final int index);

/// Static set dressing; never queried by gameplay.
final class const Scenery() implements Tag;

/// A loose physics prop (crate, barrel, driftwood, buoy).
final class const LooseProp() implements Tag;
