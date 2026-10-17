import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';

/// One clip's authored timing from `clips.json`.
final class const ClipInfo(
  final double seconds,
  final bool loop, {
  final double? eventAt,
  final bool holdLastFrame = false,
});

/// Every model the game loads, by source path. The build hook converts
/// every `.glb` under `assets/`; an asset's key is its file name without
/// `.glb`, which is also how `clips.json` keys it.
const List<String> modelSources = [
  'assets/models/characters/keeper.glb',
  'assets/models/enemies/scuttler.glb',
  'assets/models/enemies/tarback.glb',
  'assets/models/enemies/basher.glb',
  'assets/models/enemies/snuffer.glb',
  'assets/models/enemies/burrower.glb',
  'assets/models/enemies/moth_crab.glb',
  'assets/models/enemies/glassback.glb',
  'assets/models/enemies/tide_mother.glb',
  'assets/models/enemies/sand_mound.glb',
  'assets/models/weapons/oil_lamp.glb',
  'assets/models/weapons/harpoon_gun.glb',
  'assets/models/weapons/harpoon_bolt.glb',
  'assets/models/weapons/chain_link.glb',
  'assets/models/placeables/mirror.glb',
  'assets/models/placeables/lamp_post.glb',
  'assets/models/placeables/prism.glb',
  'assets/models/placeables/bell.glb',
  'assets/models/environment/island.glb',
  'assets/models/environment/lighthouse.glb',
  'assets/models/environment/cottage.glb',
  'assets/models/environment/dock.glb',
  'assets/models/environment/rocks_a.glb',
  'assets/models/environment/rocks_b.glb',
  'assets/models/environment/rocks_c.glb',
  'assets/models/environment/crate.glb',
  'assets/models/environment/barrel.glb',
  'assets/models/environment/buoy.glb',
  'assets/models/environment/driftwood_a.glb',
  'assets/models/environment/driftwood_b.glb',
  'assets/models/environment/fishing_net.glb',
  'assets/models/environment/fence_section.glb',
  'assets/models/environment/grass_tuft.glb',
  'assets/models/fx/beam_cone.glb',
  'assets/models/fx/lamp_cone.glb',
  'assets/models/fx/tar_splat.glb',
  'assets/models/fx/burn_puddle.glb',
  'assets/models/fx/flame_card.glb',
];

/// An asset's key: its file name without `.glb`.
String modelKey(String source) =>
    source.substring(source.lastIndexOf('/') + 1).replaceAll('.glb', '');

/// Parses `clips.json`: asset file name → clip name → timing.
Map<String, Map<String, ClipInfo>> parseClipBook(String source) {
  final json = jsonDecode(source) as Map<String, Object?>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key.replaceAll('.glb', ''): {
        for (final MapEntry(key: clip, value: raw)
            in (value as Map<String, Object?>).entries)
          if (raw case {'seconds': final num seconds, 'loop': final bool loop})
            clip: ClipInfo(
              seconds.toDouble(),
              loop,
              eventAt: ((raw as Map)['event_frame_s'] as num?)?.toDouble(),
              holdLastFrame: raw['hold_last_frame'] == true,
            ),
      },
  };
}

/// Every loaded model: one template [Node] per asset, one animation map per
/// asset, and the `clips.json` timing. Gameplay reads only [clipInfo], so a
/// headless library ([ModelLibrary.headless]) carries timing and no nodes.
final class ModelLibrary(
  final Map<String, Node> _templates,
  final Map<String, Map<String, Animation>> _animations,
  final Map<String, Map<String, ClipInfo>> _clips,
) {
  new headless(Map<String, Map<String, ClipInfo>> clips) : this({}, {}, clips);

  bool get hasModels => _templates.isNotEmpty;

  bool has(String asset) => _templates.containsKey(asset);

  /// Every loaded asset key.
  Iterable<String> get assets => _templates.keys;

  /// A fresh clone of [asset]'s template.
  Node instance(String asset) {
    final template = _templates[asset];
    if (template == null) throw StateError('model "$asset" is not loaded');
    return template.clone();
  }

  /// The asset's animations by name (from its `parsedAnimations`).
  Map<String, Animation> animations(String asset) =>
      _animations[asset] ?? const {};

  /// The asset's clip timings by name.
  Map<String, ClipInfo> clipInfo(String asset) => _clips[asset] ?? const {};

  /// One clip's timing, or null.
  ClipInfo? clip(String asset, String name) => _clips[asset]?[name];

  /// The clip's length in seconds, or [fallback] if the asset lacks it.
  double seconds(String asset, String name, {double fallback = 0.5}) =>
      _clips[asset]?[name]?.seconds ?? fallback;

}

/// Loads every model, its animations and `clips.json`.
Future<ModelLibrary> loadModelLibrary() async {
  final clips = parseClipBook(
    await rootBundle.loadString('assets/models/clips.json'),
  );
  final entries = await Future.wait([
    for (final source in modelSources)
      loadScene(source).then((node) => (modelKey(source), node)),
  ]);
  final templates = <String, Node>{};
  final animations = <String, Map<String, Animation>>{};
  for (final (key, node) in entries) {
    templates[key] = node;
    animations[key] = {
      for (final animation in _collectAnimations(node))
        animation.name: animation,
    };
    final authored = clips[key]?.keys ?? const <String>[];
    for (final name in authored) {
      if (!animations[key]!.containsKey(name)) {
        debugPrint('last_light: $key has no clip "$name" (clips.json lists it)');
      }
    }
  }
  return ModelLibrary(templates, animations, clips);
}

Iterable<Animation> _collectAnimations(Node node) sync* {
  yield* node.parsedAnimations;
  for (final child in node.children) {
    yield* _collectAnimations(child);
  }
}
