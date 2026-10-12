part of '../feedback.dart';

void installCorpses(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _spawnCorpses,
      reads: {Corpse, CrabModel, Dead},
      inSet: GameSets.feedback,
      runIf: _visual.and(hasEvents<CrabKilled>()),
    )
    ..addSystem(
      Schedules.update,
      _dissolveCorpses,
      writes: {Corpse},
      inSet: GameSets.feedback,
      after: [_spawnCorpses],
      runIf: _visual,
    )
    ..observe<Corpse>(onRemove: _restoreCorpse);
}

/// A killed crab's body turns dynamic: an impulse away from the killing
/// blow and a random spin, so it flips and tumbles (debris layer: never
/// trips the keeper). Capped at 40 bodies; past that it just dissolves.
void _spawnCorpses(World world) {
  final materials = world.tryResource<Materials>();
  final lib = world.resource<ModelLibrary>();
  final physics = world.hasResource<PhysicsWorld>();
  final bodies = world.query<Corpse>().count();
  final rng = math.Random();
  for (final killed in world.events<CrabKilled>()) {
    final model = world.tryGet<CrabModel>(killed.entity);
    if (model == null || world.has<Corpse>(killed.entity)) continue;
    final node = model.node;
    Node? scaled;
    if (physics && bodies < feedbackDebrisCap) {
      final away = killed.position - killed.from
        ..y = 0;
      if (away.length2 < 1e-4) away.setValues(rng.nextDouble() - 0.5, 0, 1);
      away
        ..normalize()
        ..scale(feedbackCorpseImpulse)
        ..y = feedbackCorpseImpulse * 0.8;
      final body = RigidBody(
        mass: feedbackCorpseMass,
        linearVelocity: away,
        angularVelocity: Vector3(
          (rng.nextDouble() - 0.5) * feedbackCorpseSpin,
          (rng.nextDouble() - 0.5) * feedbackCorpseSpin,
          (rng.nextDouble() - 0.5) * feedbackCorpseSpin,
        ),
        angularDamping: 0.4,
      );
      // The body sets the node's position and rotation and drops its
      // scale, so the crab's size moves onto a node below it.
      final s = world.tryGet<SceneTransform>(killed.entity)?.scale.x ?? 1;
      final size = node.combinedLocalBounds;
      final radius = size == null
          ? 0.2 * s
          : math.max(0.08, (size.max - size.min).length * 0.3 * s);
      scaled = Node(name: 'corpse_scale')..scale = Vector3.all(s);
      for (final part in node.children.toList()) {
        node.remove(part);
        scaled.add(part);
      }
      node
        ..scale = Vector3.all(1)
        ..add(scaled)
        ..addComponent(body)
        ..addComponent(
          Collider(
            shape: SphereShape(radius: radius),
            collisionLayer: Layers.debris,
            collisionMask: Layers.debrisMask,
          ),
        );
      world.add(killed.entity, const PhysicsDriven());
    }
    final dissolve = materials?.take('dissolve_sink');
    final original = <MeshPrimitive, Material>{};
    _collect(node, original);
    world.add(
      killed.entity,
      Corpse(
        node,
        dissolve,
        original,
        lib.seconds(_asset(model), 'Death') + feedbackCorpseRest,
      )..scaled = scaled,
    );
  }
}

String _asset(CrabModel model) => switch (model.type) {
  CrabType.mothCrab => 'moth_crab',
  CrabType.tideMother => 'tide_mother',
  final type => type.name,
};

void _collect(Node node, Map<MeshPrimitive, Material> into) {
  for (final p in node.mesh?.primitives ?? const <MeshPrimitive>[]) {
    into[p] = p.material;
  }
  for (final child in node.children) {
    _collect(child, into);
  }
}

/// After resting, the corpse dissolves with an ember rim.
void _dissolveCorpses(World world) {
  final dt = world.delta;
  world.query<Corpse>().each((_, corpse) {
    corpse.age += dt;
    final dissolve = corpse.dissolve;
    if (dissolve == null || corpse.age < corpse.dissolveAt) return;
    if (corpse.age - dt < corpse.dissolveAt) {
      for (final p in corpse.original.keys) {
        p.material = dissolve;
      }
    }
    setParam(
      dissolve.parameters,
      'progress',
      ((corpse.age - corpse.dissolveAt) / feedbackDissolveSeconds).clamp(0, 1),
    );
  });
}

/// The crab is gone: give its shell back its materials and its parts back
/// to the model node, for the pool.
void _restoreCorpse(World world, Entity entity, Corpse corpse) {
  if (corpse.scaled case final scaled?) {
    for (final part in scaled.children.toList()) {
      scaled.remove(part);
      corpse.node.add(part);
    }
    corpse.node.remove(scaled);
  }
  for (final MapEntry(key: p, value: m) in corpse.original.entries) {
    p.material = m;
  }
  if (corpse.dissolve case final d?) {
    setParam(d.parameters, 'progress', 0);
    world.tryResource<Materials>()?.give('dissolve_sink', d);
  }
}
