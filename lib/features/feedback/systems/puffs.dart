part of '../feedback.dart';

void installPuffs(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _spawnWordPops,
      reads: const {},
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.update,
      _ageWordPops,
      reads: const {},
      inSet: GameSets.feedback,
      runIf: hasResource<WordPops>(),
    )
    ..addSystem(
    Schedules.update,
    _puffs,
    reads: {SceneTransform, LampPost, Keeper},
    inSet: GameSets.feedback,
    runIf: _visual.and(
      hasEvents<LampSnuffed>().or(hasEvents<NightCleared>()),
    ),
  );
}

/// Smoke from a snuffed lamp; a word over the world for big moments.
void _puffs(World world) {
  final lib = world.resource<ModelLibrary>();
  for (final snuffed in world.events<LampSnuffed>()) {
    final t = world.tryGet<SceneTransform>(snuffed.lamp);
    if (t == null || !lib.has('flame_card')) continue;
    final puff = lib.instance('flame_card')
      ..position = Vector3(t.x, t.y + 2.2, t.z)
      ..scale = Vector3.all(1.4);
    setRenderLayer(puff, RenderLayers.actors);
    world.spawn([
      NodeRef(puff),
      Fleeting(puff, feedbackPuffSeconds)..rise = 0.9,
    ]);
  }
  for (final cleared in world.events<NightCleared>()) {
    final keeper = world.query<SceneTransform>().having<Keeper>().firstOrNull;
    if (keeper == null) continue;
    final k = keeper.$2;
    _wordPop(world, 'DAWN ${cleared.night}', Vector3(k.x, k.y + 2.6, k.z));
  }
}

/// A floating word over the world, from a pool mounted at startup.
void _wordPop(World world, String text, Vector3 at) {
  final pops = world.tryResource<WordPops>();
  if (pops == null || pops.slots.isEmpty) return;
  final slot = pops.slots[pops.next];
  pops.next = (pops.next + 1) % pops.slots.length;
  slot.text.value = text;
  slot.age = 0;
  slot.node
    ..visible = true
    ..position = at;
}

/// Startup, visual: the word-pop pool.
void _spawnWordPops(World world) {
  final slots = <WordSlot>[];
  for (var i = 0; i < feedbackWordPool; i++) {
    final text = ValueNotifier('');
    final node = Node(name: 'word')
      ..layers = RenderLayers.actors
      ..visible = false
      ..addComponent(
        WidgetComponent(
          child: ValueListenableBuilder<String>(
            valueListenable: text,
            builder: (_, value, _) => WordPop(value),
          ),
          size: const Size(220, 80),
          worldHeight: 0.9,
          pixelRatio: 2,
        ),
      );
    world.spawn([NodeRef(node), const Billboard()]);
    slots.add(WordSlot(node, text));
  }
  world.insert(WordPops(slots));
}

/// Words rise and vanish.
void _ageWordPops(World world) {
  final dt = world.delta;
  for (final slot in world.resource<WordPops>().slots) {
    if (!slot.node.visible) continue;
    slot.age += dt;
    slot.node.position = slot.node.position + Vector3(0, 1.2 * dt, 0);
    if (slot.age >= feedbackWordSeconds) slot.node.visible = false;
  }
}
