part of '../island.dart';

void installIslandScenery(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _dressIsland,
      reads: const {},
      inSet: GameSets.keeper,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(OnEnter(GameStatus.night), _skyToNight, reads: const {})
    ..addSystem(OnEnter(GameStatus.dawnBoons), _skyToDawn, reads: const {})
    ..addSystem(OnEnter(GameStatus.title), _skyToTitle, reads: const {})
    ..addSystem(
      Schedules.update,
      _tickSky,
      reads: const {},
      inSet: GameSets.feedback,
      runIf: hasResource<Scene>(),
    );
}

/// Startup, visual: the island model and its collider, the anchored
/// buildings, rocks, props, grass, sea, fog planes, sky and lights.
void _dressIsland(World world) {
  final lib = world.resource<ModelLibrary>();
  if (!lib.hasModels) return;
  final scene = world.resource<Scene>();
  final doc = world.resource<IslandAsset>().document;
  final grid = world.resource<HeightGrid>();
  final materials = world.tryResource<Materials>();
  final scenery = world.resource<IslandScenery>();
  final physics = world.hasResource<PhysicsWorld>();

  // The island, with its hidden collision mesh as a fixed trimesh.
  final island = lib.instance('island');
  if (lib.find(island, 'collision') case final collision?) {
    collision.visible = false;
    if (physics) {
      collision.addComponent(
        Collider(
          shape: collision.extractMeshData().toTriMeshShape(),
          collisionLayer: Layers.ground,
        ),
      );
    }
  }
  if (materials?['wet_sand'] case final sand?) {
    assign(lib, island, 'ground', sand);
  }
  scenery.ground = lib.find(island, 'ground');
  world.spawn([NodeRef(island), const Scenery()]);

  // Buildings at their anchors.
  for (final (model, anchor, layer) in const [
    ('cottage', 'cottage_anchor', Layers.prop),
    ('dock', 'dock_anchor', Layers.ground),
  ]) {
    final transform = doc.worldTransform(anchor);
    if (transform == null) continue;
    final node = lib.instance(model)..localTransform = transform;
    if (physics) {
      node.addComponent(
        Collider(
          shape: node.extractMeshData().toTriMeshShape(),
          collisionLayer: layer,
        ),
      );
    }
    final glass = model == 'cottage' ? (materials?['lamp_glass']) : null;
    if (glass != null) assign(lib, node, 'window', glass);
    final at = transform.getTranslation();
    world.spawn([
      NodeRef(node),
      const Scenery(),
      if (model == 'cottage') CameraFade(at.x, at.z, islandCottageRadius),
    ]);
    // The cottage window spills warm light onto the ground outside: a
    // rectangular area light on the window, facing out.
    if (model == 'cottage' && lib.find(node, 'window') != null) {
      final window = lib.find(node, 'window')!.globalTransform.getTranslation();
      final out = Vector3(window.x - at.x, 0, window.z - at.z);
      if (out.length2 > 1e-6) {
        out.normalize();
        final light = RectAreaLight(
          color: Vector3(1.0, 0.68, 0.38),
          intensity: islandWindowLight,
          width: 1.1,
          height: 0.9,
          range: 12,
        );
        final glow = Node(name: 'window_light')
          ..localTransform = _facing(window + out * 0.15, out)
          ..addComponent(RectAreaLightComponent(light));
        setRenderLayer(glow, RenderLayers.actors);
        world.spawn([NodeRef(glow), const Scenery()]);
      }
    }
  }

  // Rocks, loose props and set dressing from the layout.
  for (final piece in islandLayout) {
    final y = grid.sample(piece.x, piece.z);
    final node = lib.instance(piece.model)
      ..localTransform = (Matrix4.translationValues(
        piece.x,
        y + (piece.kind == .dynamicProp ? 0.05 : 0),
        piece.z,
      )..rotateY(piece.yaw));
    switch (piece.kind) {
      case .rock:
        if (physics) {
          node.addComponent(
            Collider(
              shape: node.extractMeshData().toConvexHullShape(),
              collisionLayer: Layers.prop,
            ),
          );
        }
        world.spawn([
          NodeRef(node),
          const Scenery(),
          if (piece.radius > 1) CameraFade(piece.x, piece.z, piece.radius),
        ]);
      case .dynamicProp when physics:
        node
          ..addComponent(RigidBody(mass: piece.mass, angularDamping: 0.6))
          ..addComponent(
            Collider(
              shape: node.extractMeshData().toConvexHullShape(),
              collisionLayer: Layers.prop,
              collisionMask: Layers.propMask,
            ),
          );
        setRenderLayer(node, RenderLayers.actors);
        world.spawn([NodeRef(node), const LooseProp(), const PhysicsDriven()]);
      default:
        world.spawn([NodeRef(node), const Scenery()]);
    }
  }

  // Grass, scattered deterministically over gentle, dry ground.
  final rng = math.Random(islandGrassSeed);
  final grass = materials?['grass_sway'];
  var placed = 0;
  for (var tries = 0; placed < islandGrassCount && tries < 20000; tries++) {
    final i = rng.nextInt(gridCellCount);
    if (grid.walkable[i] == 0 ||
        grid.height[i] < islandGrassMinHeight ||
        grid.slope[i] > 20) {
      continue;
    }
    final x = gridCenterX(i % gridCells) + rng.nextDouble() - 0.5;
    final z = gridCenterZ(i ~/ gridCells) + rng.nextDouble() - 0.5;
    final node = lib.instance('grass_tuft')
      ..localTransform = (Matrix4.translationValues(x, grid.sample(x, z), z)
        ..rotateY(rng.nextDouble() * math.pi * 2)
        ..scaleByDouble(
          0.8 + rng.nextDouble() * 0.6,
          0.8 + rng.nextDouble() * 0.6,
          0.8 + rng.nextDouble() * 0.6,
          1,
        ));
    if (grass != null) assignTree(node, grass);
    setRenderLayer(node, RenderLayers.actors);
    setRenderLayer(node, RenderLayers.actors);
    world.spawn([NodeRef(node), const Scenery()]);
    placed++;
  }

  // The sea: one big plane; its swell and the beam streak are in sea.fmat.
  final sea = Node(
    name: 'sea',
    mesh: Mesh(
      PlaneGeometry(
        width: islandSeaSize,
        depth: islandSeaSize,
        segmentsX: islandSeaSegments,
        segmentsZ: islandSeaSegments,
      ),
      materials?['sea'] ??
          (UnlitMaterial()..baseColorFactor = Vector4(0.03, 0.08, 0.15, 1)),
    ),
  );
  sea
    ..shadowCastingMode = ShadowCastingMode.off
    ..layers = RenderLayers.actors;
  scenery.sea = sea;
  setRenderLayer(sea, RenderLayers.actors);
  world.spawn([NodeRef(sea), const Scenery()]);

  // Rolling ground fog the beam cuts through.
  if (materials?['ground_fog'] case final fog?) {
    for (final (x, z, size) in islandFogPlanes) {
      final node = Node(
        name: 'fog',
        mesh: Mesh(PlaneGeometry(width: size, depth: size), fog),
      )..localTransform = Matrix4.translationValues(x, islandFogHeight, z);
      node
        ..shadowCastingMode = ShadowCastingMode.off
        ..layers = RenderLayers.actors;
      scenery.fog.add(node);
      setRenderLayer(node, RenderLayers.actors);
      world.spawn([NodeRef(node), const Scenery()]);
    }
  }

  // Sky, a low moon (shadows and god rays), and the night/dawn looks.
  final skybox = Skybox(
    materials?.sky ??
        GradientSkySource(
          zenithColor: Vector3(0.01, 0.02, 0.06),
          horizonColor: Vector3(0.06, 0.09, 0.18),
          groundColor: Vector3(0.01, 0.02, 0.04),
        ),
  );
  final moon = DirectionalLight(
    direction: islandMoonDirection.normalized(),
    color: Vector3(0.5, 0.62, 1.0),
    intensity: islandMoonNight,
    castsShadow: true,
  );
  if (materials?.sky case final sky?) {
    setParam3(
      sky.parameters,
      'moon_dir',
      -islandMoonDirection.normalized(),
    );
  }
  scenery
    ..moonLight = moon
    ..night = nightLook(skybox)
    ..dawn = dawnLook(skybox);
  scene
    ..directionalLight = moon
    ..antiAliasingMode = AntiAliasingMode.auto
    ..environmentSettings = scenery.night!;
}

