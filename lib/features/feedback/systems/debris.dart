part of '../feedback.dart';

void installDebris(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _spawnDebris,
      reads: {SceneTransform, CrabModel},
      inSet: GameSets.feedback,
      runIf: _visual.and(
        hasEvents<ShellCracked>().or(hasEvents<BossPhase>()),
      ),
    )
    ..addSystem(
      Schedules.update,
      _ageDebris,
      writes: {Fleeting, NodeRef},
      inSet: GameSets.feedback,
      after: [_spawnDebris, _puffs],
      runIf: hasResource<Scene>(),
    );
}

/// Tar shards fly off a cracked shell; boat-shell pieces break off the
/// Tide Mother. Both are short-lived dynamic bodies.
void _spawnDebris(World world) {
  final lib = world.resource<ModelLibrary>();
  final physics = world.hasResource<PhysicsWorld>();
  final rng = math.Random();

  void fling(Node node, Vector3 at, double speed, double seconds) {
    final a = rng.nextDouble() * math.pi * 2;
    final v = Vector3(math.cos(a) * speed, speed * 0.9, math.sin(a) * speed);
    node.position = at;
    setRenderLayer(node, RenderLayers.actors);
    final fleeting = Fleeting(node, seconds);
    if (physics) {
      node
        ..addComponent(RigidBody(mass: 0.3, linearVelocity: v))
        ..addComponent(
          Collider(
            shape: const SphereShape(radius: 0.12),
            collisionLayer: Layers.debris,
            collisionMask: Layers.debrisMask,
          ),
        );
      world.spawn([NodeRef(node), fleeting, const PhysicsDriven()]);
    } else {
      fleeting.velocity.setFrom(v);
      world.spawn([NodeRef(node), fleeting]);
    }
  }

  for (final crack in world.events<ShellCracked>()) {
    final t = world.tryGet<SceneTransform>(crack.entity);
    if (t == null || !lib.has('tar_splat')) continue;
    final at = Vector3(t.x, t.y + 0.5, t.z);
    for (var i = 0; i < feedbackTarShards; i++) {
      final shard = lib.instance('tar_splat')
        ..scale = Vector3.all(feedbackShardScale);
      fling(shard, at, feedbackShardSpeed, feedbackShardSeconds);
    }
    _wordPop(world, 'CRACK', at);
  }

  for (final phase in world.events<BossPhase>()) {
    final model = world.tryGet<CrabModel>(phase.boss);
    final piece = model?.parts['boat_shell_${phase.phase}'];
    if (piece == null) continue;
    final copy = piece.clone()..localTransform = piece.globalTransform;
    piece.visible = false;
    fling(copy, copy.position, feedbackShardSpeed * 0.8,
        feedbackShellPieceSeconds);
  }
}

/// Fleeting visuals age out; the ones without physics fall by hand.
void _ageDebris(World world) {
  final dt = world.delta;
  world.query2<Fleeting, NodeRef>().each((entity, f, ref) {
    f.age += dt;
    if (!world.has<PhysicsDriven>(entity)) {
      f.velocity.y -= 9.81 * dt;
      if (f.rise != 0) f.velocity.y = f.rise;
      ref.node.position = ref.node.position + f.velocity * dt;
    }
    if (f.age >= f.seconds) world.despawn(entity);
  });
}
