import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_scene/scene.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import 'model_library.dart';

/// The bound animation clips of one model instance. The whole animation
/// system is this component plus [bindClips], [fadeTo] and [crossed].
final class Clips(
  final String asset,
  final Map<String, AnimationClip> byName,
  var String current,
) {
  /// The current clip's playback time last frame, for event crossing.
  double lastTime = 0;
}

/// While present, the entity's current clip is held (hit pause).
final class const HitPause() implements Tag;

/// Binds every animation of [asset] onto [model], [start] at full weight.
Clips bindClips(
  ModelLibrary lib,
  String asset,
  Node model, {
  required String start,
}) {
  final info = lib.clipInfo(asset);
  final animations = lib.animations(asset);
  if (!animations.containsKey(start)) {
    debugPrint('last_light: $asset has no start clip "$start"');
  }
  return Clips(asset, {
    for (final MapEntry(:key, :value) in animations.entries)
      key: model.createAnimationClip(value)
        ..loop = info[key]?.loop ?? false
        ..weight = key == start ? 1 : 0
        ..play(),
  }, start);
}

/// Cross-fades [c] toward clip [name] over [seconds]. A missing clip is a
/// no-op. One-shots restart when entered (or when [restart] is set).
void fadeTo(
  Clips c,
  String name,
  double dt, {
  double seconds = 0.12,
  bool restart = false,
  double speed = 1,
}) {
  final target = c.byName[name];
  if (target == null) return;
  if (c.current != name || restart) {
    c
      ..current = name
      ..lastTime = 0;
    if (restart || !target.loop) target.replay();
  }
  target.playbackTimeScale = speed;
  for (final MapEntry(:key, value: clip) in c.byName.entries) {
    clip.weight = moveToward(clip.weight, key == name ? 1 : 0, dt / seconds);
  }
}

/// True on the frame the current clip's time crosses [at].
bool crossed(Clips c, double at) {
  final clip = c.byName[c.current];
  if (clip == null) return false;
  final t = clip.playbackTime;
  final hit = c.lastTime < at && t >= at;
  c.lastTime = t;
  return hit;
}

/// Puts a pooled model's clips back to [start], for reuse.
void resetClips(Clips c, String start) {
  for (final MapEntry(:key, value: clip) in c.byName.entries) {
    clip
      ..playbackTimeScale = 1
      ..weight = key == start ? 1 : 0
      ..replay();
  }
  c
    ..current = start
    ..lastTime = 0;
}

/// The [crossed] check for gameplay, which never reads a clip: true on the
/// fixed step where a state's elapsed time passes [at]. [elapsed] is the
/// time after this step's tick, [dt] the step.
bool passedMoment(double elapsed, double dt, double at) =>
    elapsed >= at && elapsed - dt < at;