/// Night ↔ dawn: retarget the sky tween on state changes.
void _skyToNight(World world) => world.resource<SkyTint>().toward(0);

void _skyToDawn(World world) => world.resource<SkyTint>().toward(1);

void _skyToTitle(World world) => world.resource<SkyTint>().toward(0.25);

/// Visual: ticks the sky tint on wall time and grades the scene by it,
/// and moves the sea with the tide.
void _tickSky(World world) {
  final tint = world.resource<SkyTint>()..tween.tick(world.unscaledDelta);
  final scene = world.resource<Scene>();
  final scenery = world.resource<IslandScenery>();
  final dawn = tint.dawn;
  if (scenery.moonLight case final moon?) {
    moon
      ..intensity = islandMoonNight +
          dawn * (islandMoonDawn - islandMoonNight) +
          scenery.flash * islandLightningBoost
      ..color = Vector3(
        0.55 + dawn * 0.45,
        0.66 + dawn * 0.16,
        1.0 - dawn * 0.35,
      );
  }
  // Cross-fade the whole look with the sky (only while it moves).
  if ((dawn - scenery.appliedDawn).abs() > 0.002 &&
      scenery.night != null &&
      scenery.dawn != null) {
    scene.environmentSettings =
        EnvironmentSettings.lerp(scenery.night!, scenery.dawn!, dawn);
    scenery.appliedDawn = dawn;
  }
  final tide = world.resource<TideLevel>();
  if (scenery.sea case final sea?) {
    final target = tide.low ? -islandTideShift : 0.0;
    final y = smoothTo(sea.position.y, target, world.delta, 1.5);
    sea.position = Vector3(0, y, 0);
  }
  for (final fog in scenery.fog) {
    fog.visible = dawn < 0.95;
  }
}

/// A transform at [at] whose local +Z (an area light's facing) points
/// along [dir].
Matrix4 _facing(Vector3 at, Vector3 dir) {
  final forward = dir.normalized();
  final right = Vector3(0, 1, 0).cross(forward)..normalize();
  final up = forward.cross(right)..normalize();
  return Matrix4.columns(
    Vector4(right.x, right.y, right.z, 0),
    Vector4(up.x, up.y, up.z, 0),
    Vector4(forward.x, forward.y, forward.z, 0),
    Vector4(at.x, at.y, at.z, 1),
  );
}
