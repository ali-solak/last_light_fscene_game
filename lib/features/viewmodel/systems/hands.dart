part of '../viewmodel.dart';

void installHands(GameBuilder game) {
  final visual = hasResource<Scene>().and(hasResource<ModelLibrary>());
  game
    ..addSystem(
      Schedules.renderSync,
      _spawnHands,
      reads: {Hands},
      runIf: visual.and(_noHands),
      before: [_poseHands],
    )
    ..addSystem(
      Schedules.renderSync,
      _poseHands,
      writes: {Hands},
      reads: {Harpoon, Lantern, KeeperBrain, Keeper},
      runIf: visual.and(_firstPerson),
    )
    ..addSystem(
      Schedules.renderSync,
      _followHands,
      writes: {Hands},
      runIf: visual.and(_firstPerson),
      after: [_poseHands],
    )
    ..addSystem(
      Schedules.renderSync,
      _placeHands,
      writes: {Hands},
      reads: {Lantern, Keeper},
      runIf: visual,
      after: [_followHands],
    );
}

bool _noHands(World world) => world.query<Hands>().firstOrNull == null;

bool _firstPerson(World world) => world.resource<CameraRig>().firstPerson;

/// Pose goals from what the keeper is doing, eased by the hands' tweens.
void _poseHands(World world) {
  final keeper = world
      .query3<Harpoon, Lantern, KeeperBrain>()
      .having<Keeper>()
      .firstOrNull;
  if (keeper == null) return;
  final (_, harpoon, lantern, brain) = keeper;
  world.query<Hands>().each((_, hands) {
    hands.aim.ease(switch (brain.mode.state) {
      .aiming || .reeling => 1,
      _ => 0,
    });
    hands.raise.ease(lantern.focusing ? 1 : 0);
    hands.reload.ease(harpoon.mode.state == HarpoonMode.reloading ? 1 : 0);
    hands.gone.ease(lantern.lit ? 0 : 1);
    hands.dry.ease(lantern.oil <= 0 ? 1 : 0);
    for (final pose in hands.poses) {
      pose.tick(world.delta);
    }
  });
}

/// Motion that follows the view and the gun: the hands trail a turn and
/// settle back, and a shot kicks the gun.
void _followHands(World world) {
  final rig = world.resource<CameraRig>();
  final dt = world.delta;
  final fired = world.events<HarpoonFired>().isNotEmpty;
  world.query<Hands>().each((_, hands) {
    final turn = Vector2(
      -angleBetweenYaw(hands.lastYaw, rig.yaw),
      rig.pitch - hands.lastPitch,
    );
    hands
      ..lastYaw = rig.yaw
      ..lastPitch = rig.pitch
      ..time += dt
      ..kick = smoothTo(fired ? 1 : hands.kick, 0, dt, handKickHalfLife);
    hands.sway
      ..addScaled(turn, handSway)
      ..clamp(Vector2.all(-handSwayMax), Vector2.all(handSwayMax))
      ..scale(smoothTo(1, 0, dt, handSwayHalfLife));
  });
}

