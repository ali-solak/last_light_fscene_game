part of '../lantern.dart';

void installLanternVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _lanternVisuals,
      writes: {LanternVisual, KeeperModel},
      reads: {Lantern, KeeperBrain, KeeperBody, SceneTransform},
      inSet: GameSets.lampAnimation,
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.update,
      _drawThrownLamps,
      reads: {ThrownLamp, LanternVisual, Pooled},
      inSet: GameSets.lampAnimation,
      after: [_lanternVisuals],
      runIf: hasResource<Scene>(),
    )
    ..addSystem(
      Schedules.startup,
      _rackLures,
      reads: const {},
      runIf: hasResource<Scene>().and(hasResource<FxTextures>()),
    )
    ..addSystem(
      Schedules.update,
      _drawLures,
      writes: {LureGlow},
      reads: {Lure, SceneTransform, Pooled},
      inSet: GameSets.lampAnimation,
      runIf: hasResource<LureRack>(),
    );
}

/// Visual: the lamp's light carving the dark. A shadow-casting spot that
/// pools wide ahead of the keeper and snaps into a hot narrow beam at the
/// aim when he focuses, a shaft of lit air along it, the lamp's own warm
/// glow, the flickering flame, embers off a hot lamp, the red smoulder of
/// a dry one, and burning puddles.
void _lanternVisuals(World world) {
  final aim = world.resource<AimInput>();
  final grid = world.tryResource<HeightGrid>();
  final fx = world.tryResource<Fx>();
  final dt = world.delta;

  world.query4<Lantern, KeeperModel, KeeperBrain, KeeperBody>().each((
    entity,
    lantern,
    model,
    brain,
    body,
  ) {
    final t = world.tryGet<SceneTransform>(entity);
    if (t == null) return;
    var visual = world.tryGet<LanternVisual>(entity);
    if (visual == null) {
      visual = _spawnLanternLight(world);
      world.add(entity, visual);
    }

    visual.time += dt;
    if (world.events<LampFlare>().isNotEmpty) visual.flare = 1;
    if (world.events<CrabBashed>().isNotEmpty) {
      visual.flare = math.max(visual.flare, lanternBashFlare);
    }
    visual.flare = math.max(0, visual.flare - dt / lanternFlareFlash);
    final on = lantern.lit && brain.mode.state != KeeperMode.downed;
    visual.focus = smoothTo(
      visual.focus,
      lantern.focusing ? 1 : 0,
      dt,
      lanternFocusHalfLife,
    );
    final f = visual.focus;
    // Low, the lamp sputters; dry, it smoulders: ember red, breathing.
    visual.dry = smoothTo(
      visual.dry,
      lantern.oil <= 0 ? 1 : 0,
      dt,
      lanternDryHalfLife,
    );
    final dry = visual.dry;
    final breath = lanternDryBreath(visual.time);
    final sputter = lantern.oil > 0 && lantern.oil < lanternSputterBelow
        ? 0.6 + 0.4 * math.sin(visual.time * 31).abs()
        : 1.0;
    final spotShare = sputter * (1 - dry) + lanternDrySpot * breath * dry;
    final glowShare = sputter * (1 - dry) + lanternDryGlow * breath * dry;
    final flicker = 1 +
        0.05 * math.sin(visual.time * lanternFlickerHz * math.pi * 2) +
        0.03 * math.sin(visual.time * 23.7);

    // The lamp in his hand, and where its light goes: through his eyes it
    // is the lamp in the left hand pointing along the view (dipped a
    // little held low, straight down the sights focused); over the
    // shoulder, from his side toward the ground ahead or the aim.
    final rig = world.tryResource<CameraRig>();
    final Vector3 hand;
    final Vector3 dir;
    if (rig != null && rig.firstPerson) {
      final f0 = rig.look.normalized();
      final r0 = rig.right.normalized();
      final u0 = f0.cross(r0)..normalize();
      hand = rig.position +
          r0 * lanternFpHand.x +
          u0 * lanternFpHand.y +
          f0 * lanternFpHand.z;
      final dip = (u0 * -lanternFpWideDip)..add(f0);
      dir = (dip.normalized() * (1 - f) + f0 * f)..normalize();
    } else {
      final fx0 = yawDirX(body.facing), fz0 = yawDirZ(body.facing);
      hand = Vector3(
        t.x + fx0 * lanternHandForward,
        t.y + lanternHandHeight,
        t.z + fz0 * lanternHandForward,
      );
      final wideX = t.x + fx0 * lanternWideDrop;
      final wideZ = t.z + fz0 * lanternWideDrop;
      final wide = Vector3(
        wideX,
        math.max(grid?.sample(wideX, wideZ) ?? t.y, 0),
        wideZ,
      );
      var focusAt = hand + Vector3(fx0, -0.1, fz0) * lanternFocusLength;
      if (aim.valid) {
        focusAt = aim.point.clone()..y += 0.4;
      }
      dir = (wide + (focusAt - wide) * f - hand)..normalize();
    }

    visual.spot
      ..direction = dir
      ..range = lanternSpotWideRange + (lanternSpotFocusRange - lanternSpotWideRange) * f
      ..innerConeAngle = lanternWideInner + (lanternFocusInner - lanternWideInner) * f
      ..outerConeAngle = lanternWideOuter + (lanternFocusOuter - lanternWideOuter) * f
      ..intensity = on
          ? (lanternSpotWide + (lanternSpotFocus - lanternSpotWide) * f) *
                    spotShare *
                    flicker +
                lanternSpotFocus * 3 * visual.flare
          : 0;
    // The spot leaves the lamp; through his eyes the warm glow sits ahead
    // and below, lighting the ground at his feet instead of blowing out
    // the hands right in front of the eye.
    final fp = rig != null && rig.firstPerson;
    // Through his eyes the cone starts ahead of the hands, so the gun and
    // the lamp up close are behind its apex, never lit point-blank.
    visual.spotNode.localTransform = Matrix4.translation(
      fp ? hand + rig.look.normalized() * lanternFpSpotAhead : hand,
    );
    visual.glowNode.localTransform = Matrix4.translation(
      fp ? hand + rig.look * lanternFpGlowAhead - Vector3(0, 0.6, 0) : hand,
    );
    visual.glow.intensity = on
        ? lanternGlowIntensity * (fp ? lanternFpGlowScale : 1) * glowShare * flicker
        : 0;
    visual.spot.color.setFrom(_mixColor(lanternSpotColor, lanternDryLight, dry));
    visual.glow.color.setFrom(_mixColor(lanternGlowColor, lanternDryLight, dry));

    // Focused, the light is a beam: a thin shaft of lit dust out to where
    // it lands (the aim, or as far as it reaches), never in the eye.
    if (visual.beam case final beam?) {
      final strength = on ? f * spotShare * flicker + visual.flare : 0.0;
      if (strength < 0.02) {
        beam.visible = false;
      } else {
        final start = fp
            ? hand + rig.look.normalized() * lanternBeamAhead
            : hand.clone();
        final end = aim.valid && (aim.point - start).length < lanternSpotFocusRange
            ? (aim.point.clone()..y += 0.3)
            : start + dir * lanternSpotFocusRange;
        aimShaft(beam, start, end, lanternBeamRadius);
        if (visual.beamMaterial case final m?) {
          setParam(m.parameters, 'intensity', lanternBeamIntensity * strength);
        }
      }
    }

    // Where the focused light lands: sparks flying off it.
    if (on && f > 0.5 && fx != null && aim.valid) {
      visual.sparks += dt * lanternHotspotSparks;
      final n = visual.sparks.floor();
      if (n > 0) {
        visual.sparks -= n;
        fx.burst(FxKind.spark, aim.point.clone()..y += 0.3, count: n,
            spread: 1.2, speed: 0.4, tint: Vector3(3.2, 2.6, 1.6));
      }
    }

    // A hot focused lamp sheds embers (not in first person, where they
    // would spawn in the player's face).
    if (on && f > 0.5 && fx != null && !(rig?.firstPerson ?? false)) {
      visual.embers += dt * lanternFocusEmbers;
      final n = visual.embers.floor();
      if (n > 0) {
        visual.embers -= n;
        fx.burst(FxKind.ember, hand, count: n, dir: dir, spread: 0.7,
            speed: 0.6, life: 0.6);
      }
    }

    // A dry lamp sheds embers, rising off it (not in first person, where
    // they would streak across the lens; the glass smoulders instead).
    if (on && dry > 0.5 && fx != null && !fp) {
      visual.embers += dt * lanternDryEmbers;
      final n = visual.embers.floor();
      if (n > 0) {
        visual.embers -= n;
        fx.burst(FxKind.ember, hand, count: n, dir: Vector3(0, 1, 0),
            spread: 0.5, speed: 0.5, life: 0.9);
      }
    }

    // The glass glows warm; dry, a deep breathing red.
    if (model.glass case final glass?) {
      setParam(glass.parameters, 'intensity',
          1 - dry + lanternDryGlass * breath * dry);
      glass.parameters.setVec3(
        'warm_color',
        _mixColor(lanternGlassWarm, lanternDryGlassWarm, dry),
      );
    }

    // The flame flickers ±8 % at 9 Hz; dry, it sinks to a red coal.
    if (model.flame case final flame?) {
      final n = math.sin(visual.time * lanternFlickerHz * math.pi * 2) * 0.6 +
          math.sin(visual.time * 23.7) * 0.4;
      final s = 1 + n * lanternFlickerAmount * (2 - sputter);
      flame.scale = Vector3.all(
        s * (1 + 0.35 * f) * (1 - dry + lanternDryFlame * dry),
      );
      if (flame.mesh?.primitives.firstOrNull?.material
          case final PreprocessedMaterial m) {
        setParam(m.parameters, 'sputter', 1 - sputter);
        setParam(m.parameters, 'intensity', on ? 1 + f - dry * (1 - breath) : 0);
        m.parameters
          ..setVec3('core_color', _mixColor(lanternFlameCore, lanternDryFlameCore, dry))
          ..setVec3('tip_color', _mixColor(lanternFlameTip, lanternDryFlameTip, dry));
      }
    }
  });
}

