part of '../light.dart';

void installBeamVisuals(GameBuilder game) {
  game.addSystem(
    Schedules.renderSync,
    _drawBeam,
    writes: {BeamVisual},
    runIf: hasResource<Scene>(),
  );
}

/// Render sync: every traced segment as lit air (a shaft from the lens, or
/// from the mirror face it left), light painted along the ground under it,
/// a spot light thrown from each mirror that relays it, and a warm splash
/// where a run ends on a cliff or a rock.
void _drawBeam(World world) {
  final visual = world.query<BeamVisual>().firstOrNull?.$2;
  if (visual == null) {
    _spawnBeamVisual(world);
    return;
  }
  final path = world.resource<BeamPath>();
  final beam = world.resource<Beam>();
  final grid = world.tryResource<HeightGrid>();
  double ground(double x, double z) => math.max(grid?.sample(x, z) ?? 0, 0);

  final from = Vector3.zero(), to = Vector3.zero();
  // At dawn the relays are only a preview: shafts and ground light, no
  // extra lights to pay for.
  final preview = world.state<GameStatus>() != GameStatus.night;
  var relays = 0, splashes = 0;
  for (var i = 0; i < visual.slots.length; i++) {
    final slot = visual.slots[i];
    if (i >= path.segments.length) {
      slot.hide();
      continue;
    }
    final s = path.segments[i];
    final strength = s.intensity / beamIntensity;
    final lens = s.from == null;
    if (lens) {
      from.setValues(s.x0, beam.groundY + beamOriginHeight, s.z0);
    } else {
      from.setValues(s.x0, ground(s.x0, s.z0) + beamMirrorFaceHeight, s.z0);
    }
    to.setValues(s.x1, ground(s.x1, s.z1) + (lens ? 0.3 : 0.5), s.z1);
    aimShaft(
      slot.shaft,
      from,
      to,
      beam.halfWidth * (lens ? beamShaftWidthLens : beamShaftWidthRelay),
    );
    if (slot.shaftMaterial case final m?) {
      setParam(m.parameters, 'intensity', strength * (lens ? 1.0 : 1.25));
      setParam(m.parameters, 'reach', lens ? 0.8 : 0.65);
      setParam(m.parameters, 'use_flame', lens ? 1 : 0);
    }
    if (slot.stripe case final stripe?) {
      _placeStripe(stripe, s, beam.halfWidth, ground);
      if (slot.stripeMaterial case final m?) {
        setParam(m.parameters, 'intensity', strength * (lens ? 1.0 : 1.2));
        setParam(m.parameters, 'span', s.length);
      }
    }

    if (!lens && !preview && relays < visual.relays.length) {
      final spot = visual.relays[relays++];
      final reach = s.length;
      final aimAt = Vector3(
        s.x0 + (s.x1 - s.x0) * 0.6,
        ground(s.x0 + (s.x1 - s.x0) * 0.6, s.z0 + (s.z1 - s.z0) * 0.6),
        s.z0 + (s.z1 - s.z0) * 0.6,
      );
      spot.node
        ..visible = true
        ..localTransform = Matrix4.translation(from);
      spot.light
        ..direction = (aimAt - from).normalized()
        ..range = reach + beamRelaySpotReachPad
        ..intensity = beamRelaySpotIntensity * strength;
    }
    if (s.blocked && !preview && splashes < visual.splashes.length) {
      final (node, light) = visual.splashes[splashes++];
      final len = math.max(s.length, 1e-3);
      final back = math.min(beamSplashBack, len);
      final x = s.x1 - (s.x1 - s.x0) / len * back;
      final z = s.z1 - (s.z1 - s.z0) / len * back;
      node
        ..visible = true
        ..localTransform =
            Matrix4.translationValues(x, ground(x, z) + beamSplashHeight, z);
      light.intensity = beamSplashIntensity * strength;
    }
  }
  for (var i = relays; i < visual.relays.length; i++) {
    visual.relays[i]
      ..node.visible = false
      ..light.intensity = 0;
  }
  for (var i = splashes; i < visual.splashes.length; i++) {
    final (node, light) = visual.splashes[i];
    node.visible = false;
    light.intensity = 0;
  }
}

/// Lays the ground-light box along [s]: across its width, from below the
/// lowest ground under it to above the highest.
void _placeStripe(
  DecalNode stripe,
  BeamSegment s,
  double halfWidth,
  double Function(double, double) ground,
) {
  final len = s.length;
  if (len < 0.05) {
    stripe.visible = false;
    return;
  }
  var low = double.infinity, high = -double.infinity;
  for (var k = 0; k <= 12; k++) {
    final f = k / 12;
    final h = ground(s.x0 + (s.x1 - s.x0) * f, s.z0 + (s.z1 - s.z0) * f);
    low = math.min(low, h);
    high = math.max(high, h);
  }
  low -= beamStripeBelow;
  high += beamStripeAbove;
  stripe
    ..visible = true
    ..localTransform = Matrix4.compose(
      Vector3((s.x0 + s.x1) / 2, (low + high) / 2, (s.z0 + s.z1) / 2),
      Quaternion.axisAngle(
        Vector3(0, 1, 0),
        math.atan2(s.x1 - s.x0, s.z1 - s.z0),
      ),
      Vector3(halfWidth * 2 * beamStripeWidth, high - low, len),
    );
}

/// The pools, created the first time the beam draws.
void _spawnBeamVisual(World world) {
  final materials = world.tryResource<Materials>();
  final root = Node(name: 'beam');
  final slots = <BeamSlot>[];
  for (var i = 0; i < beamVisualSlots; i++) {
    final shaftMaterial = materials?.take('beam');
    final shaft = lightShaft(
      shaftMaterial ?? lightVolumeFallback(),
      startRadius: beamShaftStartRadius,
    )..visible = false;
    final stripeMaterial = materials?.take('beam_ground');
    final stripe = stripeMaterial == null
        ? null
        : (DecalNode(material: stripeMaterial, name: 'beam_ground')
            ..visible = false);
    root.add(shaft);
    if (stripe != null) root.add(stripe);
    slots.add(BeamSlot(shaft, shaftMaterial, stripe, stripeMaterial));
  }
  final relays = <BeamSpot>[
    for (var i = 0; i < beamRelaySpots; i++)
      BeamSpot(
        SpotLight(
          color: Vector3(1.0, 0.84, 0.6),
          intensity: 0,
          innerConeAngle: beamRelaySpotInner,
          outerConeAngle: beamRelaySpotOuter,
          castsShadow: i < beamRelayShadowSpots,
          shadowMapResolution: 512,
          shadowNear: 0.2,
          shadowSoftness: 1.5,
        ),
      ),
  ];
  for (final spot in relays) {
    root.add(spot.node);
  }
  final splashes = <(Node, PointLight)>[
    for (var i = 0; i < beamSplashLights; i++)
      () {
        final light = PointLight(
          color: Vector3(1.0, 0.78, 0.5),
          intensity: 0,
          range: beamSplashRange,
        );
        return (
          Node(name: 'beam_splash')
            ..visible = false
            ..addComponent(PointLightComponent(light)),
          light,
        );
      }(),
  ];
  for (final (node, _) in splashes) {
    root.add(node);
  }
  setRenderLayer(root, RenderLayers.actors);
  world.spawn([BeamVisual(slots, relays, splashes), NodeRef(root)]);
}
