part of '../viewmodel.dart';

/// Poses in the eye's frame (metres: right, up, forward). The gun held low
/// right; aimed, brought to the centre under the eye; reloading, dipped.
/// The lamp held low left by its handle; focusing, raised forward; thrown,
/// gone below the view.
final Vector3 handGunRest = Vector3(0.17, -0.15, 0.52);
final Vector3 handGunAim = Vector3(0.0, -0.105, 0.42);
final Vector3 handGunReload = Vector3(0.15, -0.32, 0.42);
final Vector3 handLampRest = Vector3(-0.21, -0.12, 0.45);
final Vector3 handLampRaised = Vector3(-0.13, -0.05, 0.52);
final Vector3 handLampGone = Vector3(-0.3, -0.6, 0.3);

/// The hands are drawn smaller than the third-person props, so they sit
/// close without clipping the near plane.
const double handGunScale = 0.36;
const double handLampScale = 0.5;

/// The lamp glass's glow up close: warm and alive, just under the bloom
/// threshold so it looms without glaring.
const double handLampGlow = 0.7;

/// A soft halo of lit air round the glass (metres across, peak alpha,
/// flicker).
const double handHaloSize = 0.75;
const double handHaloAlpha = 0.26;
const double handHaloFlicker = 0.15;

/// Dry, the lamp in hand smoulders so it reads at a glance: the glass a
/// deep ember that breathes, the halo red and stronger. How fast it turns.
const double handDrySeconds = 0.25;
const double handLampDryGlow = 0.9;
const double handHaloDryAlpha = 0.42;

/// Tween times for the pose changes.
const double handAimSeconds = 0.16;
const double handRaiseSeconds = 0.22;
const double handReloadSeconds = 0.25;
const double handGoneSeconds = 0.2;

/// Sway: how far the hands lag the mouse (metres per radian of turn), the
/// most they lag, and how fast they settle.
const double handSway = 0.6;
const double handSwayMax = 0.06;
const double handSwayHalfLife = 0.06;

/// The shot's kick: back and up, springing home.
const double handKickBack = 0.09;
const double handKickPitch = 0.35;
const double handKickHalfLife = 0.07;

/// How much of the head bob the hands take (more side sway than the eye).
const double handBob = 1.6;

/// The lamp swung as a club: how far it sweeps (eye frame: across to the
/// right, up a little, out), and how far it tilts in and rolls over.
final Vector3 handLampSwing = Vector3(0.3, 0.07, 0.22);
const double handLampSwingPitch = 0.7;
const double handLampSwingRoll = 1.1;