/// A thrown lamp: one of the lantern's spares tumbling through its arc,
/// flame lit, trailing light. (Where it lands, the fire feature draws the
/// burning oil.)
void _drawThrownLamps(World world) {
  final spares = world.query<LanternVisual>().firstOrNull?.$2.spares;
  world.query<ThrownLamp>().each((entity, lamp) {
    final pose = Matrix4.compose(
      lamp.position,
      Quaternion.axisAngle(Vector3(1, 0, 0), lamp.age * 14),
      Vector3.all(1),
    );
    if (world.tryGet<Pooled>(entity) case final pooled?) {
      pooled.node.localTransform = pose;
      return;
    }
    final node = spares?.take();
    if (node == null) return;
    // Placed before its trail forgets the last throw, so no streak.
    node.localTransform = pose;
    node.getComponent<TrailComponent>()?.clear();
    world
      ..add(entity, NodeRef(node))
      ..add(entity, Pooled(spares!, node));
  });
}

/// Startup, visual: the wisps, cold blue-green so they never read as the
/// lamp: a soft glow and a small light.
void _rackLures(World world) {
  final dot = world.resource<FxTextures>().dot;
  world.insert(LureRack(mountRack(world, 'lures', () {
    final glow = Sprite(
      texture: dot,
      width: 0.7,
      height: 0.7,
      color: Vector4(0.5, 1.6, 1.4, 1),
      blendMode: SpriteBlendMode.additive,
    );
    final node = Node(name: 'wisp')
      ..addComponent(
        PointLightComponent(
          PointLight(color: Vector3(0.45, 1.0, 0.9), intensity: 0, range: 5),
        ),
      )
      ..add(Node(name: 'wisp_glow', mesh: glow.mesh));
    setRenderLayer(node, RenderLayers.actors);
    return node;
  }, size: lanternLureRack)));
}

