part of '../harpoon.dart';

void installHarpoonVisuals(GameBuilder game) {
  game
    ..addSystem(
      Schedules.renderSync,
      _drawHarpoon,
      writes: {HarpoonVisual, KeeperModel},
      reads: {Harpoon, SceneTransform, KeeperBody},
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    )
    ..addSystem(
      Schedules.renderSync,
      _drawDarts,
      writes: {DartVisual},
      reads: {Dart},
      runIf: hasResource<Scene>().and(hasResource<ModelLibrary>()),
    );
}

/// Render sync: darts as small bolts with a streak of light behind.
void _drawDarts(World world) {
  final lib = world.resource<ModelLibrary>();
  world.query<Dart>().each((entity, dart) {
    var visual = world.tryGet<DartVisual>(entity);
    if (visual == null) {
      if (!lib.has('harpoon_bolt')) return;
      final node = lib.instance('harpoon_bolt')
        ..addComponent(TrailComponent(width: 0.07, lifetime: 0.2));
      setRenderLayer(node, RenderLayers.actors);
      visual = DartVisual(node);
      world
        ..add(entity, visual)
        ..add(entity, NodeRef(node));
    }
    visual.node.localTransform = Matrix4.compose(
      dart.position,
      Quaternion.fromTwoVectors(Vector3(0, 0, -1), dart.velocity.normalized()),
      Vector3.all(harpoonVisualScale * 0.7),
    );
  });
}

/// Render sync: the gun kicks on a shot (muzzle flash, smoke, sparks), the
/// bolt flies with its trail and light, and the chain is a verlet rope from
/// the gun to the bolt: loose and swinging while it pays out, lying on the
/// sand, snapping taut on the reel, then winding back in.
void _drawHarpoon(World world) {
  final lib = world.resource<ModelLibrary>();
  final grid = world.tryResource<HeightGrid>();
  final fx = world.tryResource<Fx>();
  final dt = world.delta;
  double ground(double x, double z) => math.max(grid?.sample(x, z) ?? 0, -0.5);

  world.query4<Harpoon, KeeperModel, SceneTransform, KeeperBody>().each((
    entity,
    harpoon,
    model,
    t,
    body,
  ) {
    final visual = world.tryGet<HarpoonVisual>(entity);
    if (visual == null) {
      if (!lib.has('harpoon_bolt') || !lib.has('chain_link')) return;
      final root = Node(name: 'harpoon_fx');
      final bolt = lib.instance('harpoon_bolt')
        ..visible = false
        ..addComponent(TrailComponent(width: 0.14, lifetime: 0.35))
        ..addComponent(
          PointLightComponent(
            PointLight(
              color: Vector3(1.0, 0.75, 0.4),
              intensity: 4,
              range: 6,
            ),
          ),
        );
      root.add(bolt);
      final links = <Node>[
        for (var i = 0; i < harpoonChainPoints - 1; i++)
          lib.instance('chain_link')..visible = false,
      ];
      root.addAll(links);
      setRenderLayer(root, RenderLayers.actors);
      world.spawn([NodeRef(root)], ownedBy: entity);
      world.add(
        entity,
        HarpoonVisual(bolt, links, ChainRope(harpoonChainPoints)),
      );
      return;
    }

    final state = harpoon.mode.state;
    final fx0 = yawDirX(body.facing), fz0 = yawDirZ(body.facing);
    // Through his eyes the chain leaves the gun in his hand.
    final rig = world.tryResource<CameraRig>();
    final muzzle = rig != null && rig.firstPerson
        ? rig.muzzle.clone()
        : Vector3(
            t.x + fx0 * harpoonMuzzleForward,
            t.y + harpoonMuzzleHeight,
            t.z + fz0 * harpoonMuzzleForward,
          );

    // The shot: kick, flash, smoke and sparks out of the muzzle.
    final fired = state == HarpoonMode.flying && !visual.rope.live;
    if (fired) {
      visual
        ..recoil = 1
        ..retract = 0;
      visual.rope
        ..reset(muzzle)
        ..live = true;
      final dir = harpoon.velocity.normalized();
      fx
        ?..burst(FxKind.flash, muzzle + dir * 0.4, count: 1, size: 1.3)
        ..burst(FxKind.spark, muzzle + dir * 0.3, count: 16, dir: dir,
            spread: 0.35, speed: 1.2)
        ..burst(FxKind.smoke, muzzle + dir * 0.3, count: 5, dir: dir,
            spread: 0.5, speed: 0.8, size: 0.5, life: 0.6);
    }
    visual.recoil = smoothTo(visual.recoil, 0, dt, harpoonRecoilHalfLife);
    if (model.gun case final gun?) {
      final rest = visual.gunRest ??= gun.localTransform.clone();
      gun
        ..visible = true
        ..localTransform = rest.clone()
        ..mutateLocalTransform((m) => m
          ..translateByDouble(0, 0, -harpoonGunKick * visual.recoil, 1)
          ..rotateX(-harpoonGunPitch * visual.recoil));
    }

    final out = state == HarpoonMode.flying || state == HarpoonMode.reeling;
    visual.bolt.visible = out;
    if (out) {
      final dir = state == HarpoonMode.flying
          ? harpoon.velocity.normalized()
          : (harpoon.bolt - muzzle).normalized();
      if (dir.length2 > 0.5) {
        visual.bolt.localTransform = Matrix4.compose(
          harpoon.bolt,
          Quaternion.fromTwoVectors(Vector3(0, 0, -1), dir),
          Vector3.all(harpoonVisualScale),
        );
      }
    }

    // The chain's far end: the bolt, or winding back to the gun.
    final rope = visual.rope;
    if (!rope.live) {
      for (final link in visual.links) {
        link.visible = false;
      }
      return;
    }
    Vector3 end;
    double slack;
    if (out) {
      end = harpoon.bolt.clone();
      slack = switch (state) {
        HarpoonMode.reeling => harpoon.hooked == null
            ? harpoonChainSlackHooked
            : harpoonChainSlackReeling,
        _ => harpoonChainSlackFlying,
      };
    } else {
      visual.retract += dt;
      final f = (visual.retract / harpoonChainRetractSeconds).clamp(0.0, 1.0);
      end = rope.points.last + (muzzle - rope.points.last) * (f * f);
      slack = 1.0;
      if (f >= 1) {
        rope.live = false;
        for (final link in visual.links) {
          link.visible = false;
        }
        return;
      }
    }
    final span = (end - muzzle).length;
    final segment = math.max(span * slack, 0.05) / (rope.count - 1);
    // Small fixed sub-steps keep the rope stable through hitches.
    var left = math.min(dt, 0.05);
    while (left > 1e-5) {
      final h = math.min(left, 1 / 120);
      rope.step(h, muzzle, end, segment, ground);
      left -= h;
    }

    // A link on every segment, along it, each turned a quarter from the
    // last so it reads as chain.
    for (var i = 0; i < visual.links.length; i++) {
      final a = rope.points[i], b = rope.points[i + 1];
      final d = b - a;
      final len = d.length;
      final link = visual.links[i];
      if (len < 1e-4) {
        link.visible = false;
        continue;
      }
      final along = Quaternion.fromTwoVectors(Vector3(0, 0, 1), d / len);
      final twist = Quaternion.axisAngle(Vector3(0, 0, 1), i.isEven ? 0 : math.pi / 2);
      link
        ..visible = true
        ..localTransform = Matrix4.compose(
          (a + b) * 0.5,
          along * twist,
          Vector3.all(harpoonVisualScale),
        );
    }
  });
}
