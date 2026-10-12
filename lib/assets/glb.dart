import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

/// A minimal, pure-Dart reader for the parts of a `.glb` gameplay needs
/// without a renderer: node transforms by name and triangle soups by mesh
/// name. Everything it returns is in engine space: the scene importer bakes
/// glTF's right-handed axes by negating Z, and this does the same.
final class GlbDocument {
  GlbDocument._(this._json, this._bin) {
    final nodes = (_json['nodes'] as List?) ?? const [];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i] as Map<String, Object?>;
      for (final child in (node['children'] as List?) ?? const []) {
        _parent[child as int] = i;
      }
      if (node['name'] case final String name) _byName[name] = i;
    }
  }

  factory GlbDocument.parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0, Endian.little) != 0x46546C67) {
      throw const FormatException('not a binary glTF');
    }
    var offset = 12;
    Map<String, Object?>? json;
    Uint8List? bin;
    while (offset + 8 <= bytes.length) {
      final length = data.getUint32(offset, Endian.little);
      final type = data.getUint32(offset + 4, Endian.little);
      final chunk = Uint8List.sublistView(bytes, offset + 8, offset + 8 + length);
      switch (type) {
        case 0x4E4F534A:
          json = jsonDecode(utf8.decode(chunk)) as Map<String, Object?>;
        case 0x004E4942:
          bin = chunk;
      }
      offset += 8 + length;
    }
    if (json == null) throw const FormatException('glb has no JSON chunk');
    return GlbDocument._(json, bin ?? Uint8List(0));
  }

  final Map<String, Object?> _json;
  final Uint8List _bin;
  final Map<int, int> _parent = {};
  final Map<String, int> _byName = {};

  static final Matrix4 _flip = Matrix4.diagonal3Values(1, 1, -1);

  Iterable<String> get nodeNames => _byName.keys;

  bool hasNode(String name) => _byName.containsKey(name);

  /// The node's world transform in engine space, or null if absent.
  Matrix4? worldTransform(String name) {
    final index = _byName[name];
    if (index == null) return null;
    return _flip * _gltfWorld(index) * _flip;
  }

  /// The node's world position in engine space, or null if absent.
  Vector3? position(String name) => worldTransform(name)?.getTranslation();

  /// The node's yaw about +Y in engine space.
  double yaw(String name) {
    final m = worldTransform(name);
    if (m == null) return 0;
    // Local −Z (the authored forward) in world space.
    final f = m.transform3(Vector3(0, 0, -1)) - m.getTranslation();
    return math.atan2(-f.x, -f.z);
  }

  /// Every triangle of the first node using mesh [meshName], in world
  /// engine space, as packed xyz triplets (9 floats per triangle).
  Float32List triangles(String meshName) {
    final meshes = (_json['meshes'] as List?) ?? const [];
    final meshIndex = meshes.indexWhere(
      (m) => (m as Map<String, Object?>)['name'] == meshName,
    );
    if (meshIndex < 0) return Float32List(0);
    final nodes = (_json['nodes'] as List?) ?? const [];
    final nodeIndex = nodes.indexWhere(
      (n) => (n as Map<String, Object?>)['mesh'] == meshIndex,
    );
    final world = nodeIndex < 0
        ? Matrix4.identity()
        : _flip * _gltfWorld(nodeIndex) * _flip;
    final out = <double>[];
    final v = Vector3.zero();
    final primitives =
        (meshes[meshIndex] as Map<String, Object?>)['primitives'] as List;
    for (final p in primitives.cast<Map<String, Object?>>()) {
      final attributes = p['attributes'] as Map<String, Object?>;
      final positions = _accessor(attributes['POSITION'] as int);
      final indices = p['indices'] is int
          ? _accessor(p['indices'] as int)
          : List<double>.generate(positions.length ~/ 3, (i) => i.toDouble());
      for (final index in indices) {
        final i = index.toInt() * 3;
        // glTF → engine: negate Z, then apply the (already flipped) world.
        v.setValues(positions[i], positions[i + 1], -positions[i + 2]);
        world.transform3(v);
        out
          ..add(v.x)
          ..add(v.y)
          ..add(v.z);
      }
    }
    return Float32List.fromList(out);
  }

  /// The mean texture U of every triangle of mesh [meshName], in the same
  /// order as [triangles]: which palette column it is painted with.
  Float32List triangleUs(String meshName) {
    final meshes = (_json['meshes'] as List?) ?? const [];
    final mesh = meshes.cast<Map<String, Object?>>().where(
      (m) => m['name'] == meshName,
    ).firstOrNull;
    if (mesh == null) return Float32List(0);
    final out = <double>[];
    for (final p in (mesh['primitives'] as List).cast<Map<String, Object?>>()) {
      final attributes = p['attributes'] as Map<String, Object?>;
      final uvIndex = attributes['TEXCOORD_0'];
      final count = _accessorCount(attributes['POSITION'] as int);
      final uvs = uvIndex is int ? _accessor(uvIndex) : null;
      final indices = p['indices'] is int
          ? _accessor(p['indices'] as int)
          : List<double>.generate(count, (i) => i.toDouble());
      for (var k = 0; k + 2 < indices.length; k += 3) {
        if (uvs == null) {
          out.add(0);
          continue;
        }
        var u = 0.0;
        for (var c = 0; c < 3; c++) {
          u += uvs[indices[k + c].toInt() * 2];
        }
        out.add(u / 3);
      }
    }
    return Float32List.fromList(out);
  }

  int _accessorCount(int index) =>
      ((_json['accessors'] as List)[index] as Map<String, Object?>)['count']
          as int;

  Matrix4 _gltfWorld(int index) {
    var m = _gltfLocal(index);
    for (var p = _parent[index]; p != null; p = _parent[p]) {
      m = _gltfLocal(p) * m;
    }
    return m;
  }

  Matrix4 _gltfLocal(int index) {
    final node = (_json['nodes'] as List)[index] as Map<String, Object?>;
    if (node['matrix'] case final List m) {
      return Matrix4.fromList([for (final x in m) (x as num).toDouble()]);
    }
    final t = _vec(node['translation'], 3, 0);
    final r = node['rotation'] == null
        ? const [0.0, 0.0, 0.0, 1.0]
        : _vec(node['rotation'], 4, 0);
    final s = _vec(node['scale'], 3, 1);
    return Matrix4.compose(
      Vector3(t[0], t[1], t[2]),
      Quaternion(r[0], r[1], r[2], r[3]),
      Vector3(s[0], s[1], s[2]),
    );
  }

  static List<double> _vec(Object? raw, int n, double fill) => switch (raw) {
    final List l => [for (final x in l) (x as num).toDouble()],
    _ => List<double>.filled(n, fill),
  };

  List<double> _accessor(int index) {
    final accessor =
        (_json['accessors'] as List)[index] as Map<String, Object?>;
    final view =
        (_json['bufferViews'] as List)[accessor['bufferView'] as int]
            as Map<String, Object?>;
    final count = accessor['count'] as int;
    final components = switch (accessor['type']) {
      'SCALAR' => 1,
      'VEC2' => 2,
      'VEC3' => 3,
      'VEC4' => 4,
      _ => throw FormatException('accessor type ${accessor['type']}'),
    };
    final (size, read) = switch (accessor['componentType']) {
      5126 => (4, (ByteData d, int o) => d.getFloat32(o, Endian.little)),
      5125 => (4, (ByteData d, int o) => d.getUint32(o, Endian.little).toDouble()),
      5123 => (2, (ByteData d, int o) => d.getUint16(o, Endian.little).toDouble()),
      5121 => (1, (ByteData d, int o) => d.getUint8(o).toDouble()),
      _ => throw FormatException('component ${accessor['componentType']}'),
    };
    final base =
        ((view['byteOffset'] as int?) ?? 0) +
        ((accessor['byteOffset'] as int?) ?? 0);
    final stride = (view['byteStride'] as int?) ?? size * components;
    final data = ByteData.sublistView(_bin);
    return [
      for (var i = 0; i < count; i++)
        for (var c = 0; c < components; c++)
          read(data, base + i * stride + c * size),
    ];
  }
}