/// The hands in front of the eye, shown only in first person; and where
/// the chain leaves the gun, for the harpoon's visuals.
void _placeHands(World world) {
  final rig = world.resource<CameraRig>();
  // The swing: 0 at rest, rising and falling over the bash.
  final bash = world.query<Lantern>().having<Keeper>().firstOrNull?.$2.bashTime ?? 0;
  final swing = bash <= 0 ? 0.0 : math.sin((1 - bash / lanternBashSwing) * math.pi);
  world.query<Hands>().each((_, hands) {
    hands.gun.visible = rig.firstPerson;
    hands.lamp.visible = rig.firstPerson && hands.gone.value < 0.98;
    if (!rig.firstPerson) return;

    final eye = _Eye(rig);
    final bob = eye.local(rig.bob)..scale(handBob);
    final sway = Vector3(hands.sway.x, hands.sway.y, 0);

    final gun = _mix3(handGunRest, handGunAim, hands.aim.value)
      ..add((handGunReload - handGunRest) * hands.reload.value)
      ..add(sway)
      ..z -= handKickBack * hands.kick
      ..add(bob * (1 - 0.7 * hands.aim.value));
    hands.gun.localTransform = eye.pose(
      gun,
      pitch: -handKickPitch * hands.kick + 0.6 * hands.reload.value,
      roll: -0.5 * hands.reload.value,
      scale: handGunScale,
    );

    final lamp = _mix3(handLampRest, handLampRaised, hands.raise.value)
      ..add((handLampGone - handLampRest) * hands.gone.value)
      ..add(sway * 1.3)
      ..add(bob)
      ..add(handLampSwing * swing)
      ..y += 0.006 * math.sin(hands.time * 2.1);
    hands.lamp.localTransform = eye.pose(
      lamp,
      pitch: -handLampSwingPitch * swing,
      roll: 0.08 * math.sin(hands.time * 1.7) + hands.sway.x * 2 -
          handLampSwingRoll * swing,
      scale: handLampScale,
    );
    // Burning, the glow flickers; dry, it sinks to a red breathing coal.
    final dry = hands.dry.value;
    final breath = lanternDryBreath(hands.time);
    if (hands.halo case final halo?) {
      final flicker = 1 +
          handHaloFlicker *
              (math.sin(hands.time * 9.1) * 0.6 + math.sin(hands.time * 23.3) * 0.4);
      final a = (handHaloAlpha * flicker * (1 - dry) +
              handHaloDryAlpha * breath * dry) *
          (1 - hands.gone.value);
      final g = 0.5 - 0.38 * dry, b = 0.16 - 0.13 * dry;
      halo.color = Vector4(1.0 * a, g * a, b * a, a);
    }
    if (hands.glass case final glass?) {
      setParam(glass.parameters, 'intensity',
          handLampGlow * (1 - dry) + handLampDryGlow * breath * dry);
      glass.parameters.setVec3(
        'warm_color',
        lanternGlassWarm + (lanternDryGlassWarm - lanternGlassWarm) * dry,
      );
    }

    if (hands.gunMuzzle case final muzzle?) {
      rig.muzzle.setFrom(muzzle.globalTransform.getTranslation());
    }
  });
}

Vector3 _mix3(Vector3 a, Vector3 b, double t) => a + (b - a) * t;

/// The signed shortest turn from yaw [a] to yaw [b].
double angleBetweenYaw(double a, double b) {
  var d = (b - a) % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  return d;
}

/// The hands, built once: the gun and the lamp, its flame hidden (an
/// additive flame right in the eye only blinds) and its glass a warm
/// glow instead of a glare.
void _spawnHands(World world) {
  final lib = world.resource<ModelLibrary>();
  if (!lib.has('harpoon_gun') || !lib.has('oil_lamp')) return;
  final gun = lib.instance('harpoon_gun')..visible = false;
  final lamp = lib.instance('oil_lamp')..visible = false;
  lamp.getChildByName('lamp_flame')?.visible = false;
  final glass = lamp.getChildByName('lamp_glass');
  final glow = glass == null
      ? null
      : world.tryResource<Materials>()?.take('lamp_glass');
  if ((glass, glow) case (final glass?, final glow?)) {
    setParam(glow.parameters, 'intensity', handLampGlow);
    assignNode(glass, glow);
  }
  // The halo: lit air round the glass, a soft additive sprite.
  final dot = world.tryResource<FxTextures>()?.dot;
  final halo = dot == null
      ? null
      : Sprite(
          texture: dot,
          width: handHaloSize / handLampScale,
          height: handHaloSize / handLampScale,
          color: Vector4.zero(),
          blendMode: SpriteBlendMode.additive,
        );
  if (halo != null) {
    final bounds = glass?.combinedLocalBounds;
    final centre = bounds == null
        ? Vector3.zero()
        : ((bounds.min + bounds.max)..scale(0.5));
    (glass ?? lamp).add(
      Node(name: 'lamp_halo', mesh: halo.mesh)..position = centre,
    );
  }
  for (final node in [gun, lamp]) {
    _noShadow(node);
    setRenderLayer(node, RenderLayers.actors);
    world.spawn([NodeRef(node)]);
  }
  world.spawn([Hands(gun, lamp, gun.getChildByName('muzzle'), halo, glow)]);
}

void _noShadow(Node node) {
  node.shadowCastingMode = ShadowCastingMode.off;
  for (final child in node.children) {
    _noShadow(child);
  }
}