/// A wisp on each lure; it bobs, breathes, and gutters out at the end.
void _drawLures(World world) {
  final rack = world.resource<LureRack>().rack;
  world.query<SceneTransform>().having<Lure>().without<Pooled>().each((
    entity,
    t,
  ) {
    final node = rack.take();
    final glow = node?.children.firstOrNull;
    final light = node?.getComponent<PointLightComponent>()?.light;
    if (node == null || glow == null || light == null) return;
    node.position = t.translation;
    light.intensity = 0;
    glow.scale = Vector3.zero();
    world
      ..add(entity, NodeRef(node))
      ..add(entity, Pooled(rack, node))
      ..add(entity, LureGlow(glow, light));
  });
  final dt = world.delta;
  world.query<LureGlow>().each((_, wisp) {
    final age = wisp.age += dt;
    final fade = ((lanternLureSeconds - age) / 0.6).clamp(0.0, 1.0) *
        (age / 0.3).clamp(0.0, 1.0);
    final breath = 0.8 + 0.2 * math.sin(age * 5);
    wisp.light.intensity = 2.2 * breath * fade;
    wisp.glow
      ..position = Vector3(0, 0.15 * math.sin(age * 2.4), 0)
      ..scale = Vector3.all(fade * breath);
  });
}

/// A lit lamp to throw: the model, its flame's light, a trail.
Node _spareLamp(ModelLibrary lib) {
  final node = Node(name: 'thrown_lamp')
    ..addComponent(
      PointLightComponent(
        PointLight(color: Vector3(1.0, 0.7, 0.35), intensity: 5, range: 7),
      ),
    )
    ..addComponent(TrailComponent(width: 0.12, lifetime: 0.3));
  if (lib.has('oil_lamp')) {
    node.add(lib.instance('oil_lamp')..scale = Vector3.all(1.4));
  }
  setRenderLayer(node, RenderLayers.actors);
  return node;
}

