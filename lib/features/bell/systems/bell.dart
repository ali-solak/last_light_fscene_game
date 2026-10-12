part of '../bell.dart';

void installBellRinging(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _placeBell,
      reads: const {},
      inSet: GameSets.keeper,
    )
    ..addSystem(
      Schedules.fixedUpdate,
      _ringBell,
      writes: {BellSwing},
      inSet: GameSets.rules,
      runIf: inState(GameStatus.dawnBuild),
    )
    ..addSystem(
      Schedules.update,
      _swingBell,
      writes: {BellModel},
      reads: {Bell, BellSwing},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    );
}

void _placeBell(World world) {
  final anchors = world.tryResource<IslandAnchors>();
  if (anchors == null) return;
  world.spawn([
    const Bell(),
    BellSwing(),
    SceneTransform.fromVector(anchors.bell)..setRotationY(anchors.bellYaw),
    Interactable(
      InteractKind.bell,
      holdSeconds: bellInteractHold,
      range: bellInteractRange,
      verb: PromptVerb.ring,
    ),
  ]);
}

/// Interacting with the bell (or the UI's button) rings it: dusk falls.
void _ringBell(World world) {
  var rung = world.consumeAny<BellRung>();
  for (final e in world.events<Interacted>()) {
    if (e.kind == InteractKind.bell) rung = true;
  }
  world.query<BellSwing>().each((_, swing) {
    swing.time += world.dt;
    if (rung) swing.time = 0;
  });
  if (rung) world.setState(GameStatus.dusk);
}

/// The bell swings on `bell_pivot`, a small code rotation.
void _swingBell(World world) {
  final lib = world.resource<ModelLibrary>();
  world.query<BellSwing>().having<Bell>().each((entity, swing) {
    final model = world.tryGet<BellModel>(entity);
    if (model == null) {
      if (!lib.has('bell')) return;
      final node = lib.instance('bell');
      world
        ..add(entity, NodeRef(node))
        ..add(entity, BellModel(node, lib.find(node, 'bell_pivot')));
      return;
    }
    final fade = math.max(0.0, 1 - swing.time / bellSwingSeconds);
    model.pivot?.rotation = Quaternion.axisAngle(
      Vector3(1, 0, 0),
      math.sin(swing.time * bellSwingHz * math.pi * 2) *
          bellSwingAmplitude *
          fade,
    );
  });
}
