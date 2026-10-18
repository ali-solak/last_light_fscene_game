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
      reads: {Dart, HarpoonVisual, Pooled},
      after: [_drawHarpoon],
      runIf: hasResource<Scene>(),
    );
}

/// Render sync: darts as small bolts off the gun's rack, a streak of
/// light behind.
void _drawDarts(World world) {
  final gun = world.query<HarpoonVisual>().firstOrNull?.$2;
  final darts = gun?.darts;
  final tip = (gun?.tip ?? 0) * 0.7;
  world.query<Dart>().each((entity, dart) {
    final dir = dart.velocity.normalized();
    void place(Node node) => _placeBolt(
      node,
      dart.position - dir * tip,
      dir,
      harpoonBoltScale * 0.7,
    );
    if (world.tryGet<Pooled>(entity) case final pooled?) {
      place(pooled.node);
      return;
    }
    final node = darts?.take();
    if (node == null) return;
    // Placed before its trail forgets the last shot, so no streak.
    place(node);
    node.getComponent<TrailComponent>()?.clear();
    world
      ..add(entity, NodeRef(node))
      ..add(entity, Pooled(darts!, node));
  });
}

/// A dart: a small bolt with a short trail.
Node _dart(ModelLibrary lib) {
  final node = lib.instance('harpoon_bolt')
    ..addComponent(TrailComponent(width: 0.07, lifetime: 0.2));
  setRenderLayer(node, RenderLayers.actors);
  return node;
}

/// The bolt model's tip along its +Z (its origin is the chain's anchor).
double _boltTip(Node bolt) =>
    bolt.getChildByName('tip')?.localTransform.getTranslation().z ?? 0.9;

/// Lays a bolt with its tail at [tail], tip pointing along unit [dir].
void _placeBolt(Node bolt, Vector3 tail, Vector3 dir, double scale) {
  bolt.localTransform = Matrix4.compose(
    tail,
    Quaternion.fromTwoVectors(Vector3(0, 0, 1), dir),
    Vector3.all(scale),
  );
}

/// Render sync: the gun kicks on a shot (muzzle flash, smoke, sparks), the
/// bolt flies tip first with its trail and light, and the chain is a verlet
/// rope from the gun to the bolt's tail: loose and swinging while it pays
/// out, lying on the sand, drawing in on the reel, then winding back and
/// dragging the bolt home.
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
      final tip = _boltTip(bolt) * harpoonBoltScale;
      final links = <Node>[
        for (var i = 0; i < harpoonChainPoints - 1; i++)
          lib.instance('chain_link')..visible = false,
      ];
      root.addAll(links);
      setRenderLayer(root, RenderLayers.actors);
      world.spawn([NodeRef(root)], ownedBy: entity);
      final darts = mountRack(world, 'darts', () => _dart(lib),
          size: harpoonDartRack);
      world.add(
        entity,
        HarpoonVisual(bolt, tip, links, ChainRope(harpoonChainPoints), darts),
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

    // The shot: kick, flash, smoke and sparks out of the muzzle. A shot
    // while the last chain still winds in starts it afresh.
    final rope = visual.rope;
    final fired =
        state == HarpoonMode.flying && (!rope.live || visual.retract > 0);
    if (fired) {
      visual
        ..recoil = 1
        ..retract = 0
        ..slack = harpoonChainSlackFlying;
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

    if (!rope.live) {
      visual.bolt.visible = false;
      for (final link in visual.links) {
        link.visible = false;
      }
      return;
    }
    final out = state == HarpoonMode.flying || state == HarpoonMode.reeling;
    final facing = Vector3(fx0, 0, fz0);
    if (out) {
      // Out: the bolt's tip is the harpoon's point; the chain pays out to
      // its tail, the slack easing as it flies, strikes and reels.
      final dir = state == HarpoonMode.flying
          ? harpoon.velocity.normalized()
          : (harpoon.bolt - muzzle).normalized();
      if (dir.length2 < 0.5) dir.setFrom(facing);
      final tail = harpoon.bolt - dir * visual.tip;
      final slack = switch (state) {
        HarpoonMode.reeling => harpoon.hooked == null
            ? harpoonChainSlackHooked
            : harpoonChainSlackReeling,
        _ => harpoonChainSlackFlying,
      };
      visual
        ..slack = smoothTo(visual.slack, slack, dt, harpoonChainSlackHalfLife)
        ..length = math.max((tail - muzzle).length * visual.slack, 0.05);
      _stepRope(rope, dt, muzzle, tail, visual.length, ground);
      _placeBolt(visual.bolt, tail, dir, harpoonBoltScale);
    } else {
      // Done: the bolt hangs where it struck a beat (a miss just drops),
      // then is let go and the chain winds in, dragging it back over the
      // sand.
      visual.retract += dt;
      final missed = harpoon.travelled >= harpoonRange - 1e-3;
      final winding = visual.retract - (missed ? 0 : harpoonChainDwellSeconds);
      if (winding > 0) {
        final ramp = math.min(winding / harpoonChainWindRamp, 1.0);
        visual.length -= harpoonChainWindSpeed * ramp * dt;
      }
      if (visual.length <= visual.tip) {
        rope.live = false;
        visual.bolt.visible = false;
        for (final link in visual.links) {
          link.visible = false;
        }
        return;
      }
      _stepRope(
        rope,
        dt,
        muzzle,
        rope.points.last.clone(),
        visual.length,
        ground,
        pinEnd: winding <= 0,
      );
      final dir = (rope.points.last - rope.points[rope.count - 2]).normalized();
      if (dir.length2 < 0.5) dir.setFrom(facing);
      _placeBolt(visual.bolt, rope.points.last, dir, harpoonBoltScale);
    }
    visual.bolt.visible = true;

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

/// Steps [rope] of total [length] from [start] to [end] in small fixed
/// sub-steps, which keep it stable through hitches.
void _stepRope(
  ChainRope rope,
  double dt,
  Vector3 start,
  Vector3 end,
  double length,
  double Function(double x, double z) ground, {
  bool pinEnd = true,
}) {
  final segment = length / (rope.count - 1);
  var left = math.min(dt, 0.05);
  while (left > 1e-5) {
    final h = math.min(left, 1 / 120);
    rope.step(h, start, end, segment, ground, pinEnd: pinEnd);
    left -= h;
  }
}
