part of '../island.dart';

/// Shared `.fmat` materials, one instance each.
const List<String> materialNames = [
  'sea',
  'wet_sand',
  'grass_sway',
  'beam',
  'flame',
  'lamp_glass',
  'crab_shell',
  'ground_fog',
  'burn',
  'grass_fire',
];

/// Per-entity materials and how many instances to pre-load. Never used for
/// hordes: tarbacks, mirrors, corpses (capped) and glass shells only.
const Map<String, int> materialPools = {
  'tar': 10,
  'mirror': 10,
  'dissolve_sink': 40,
  'crystal': 8,
  'lamp_glass': 16,
  'beam': 20,
  'beam_ground': 16,
  'burn': 6,
};

/// Loads every material, logging (once) and skipping any that fail, so the
/// game runs on the GLB palette materials alone.
Future<Materials> loadMaterials() async {
  final FmatMaterialRegistry registry;
  try {
    registry = await FmatMaterialRegistry.load();
  } catch (error) {
    debugPrint('last_light: no .fmat materials ($error); using palettes');
    return Materials({}, {}, null);
  }

  Future<PreprocessedMaterial?> one(String name) async {
    try {
      return await registry.loadMaterial('assets/materials/$name.fmat');
    } catch (error) {
      debugPrint('last_light: material $name failed to load: $error');
      return null;
    }
  }

  final shared = <String, PreprocessedMaterial>{};
  for (final name in materialNames) {
    if (await one(name) case final material?) shared[name] = material;
  }
  final pools = <String, List<PreprocessedMaterial>>{};
  for (final MapEntry(key: name, value: count) in materialPools.entries) {
    for (var i = 0; i < count; i++) {
      final material = await one(name);
      if (material == null) break;
      (pools[name] ??= []).add(material);
    }
  }
  PreprocessedSky? sky;
  try {
    sky = await registry.loadSky('assets/materials/sky.fmat');
  } catch (error) {
    debugPrint('last_light: sky.fmat failed to load: $error');
  }
  final materials = Materials(shared, pools, sky);
  materials.live
    ..addAll(shared.values)
    ..addAll([for (final pool in pools.values) ...pool]);
  return materials;
}

/// Sets [material] on every mesh primitive of the node named [nodeName]
/// under [root]. Lit materials that declare a `palette` sampler inherit the
/// GLB's palette texture so the model keeps its colours.
bool assign(ModelLibrary lib, Node root, String nodeName, Material material) {
  final node = lib.find(root, nodeName);
  if (node == null) return false;
  assignNode(node, material);
  return true;
}

/// [assign] for a node already in hand (no recursion into children).
void assignNode(Node node, Material material) {
  final mesh = node.mesh;
  if (mesh == null) return;
  for (final primitive in mesh.primitives) {
    if (material is PreprocessedMaterial &&
        material.parameters.hasSampler('palette')) {
      final old = primitive.material;
      if (old is PhysicallyBasedMaterial) {
        final texture = old.baseColorTexture?.sampledTexture;
        if (texture != null) material.parameters.setTexture('palette', texture);
      }
    }
    primitive.material = material;
  }
}

/// Assigns [material] to [root] and every mesh below it.
void assignTree(Node root, Material material) {
  assignNode(root, material);
  for (final child in root.children) {
    assignTree(child, material);
  }
}

/// A see-through stand-in for a light volume when `beam.fmat` is missing:
/// light cones must never render as solid geometry.
Material lightVolumeFallback({double alpha = 0.07}) => UnlitMaterial()
  ..baseColorFactor = Vector4(1.0, 0.82, 0.55, alpha)
  ..alphaMode = AlphaMode.blend;

/// Writes a float parameter if the material declares it.
void setParam(MaterialParameters parameters, String name, double value) {
  if (parameters.hasParameter(name)) parameters.setFloat(name, value);
}

/// Writes a vec3 parameter if the material declares it.
void setParam3(MaterialParameters parameters, String name, Vector3 value) {
  if (parameters.hasParameter(name)) parameters.setVec3(name, value);
}

/// Writes a vec4 parameter if the material declares it.
void setParam4(MaterialParameters parameters, String name, Vector4 value) {
  if (parameters.hasParameter(name)) parameters.setVec4(name, value);
}
