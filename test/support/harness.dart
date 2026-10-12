import 'dart:io';

import 'package:last_light/assets/glb.dart';
import 'package:last_light/assets/model_library.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/common/states.dart';
import 'package:last_light/features/boons/boons.dart';
import 'package:last_light/features/crabs/crabs.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/keeper/keeper.dart';
import 'package:last_light/features/light/light.dart';
import 'package:last_light/features/nights/nights.dart';
import 'package:last_light/game.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

final IslandAsset islandAsset = IslandAsset(
  GlbDocument.parse(
    File('assets/models/environment/island.glb').readAsBytesSync(),
  ),
);

final ModelLibrary headlessModels = ModelLibrary.headless(
  parseClipBook(File('assets/models/clips.json').readAsStringSync()),
);

/// A headless game with the real island and clip timings, every feature
/// (or [features]), strict access, and a pinned seed. Started.
TestGame makeGame({
  List<Feature>? features,
  List<Feature> probes = const [],
  int seed = 7,
}) => TestGame.headless(
  strictAccess: true,
  features: [
    configureGame(headlessModels, islandAsset, seed: seed),
    ...(features ?? lastLightFeatures),
    ...probes,
  ],
)..start();

extension TestGameFlow on TestGame {
  GameStatus get status => world.state<GameStatus>();

  /// Pumps fixed steps covering [seconds] of game time.
  void seconds(double seconds) =>
      pumpFixed(steps: (seconds / fixedDt).round());

  /// One rendered frame (state transitions, update schedule, events).
  void frame() => pump();

  /// Title → dawn boons → (first offer picked) → build.
  void toDawnBuild() {
    emit(const GameStarted());
    frame();
    frame();
    final offer = world.resource<BoonOffer>().boons;
    if (offer.isNotEmpty) emit(BoonPicked(offer.first.id));
    frame();
    frame();
  }

  /// Ring the bell and let the dusk card run into the night.
  void toNight() {
    emit(const BellRung());
    frame();
    frame();
    seconds(2.6);
    frame();
  }

  /// A night with no plan and no crabs: a clean stage for one rule.
  void quietNight() {
    emit(const GameStarted());
    frame();
    world.setState(GameStatus.night);
    frame();
    world.resource<NightDirector>().routine = null;
    world.query<Crab>().each((e, _) => world.despawn(e));
    frame();
  }

  /// Flat ground at [level] everywhere, walkable.
  void flatGround([double level = 0]) {
    world.insert(HeightGrid.flat(level));
    world.resource<IslandAnchors>().lighthouse.setValues(0, level, 0);
  }

  /// The beam held still at [yaw] from (x, z), with nothing in the way.
  void pinBeam({double yaw = 0, double x = 0, double z = 0, bool on = true}) {
    world.resource<Beam>()
      ..degreesPerSecond = 0
      ..yaw = yaw
      ..centreX = x
      ..centreZ = z
      ..groundY = 0
      ..on = on;
    world.insert(Occluders([]));
  }

  Entity get keeper => world.entitiesWith<Keeper>().firstOrNull!;

  SceneTransform get keeperAt => world.get<SceneTransform>(keeper);

  void placeKeeper(double x, double z) {
    keeperAt.setTranslation(x, world.resource<HeightGrid>().sample(x, z), z);
  }

  /// Aims at the ground at (x, z), as the camera ray would land.
  void aimAt(double x, double z) => world.resource<AimInput>().setGroundPoint(
    x,
    world.tryResource<HeightGrid>()?.sample(x, z) ?? 0,
    z,
  );

  /// Spawns a crab already advancing at (x, z).
  /// A crab of [type] at ([x], [z]), advancing. Bare of its brine shroud
  /// unless [shrouded], so damage tests see raw numbers.
  Entity crab(CrabType type, double x, double z, {bool shrouded = false}) {
    final e = world.spawn(crabBundle(type, Vector3(x, 0, z)));
    if (!shrouded) world.remove<Shroud>(e);
    frame();
    world.get<CrabBrain>(e).mode.go(CrabMode.advancing);
    return e;
  }
}

/// A probe feature: collects every [T] the game emits into [into].
Feature collect<T extends Object>(List<T> into) => (game) => game.addSystem(
  Schedules.update,
  (world) => into.addAll(world.events<T>()),
  reads: const {},
  label: 'collect<$T>',
);
