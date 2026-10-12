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

/// Asset key → source path. Keys are the file names without `.glb`, which
/// is also how `clips.json` keys them (minus the extension).
const Map<String, String> modelPaths = {
  'keeper': 'assets/models/characters/keeper.glb',
  'scuttler': 'assets/models/enemies/scuttler.glb',
  'tarback': 'assets/models/enemies/tarback.glb',
  'basher': 'assets/models/enemies/basher.glb',
  'snuffer': 'assets/models/enemies/snuffer.glb',
  'burrower': 'assets/models/enemies/burrower.glb',
  'moth_crab': 'assets/models/enemies/moth_crab.glb',
  'glassback': 'assets/models/enemies/glassback.glb',
  'tide_mother': 'assets/models/enemies/tide_mother.glb',
  'sand_mound': 'assets/models/enemies/sand_mound.glb',
  'oil_lamp': 'assets/models/weapons/oil_lamp.glb',
  'harpoon_gun': 'assets/models/weapons/harpoon_gun.glb',
  'harpoon_bolt': 'assets/models/weapons/harpoon_bolt.glb',
  'chain_link': 'assets/models/weapons/chain_link.glb',
  'mirror': 'assets/models/placeables/mirror.glb',
  'lamp_post': 'assets/models/placeables/lamp_post.glb',
  'prism': 'assets/models/placeables/prism.glb',
  'bell': 'assets/models/placeables/bell.glb',
  'island': 'assets/models/environment/island.glb',
  'lighthouse': 'assets/models/environment/lighthouse.glb',
  'cottage': 'assets/models/environment/cottage.glb',
  'dock': 'assets/models/environment/dock.glb',
  'rocks_a': 'assets/models/environment/rocks_a.glb',
  'rocks_b': 'assets/models/environment/rocks_b.glb',
  'rocks_c': 'assets/models/environment/rocks_c.glb',
  'crate': 'assets/models/environment/crate.glb',
  'barrel': 'assets/models/environment/barrel.glb',
  'buoy': 'assets/models/environment/buoy.glb',
  'driftwood_a': 'assets/models/environment/driftwood_a.glb',
  'driftwood_b': 'assets/models/environment/driftwood_b.glb',
  'fishing_net': 'assets/models/environment/fishing_net.glb',
  'fence_section': 'assets/models/environment/fence_section.glb',
  'grass_tuft': 'assets/models/environment/grass_tuft.glb',
  'beam_cone': 'assets/models/fx/beam_cone.glb',
  'lamp_cone': 'assets/models/fx/lamp_cone.glb',
  'tar_splat': 'assets/models/fx/tar_splat.glb',
  'burn_puddle': 'assets/models/fx/burn_puddle.glb',
  'flame_card': 'assets/models/fx/flame_card.glb',
};

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

  /// Depth-first lookup by node name under [root], [root] included.
  Node? find(Node root, String name) {
    if (root.name == name) return root;
    for (final child in root.children) {
      final hit = find(child, name);
      if (hit != null) return hit;
    }
    return null;
  }
}

/// Loads every model, its animations and `clips.json`.
Future<ModelLibrary> loadModelLibrary() async {
  final clips = parseClipBook(
    await rootBundle.loadString('assets/models/clips.json'),
  );
  final entries = await Future.wait([
    for (final MapEntry(:key, :value) in modelPaths.entries)
      loadScene(value).then((node) => (key, node)),
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