/// The lamp's light nodes, in world space (they aim on their own rather
/// than ride the model's bones).
LanternVisual _spawnLanternLight(World world) {
  final spot = SpotLight(
    color: lanternSpotColor.clone(),
    intensity: 0,
    range: lanternSpotWideRange,
    innerConeAngle: lanternWideInner,
    outerConeAngle: lanternWideOuter,
    castsShadow: true,
    shadowMapResolution: 1024,
    shadowNear: 0.3,
    shadowSoftness: 1.4,
  );
  final glow = PointLight(
    color: lanternGlowColor.clone(),
    intensity: 0,
    range: lanternGlowRange,
  );
  final spotNode = Node(name: 'lantern_spot')
    ..addComponent(SpotLightComponent(spot));
  final glowNode = Node(name: 'lantern_glow')
    ..addComponent(PointLightComponent(glow));
  final root = Node(name: 'lantern_light')
    ..add(spotNode)
    ..add(glowNode);
  // The focused beam's shaft, drawn with the lighthouse's beam material.
  final beamMaterial = world.tryResource<Materials>()?.take('beam');
  Node? beam;
  if (beamMaterial != null) {
    for (final (name, value) in [
      ('use_flame', 0.0),
      ('fill', 1.0),
      ('reach', 0.8),
      ('motes', 0.7),
      ('soft_depth', 0.35),
      ('near_fade', lanternBeamNearFade),
    ]) {
      setParam(beamMaterial.parameters, name, value);
    }
    beamMaterial.parameters.setVec3('color', Vector3(1.0, 0.78, 0.45));
    beam = lightShaft(beamMaterial, startRadius: lanternBeamStartShare)
      ..visible = false;
    root.add(beam);
  }
  setRenderLayer(root, RenderLayers.actors);
  world.spawn([NodeRef(root)]);
  final lib = world.resource<ModelLibrary>();
  final spares = mountRack(world, 'spare_lamps', () => _spareLamp(lib),
      size: lanternSpares);
  return LanternVisual(
      spot, spotNode, glow, glowNode, beam, beamMaterial, spares);
}

Vector3 _mixColor(Vector3 a, Vector3 b, double t) => a + (b - a) * t;
