part of '../fx.dart';

/// The particle textures, baked once on the CPU at boot (no image assets):
/// a soft dot for sparks, embers and glows, a 4×4 smoke flipbook, an 8×8
/// flame flipbook. Absent headless.
final class FxTextures(
  final TextureSource dot,
  final TextureSource smoke,
  final TextureSource flame,
);

/// Bakes every particle texture.
Future<FxTextures> loadFxTextures() async {
  Future<TextureSource> upload(Future<ui.Image> image) async =>
      GpuTextureSource(await gpuTextureFromImage(await image));
  final (dot, smoke, flame) = await (
    upload(_bakeSoftDot()),
    upload(_bakeSmokeAtlas()),
    upload(_bakeFlameAtlas()),
  ).wait;
  return FxTextures(dot, smoke, flame);
}

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Black → deep red → orange → yellow → white, by temperature 0..1.
(double, double, double) _blackbody(double temp) {
  const stops = <(double, double, double, double)>[
    (0.0, 0.0, 0.0, 0.0),
    (0.20, 0.32, 0.02, 0.0),
    (0.45, 0.85, 0.22, 0.01),
    (0.70, 1.0, 0.62, 0.10),
    (0.88, 1.0, 0.86, 0.42),
    (1.0, 1.0, 0.98, 0.82),
  ];
  final t = temp.clamp(0.0, 1.0);
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i].$1) {
      final (a0, ar, ag, ab) = stops[i - 1];
      final (b0, br, bg, bb) = stops[i];
      final f = (t - a0) / (b0 - a0);
      return (ar + (br - ar) * f, ag + (bg - ag) * f, ab + (bb - ab) * f);
    }
  }
  return (1.0, 0.98, 0.82);
}

Future<ui.Image> _image(Uint8List pixels, int size) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    size,
    size,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

/// A white dot with a Gaussian falloff that reaches zero at the rim.
Future<ui.Image> _bakeSoftDot() {
  const size = 64;
  final pixels = Uint8List(size * size * 4);
  const half = size / 2;
  const sigma = size * 0.2;
  final rim = math.exp(-0.5 * (half / sigma) * (half / sigma));
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x + 0.5 - half, dy = y + 0.5 - half;
      final r = math.sqrt(dx * dx + dy * dy);
      final g = math.exp(-0.5 * (r / sigma) * (r / sigma));
      final a = ((g - rim) / (1 - rim)).clamp(0.0, 1.0);
      final i = (y * size + x) * 4;
      pixels
        ..[i] = 255
        ..[i + 1] = 255
        ..[i + 2] = 255
        ..[i + 3] = (a * 255).round();
    }
  }
  return _image(pixels, size);
}

/// 4×4 billowing puffs, eaten away by a rising erosion threshold so old
/// smoke tears apart instead of fading uniformly.
Future<ui.Image> _bakeSmokeAtlas() async {
  const grid = 4, cell = 96, size = grid * cell, frames = grid * grid;
  final pixels = Uint8List(size * size * 4);
  final noise = FastNoiseLite()
    ..seed = 17
    ..frequency = 1.0
    ..fractalType = FractalType.fbm
    ..octaves = 4;
  for (var f = 0; f < frames; f++) {
    final t = f / (frames - 1);
    final evolve = f * 0.22;
    final erosion = 0.18 + 0.55 * _smooth(0.2, 1.0, t);
    final cellX = (f % grid) * cell, cellY = (f ~/ grid) * cell;
    for (var py = 0; py < cell; py++) {
      final y = ((py + 0.5) / cell) * 2 - 1;
      final row = ((cellY + py) * size + cellX) * 4;
      for (var px = 0; px < cell; px++) {
        final x = ((px + 0.5) / cell) * 2 - 1;
        final base = (1 - (x * x + y * y)).clamp(0.0, 1.0);
        final billow = 1 - noise.getNoise3(x * 1.9, y * 1.9, evolve).abs();
        final density = base * (0.35 + 0.65 * billow * billow);
        final value = ((density - erosion) / 0.42).clamp(0.0, 1.0) *
            (1 - 0.45 * _smooth(0.5, 1.0, t));
        final shade = ((0.62 + 0.38 * billow) * (0.85 - 0.15 * y))
            .clamp(0.0, 1.0);
        final v = (shade * 255).round();
        final o = row + px * 4;
        pixels
          ..[o] = v
          ..[o + 1] = v
          ..[o + 2] = v
          ..[o + 3] = (value * 255).round();
      }
    }
    if (f % 4 == 3) await Future<void>.delayed(Duration.zero);
  }
  return _image(pixels, size);
}

