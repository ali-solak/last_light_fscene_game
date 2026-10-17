part of '../lighthouse.dart';

void installLighthouseVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.startup,
      _dressLighthouse,
      reads: const {},
      inSet: GameSets.keeper,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.renderSync,
      _turnLampHead,
      writes: {LighthouseModel},
      runIf: hasResource<Scene>(),
    );
}

/// Startup, visual: the tower at its anchor, with a fixed collider and the
/// lamp head's warm light.
void _dressLighthouse(World world) {
  final lib = world.resource<ModelLibrary>();
  final anchors = world.resource<IslandAnchors>();
  final at = anchors.lighthouse;
  final tower = lib.instance('lighthouse')
    ..localTransform = Matrix4.translation(at);
  if (world.hasResource<PhysicsWorld>()) {
    tower.addComponent(
      Collider(
        shape: CylinderShape(
          radius: lighthouseRadius,
          halfHeight: lighthouseHeight / 2,
        ),
        collisionLayer: Layers.prop,
        localPose: Matrix4.translationValues(0, lighthouseHeight / 2, 0),
      ),
    );
  }
  final head = tower.getChildByName('lamp_head') ?? tower;
  final lens = tower.getChildByName('lens');
  final glass = world.tryResource<Materials>()?.take('lamp_glass');
  if (lens != null && glass != null) assignNode(lens, glass);
  final light = PointLight(
    color: Vector3(1.0, 0.82, 0.55),
    intensity: lighthouseLightIntensity,
    range: lighthouseLightRange,
  );
  head.add(Node(name: 'lamp_light')..addComponent(PointLightComponent(light)));
  final spot = SpotLight(
    color: Vector3(1.0, 0.86, 0.62),
    intensity: lighthouseSpotIntensity,
    range: lighthouseSpotRange,
    innerConeAngle: lighthouseSpotInner,
    outerConeAngle: lighthouseSpotOuter,
    castsShadow: true,
    shadowMapResolution: 1024,
    shadowNear: 1.0,
    shadowSoftness: 1.2,
  );
  final spotNode = Node(name: 'beam_spot')
    ..addComponent(SpotLightComponent(spot));
  tower.add(spotNode);
  world.spawn([
    LighthouseModel(head, lens, light, spotNode, spot),
    NodeRef(tower),
    CameraFade(at.x, at.z, lighthouseRadius),
  ]);
}

/// Render sync: the head follows the beam yaw and the spot sweeps with it;
/// both dim and stutter with the Flame.
void _turnLampHead(World world) {
  final beam = world.resource<Beam>();
  final flame = world.resource<Flame>().fraction;
  final grid = world.tryResource<HeightGrid>();
  world.query<LighthouseModel>().each((_, model) {
    model.lampHead.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), beam.yaw);
    model.flicker += world.delta * 13;
    final stutter = flame < lighthouseFlickerBelow
        ? (0.55 + 0.45 * math.sin(model.flicker * 2.3).abs())
        : 1.0;
    model.light.intensity =
        lighthouseLightIntensity * (0.25 + 0.75 * flame) * stutter;

    // The spot, from the lens (tower-local), aimed at the ground ahead.
    final lens = Vector3(
      beam.dirX * beamOriginForward,
      beamOriginHeight,
      beam.dirZ * beamOriginForward,
    );
    final ax = beam.centreX + beam.dirX * lighthouseSpotAim;
    final az = beam.centreZ + beam.dirZ * lighthouseSpotAim;
    final ground = math.max(grid?.sample(ax, az) ?? 0, 0.0);
    final aim = Vector3(
      beam.dirX * lighthouseSpotAim,
      ground - beam.groundY,
      beam.dirZ * lighthouseSpotAim,
    );
    model.spotNode.localTransform = Matrix4.translation(lens);
    model.spot
      ..direction = (aim - lens).normalized()
      ..intensity = beam.on
          ? lighthouseSpotIntensity * (0.3 + 0.7 * flame) * stutter
          : 0;
    if (model.lens?.mesh?.primitives.first.material
        case final PreprocessedMaterial glass) {
      setParam(glass.parameters, 'lit', 1);
      setParam(glass.parameters, 'intensity', (0.3 + flame) * stutter);
    }
  });
}
