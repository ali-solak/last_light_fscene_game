import 'package:scene_dash_v2/scene_dash_v2.dart';

/// Cross-feature phase order, declared once in `configureGame`.
///
/// fixedUpdate: input → keeper → weapons → lantern → light → navigation →
/// crabs → damage → flotsam → motes → gulls → rules → lamps → nights.
/// update: dress → animation (keeper, crabs, mirrors, lamps) → feedback →
/// camera.
///
/// Spawning and adding components are deferred, so they never conflict;
/// these phases order the systems that mutate the same component types on
/// different entities (every feature's `Clips`, every placeable's
/// `Interactable`).
abstract final class GameSets {
  static const input = SystemSet('fixed.input');
  static const keeper = SystemSet('fixed.keeper');
  static const weapons = SystemSet('fixed.weapons');
  static const lantern = SystemSet('fixed.lantern');
  static const light = SystemSet('fixed.light');
  static const navigation = SystemSet('fixed.navigation');
  static const crabs = SystemSet('fixed.crabs');
  static const damage = SystemSet('fixed.damage');

  /// What the sea and the air carry, each moving its own transforms:
  /// flotsam, light motes, gulls.
  static const flotsam = SystemSet('fixed.flotsam');
  static const motes = SystemSet('fixed.motes');
  static const gulls = SystemSet('fixed.gulls');
  static const rules = SystemSet('fixed.rules');
  static const lamps = SystemSet('fixed.lamps');
  static const nights = SystemSet('fixed.nights');

  /// Visuals put on models (deferred adds only).
  static const dress = SystemSet('update.dress');
  static const animation = SystemSet('update.animation');
  static const crabAnimation = SystemSet('update.animation.crabs');
  static const mirrorAnimation = SystemSet('update.animation.mirrors');
  static const lampAnimation = SystemSet('update.animation.lamps');
  static const feedback = SystemSet('update.feedback');
  static const camera = SystemSet('update.camera');

  static const fixedOrder = [
    input,
    keeper,
    weapons,
    lantern,
    light,
    navigation,
    crabs,
    damage,
    flotsam,
    motes,
    gulls,
    rules,
    lamps,
    nights,
  ];

  static const updateOrder = [
    dress,
    animation,
    crabAnimation,
    mirrorAnimation,
    lampAnimation,
    feedback,
    camera,
  ];
}