/// 8×8 flame tongues over one lifetime: grows in, licks and splits on a
/// domain warp, lifts off and cools through blackbody colours.
Future<ui.Image> _bakeFlameAtlas() async {
  const grid = 8, cell = 64, size = grid * cell, frames = grid * grid;
  final pixels = Uint8List(size * size * 4);
  final warp = FastNoiseLite()
    ..seed = 7
    ..frequency = 1.0
    ..fractalType = FractalType.fbm
    ..octaves = 3;
  final main = FastNoiseLite()
    ..seed = 8
    ..frequency = 1.0
    ..fractalType = FractalType.fbm
    ..octaves = 3;
  for (var f = 0; f < frames; f++) {
    final t = f / (frames - 1);
    final evolve = f * 0.055, scroll = f * 0.10;
    final grow = _smooth(0, 0.18, t);
    final baseY = 0.5 * math.pow(_smooth(0.4, 1, t), 1.2);
    final height = 0.92 * (0.3 + 0.7 * grow) * (1 - 0.35 * _smooth(0.5, 1, t));
    final erosion = 0.12 + 0.55 * _smooth(0.35, 1, t);
    final cooling = 1 - 0.4 * _smooth(0.45, 1, t);
    final cellX = (f % grid) * cell, cellY = (f ~/ grid) * cell;
    for (var py = 0; py < cell; py++) {
      final y = 1 - (py + 0.5) / cell;
      final row = ((cellY + py) * size + cellX) * 4;
      for (var px = 0; px < cell; px++) {
        final x = ((px + 0.5) / cell) * 2 - 1;
        var value = 0.0, detail = 0.5;
        final h = height > 0 ? (y - baseY) / height : -1.0;
        if (h >= 0 && h <= 1) {
          final w = warp.getNoise3(x * 2.2, y * 2.2 - scroll * 1.6, evolve + 37.7);
          final xw = x + w * 0.3 * (0.35 + 0.65 * h);
          final halfW = 0.52 *
              (1 - 0.3 * t) *
              math.pow(1 - h, 0.65) *
              (0.3 + 0.7 * _smooth(0, 0.18, h));
          if (halfW > 1e-4) {
            final d = (xw / halfW).abs();
            final radial = (1 - d * d).clamp(0.0, 1.0);
            final n = main.getNoise3(xw * 2.6, y * 3.2 - scroll * 2.2, evolve) *
                    0.5 +
                0.5;
            value = ((radial * (0.45 + 0.55 * n) * 1.35 - erosion - 0.3 * h) /
                    0.22)
                .clamp(0.0, 1.0);
            detail = n;
          }
        }
        final temp = (value *
                (1.12 - 0.45 * h.clamp(0.0, 1.0)) *
                (0.68 + 0.55 * detail) *
                cooling)
            .clamp(0.0, 1.0);
        final (r, g, b) = _blackbody(temp);
        final o = row + px * 4;
        pixels
          ..[o] = (r * 255).round()
          ..[o + 1] = (g * 255).round()
          ..[o + 2] = (b * 255).round()
          ..[o + 3] = ((value * 1.45).clamp(0.0, 1.0) * 255).round();
      }
    }
    if (f % 8 == 7) await Future<void>.delayed(Duration.zero);
  }
  return _image(pixels, size);
}
