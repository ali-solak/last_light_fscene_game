part of '../light.dart';

void installBraziers(GameBuilder game) {
  game
    ..observe<BrazierStand>(
      onAdd: (world, entity, _) => world.add(entity, Brazier()),
    )
    ..addSystem(OnEnter(GameStatus.night), _douseBraziers, writes: {Brazier})
    ..addSystem(
      Schedules.fixedUpdate,
      _kindleBraziers,
      writes: {Brazier},
      reads: {SceneTransform},
      inSet: GameSets.light,
      after: [_traceBeam],
    )
    ..addSystem(
      Schedules.update,
      _drawBraziers,
      writes: {BrazierVisual},
      reads: {Brazier, SceneTransform, NodeRef},
      inSet: GameSets.lampAnimation,
      runIf: hasResource<Scene>(),
    );
}

/// Every night starts with the signal fires out.
void _douseBraziers(World world) {
  world.query<Brazier>().each((_, b) {
    b
      ..lit = false
      ..charge = 0;
  });
}

/// Thrown light (any segment leaving a mirror) passing over a brazier at
/// about its height kindles it after a moment; at dawn the same test only
/// previews which ones the mirrors as set would reach.
void _kindleBraziers(World world) {
  final path = world.resource<BeamPath>();
  final status = world.state<GameStatus>();
  final dt = world.dt;
  world.query2<Brazier, SceneTransform>().each((entity, brazier, t) {
    var touched = false;
    for (final s in path.segments) {
      if (s.from == null) continue;
      if (s.altitude < t.y - brazierCatchBelow ||
          s.altitude > t.y + brazierCatchAbove) {
        continue;
      }
      if (distToSegment(t.x, t.z, s.x0, s.z0, s.x1, s.z1) <=
          brazierCatchRadius) {
        touched = true;
        break;
      }
    }
    brazier
      ..touched = touched
      ..reachable = touched || (brazier.reachable && status != GameStatus.dawnBuild);
    if (status == GameStatus.dawnBuild) {
      brazier.reachable = touched;
      return;
    }
    if (status != GameStatus.night || brazier.lit) return;
    brazier.charge = touched
        ? brazier.charge + dt
        : math.max(0, brazier.charge - dt * 0.5);
    if (brazier.charge >= brazierKindleSeconds) {
      brazier.lit = true;
      world.emit(BrazierLit(entity));
    }
  });
}

/// Visual: each stand gets an iron fire bowl; lit, it roars (flames,
/// embers, smoke, a big flickering light); kindling, the coals glow up;
/// at dawn a reachable one pulses so the player sees the plan works.
void _drawBraziers(World world) {
  final fx = world.tryResource<Fx>();
  final dt = world.delta;
  world.query2<Brazier, SceneTransform>().each((entity, brazier, t) {
    var visual = world.tryGet<BrazierVisual>(entity);
    if (visual == null) {
      visual = _spawnBrazierModel(world, t);
      world.add(entity, visual);
    }
    visual.time += dt;
    final kindling = (brazier.charge / brazierKindleSeconds).clamp(0.0, 1.0);
    final preview = brazier.reachable && !brazier.lit
        ? 0.35 + 0.25 * math.sin(visual.time * 4)
        : 0.0;
    visual.heat = smoothTo(
      visual.heat,
      brazier.lit ? 1.0 : math.max(kindling * 0.8, preview),
      dt,
      0.15,
    );
    visual.fire = smoothTo(visual.fire, brazier.lit ? 1 : 0, dt, 0.25);
    final flicker = 0.85 +
        0.1 * math.sin(visual.time * 17.3) +
        0.05 * math.sin(visual.time * 31.1);
    visual.light.intensity =
        (visual.heat * 2 + visual.fire * brazierLightIntensity) * flicker;
    visual.coalMaterial.emissiveFactor = Vector4(
      3.2 * visual.heat * flicker,
      0.9 * visual.heat * flicker,
      0.12 * visual.heat,
      1,
    );

    // The fire: a few flame sheets standing in the bowl, the same flame
    // the grass burns with.
    final bowl = Vector3(t.x, t.y + brazierBowlHeight, t.z);
    if (visual.flames case final flames?) {
      flames.clearInstances();
      if (visual.fire > 0.05) {
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi * 2 / 3;
          addFlame(
            flames,
            // In the brazier node's own space.
            Vector3(math.cos(a) * 0.18, brazierBowlHeight - 0.15, math.sin(a) * 0.18),
            brazierFlameScale * (0.85 + 0.15 * i) * visual.fire,
            phase: i / 3 + t.x * 0.1,
            heat: visual.fire,
          );
        }
      }
    }

    if (fx == null) return;
    if (visual.fire > 0.05) {
      visual.fireDebt += dt * 6 * visual.fire;
      final n = visual.fireDebt.floor();
      if (n > 0) {
        visual.fireDebt -= n;
        if (visual.time % 0.2 < dt) {
          fx
            ..burst(FxKind.ember, bowl + Vector3(0, 0.6, 0), count: 2,
                spread: 0.6)
            ..burst(FxKind.smoke, bowl + Vector3(0, 1.4, 0), count: 1,
                size: 0.9, spread: 0.3);
        }
      }
    } else if (brazier.touched && visual.time % 0.1 < dt) {
      // Kindling: sparks fly where the thrown light bites.
      fx.burst(FxKind.ember, bowl, count: 2, spread: 0.8, speed: 0.6);
    }
  });

  for (final lit in world.events<BrazierLit>()) {
    final t = world.tryGet<SceneTransform>(lit.brazier);
    if (t == null) continue;
    final bowl = Vector3(t.x, t.y + brazierBowlHeight, t.z);
    fx
      ?..burst(FxKind.flash, bowl, count: 1, size: 1.6)
      ..burst(FxKind.fire, bowl, count: 8, spread: 1.0, speed: 5, size: 0.9)
      ..burst(FxKind.ember, bowl, count: 50, spread: 1.4, speed: 3);
  }
}

