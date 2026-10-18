part of '../feedback.dart';

void installPuffs(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _rackPuffsAndWords,
      reads: const {},
      runIf: _visual,
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
  final rack = world.tryResource<Puffs>()?.rack;
  for (final snuffed in world.events<LampSnuffed>()) {
    final t = world.tryGet<SceneTransform>(snuffed.lamp);
    final puff = t == null ? null : rack?.take();
    if (puff == null) continue;
    puff.position = Vector3(t!.x, t.y + 2.2, t.z);
    world.spawn([
      NodeRef(puff),
      Pooled(rack!, puff),
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

/// A floating word over the world: it rises and is gone.
void _wordPop(World world, String text, Vector3 at) {
  final pops = world.tryResource<WordPops>();
  final node = pops?.rack.take();
  if (node == null) return;
  pops!.texts[node]?.value = text;
  node.position = at;
  world.spawn([
    NodeRef(node),
    Pooled(pops.rack, node),
    const Billboard(),
    Fleeting(node, feedbackWordSeconds)..rise = feedbackWordRise,
  ]);
}

/// Startup, visual: the flame-card puffs and the word quads, built once.
void _rackPuffsAndWords(World world) {
  final lib = world.resource<ModelLibrary>();
  if (lib.has('flame_card')) {
    world.insert(Puffs(mountRack(world, 'puffs', () {
      final puff = lib.instance('flame_card')..scale = Vector3.all(1.4);
      setRenderLayer(puff, RenderLayers.actors);
      return puff;
    }, size: feedbackPuffPool)));
  }
  final texts = <Node, ValueNotifier<String>>{};
  final rack = mountRack(world, 'words', () {
    final text = ValueNotifier('');
    final node = Node(name: 'word')
      ..layers = RenderLayers.actors
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
    texts[node] = text;
    return node;
  }, size: feedbackWordPool);
  world.insert(WordPops(rack, texts));
}
