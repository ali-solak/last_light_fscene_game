part of '../boons.dart';

// Every boon that is a component sits on the keeper as a tag; the systems
// that care check `world.entitiesWith<…>()`.

// Ember.
final class const HotWick() implements Tag;

final class const Kindling() implements Tag;

final class const Smash() implements Tag;

final class const Flashpoint() implements Tag;

// Tide.
final class const Barbed() implements Tag;

final class const WhalersReel() implements Tag;

final class const Undertow() implements Tag;

final class const Riptide() implements Tag;

// Salt.
final class const BrineLight() implements Tag;

final class const SaltedWicks() implements Tag;

final class const Preserves() implements Tag;

final class const SaltRing() implements Tag;

// Duos.
final class const Sunfire() implements Tag;

final class const BrineWave() implements Tag;

/// Whiplash: the reeled chain lashes the crabs it sweeps through.
final class const Whiplash() implements Tag;

/// Triple Bolt: each shot fans two darts out beside the bolt.
final class const TripleBolt() implements Tag;

/// Flare: letting a held focus go flares the lamp.
final class const Flare() implements Tag;