/// A stone column with an iron bowl of coals on top, and its light.
BrazierVisual _spawnBrazierModel(World world, SceneTransform t) {
  final stone = PhysicallyBasedMaterial()
    ..baseColorFactor = Vector4(0.28, 0.27, 0.26, 1)
    ..roughnessFactor = 0.9;
  final iron = PhysicallyBasedMaterial()
    ..baseColorFactor = Vector4(0.12, 0.1, 0.09, 1)
    ..roughnessFactor = 0.5
    ..metallicFactor = 0.7;
  final coal = PhysicallyBasedMaterial()
    ..baseColorFactor = Vector4(0.05, 0.04, 0.035, 1)
    ..roughnessFactor = 0.95;
  final light = PointLight(
    color: Vector3(1.0, 0.6, 0.25),
    intensity: 0,
    range: brazierLightRange,
  );
  final coals = Node(
    name: 'brazier_coals',
    mesh: Mesh(
      CylinderGeometry(bottomRadius: 0.5, topRadius: 0.55, height: 0.12),
      coal,
    ),
  )..position = Vector3(0, brazierBowlHeight - 0.02, 0);
  final root = Node(name: 'brazier')
    ..position = Vector3(t.x, t.y, t.z)
    ..add(
      Node(
        mesh: Mesh(
          CylinderGeometry(bottomRadius: 0.45, topRadius: 0.3, height: 1.0),
          stone,
        ),
      )..position = Vector3(0, 0.5, 0),
    )
    ..add(
      Node(
        mesh: Mesh(
          CylinderGeometry(
            bottomRadius: 0.32,
            topRadius: 0.62,
            height: 0.35,
            topCap: false,
          ),
          iron,
        ),
      )..position = Vector3(0, brazierBowlHeight - 0.12, 0),
    )
    ..add(coals)
    ..add(
      Node(name: 'brazier_light')
        ..position = Vector3(0, brazierBowlHeight + 0.8, 0)
        ..addComponent(PointLightComponent(light)),
    );
  final flames = flameSheets(world.tryResource<Materials>());
  if (flames != null) {
    root.add(
      Node(name: 'brazier_flames')
        ..addComponent(InstancedMeshComponent(flames))
        ..shadowCastingMode = ShadowCastingMode.off,
    );
  }
  setRenderLayer(root, RenderLayers.actors);
  world.spawn([NodeRef(root)]);
  return BrazierVisual(coals, light, coal, flames);
}
