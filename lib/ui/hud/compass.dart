import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../features/camera/camera.dart' show CameraRig;
import '../../features/island/island.dart' show IslandAnchors, SpawnPoints;
import '../../features/keeper/keeper.dart' show Keeper;
import '../../features/light/light.dart' show Brazier;
import '../theme.dart';

/// A compass strip across the top: N, E, S, W (north is the north beach)
/// sliding with the view, the lighthouse always marked so the way home is
/// never lost, a red chevron over any beach that just took a landing, and
/// the signal fires that burn.
class CompassBar extends StatefulWidget {
  const CompassBar({super.key});

  @override
  State<CompassBar> createState() => _CompassBarState();
}

class _CompassBarState extends State<CompassBar> {
  final Map<Beach, DateTime> _landings = {};

  @override
  Widget build(BuildContext context) => WorldEventListener<WaveLanded>(
    onEvent: (context, wave) {
      setState(() => _landings[wave.beach] = DateTime.now());
      Future.delayed(_landingShown, () {
        if (mounted) {
          setState(() => _landings.removeWhere(
            (_, at) => DateTime.now().difference(at) >= _landingShown,
          ));
        }
      });
    },
    child: WorldBuilder<_Bearings>(
      select: (w) => _Bearings.of(w, _landings.keys.toSet()),
      builder: (context, bearings) => SizedBox(
        width: _width,
        height: 34,
        child: CustomPaint(painter: _CompassPainter(bearings)),
      ),
    ),
  );
}

const Duration _landingShown = Duration(seconds: 8);
const double _width = 420;

/// Half the strip spans this much turn either side of straight ahead.
const double _span = math.pi * 0.5;

/// What the strip shows: the view's heading and the bearings (relative to
/// it) of the lighthouse, landing beaches and lit braziers.
final class _Bearings {
  _Bearings(this.heading, this.lighthouse, this.landings, this.fires);

  final double heading;
  final double? lighthouse;
  final List<double> landings;
  final List<double> fires;

  static _Bearings of(World w, Set<Beach> landed) {
    final rig = w.resource<CameraRig>();
    final k = w.query<SceneTransform>().having<Keeper>().firstOrNull?.$2;
    double? toward(double x, double z) {
      if (k == null) return null;
      return _wrap(math.atan2(x - k.x, z - k.z) - rig.yaw);
    }

    final anchors = w.tryResource<IslandAnchors>();
    final spawns = w.tryResource<SpawnPoints>();
    return _Bearings(
      // Rounded so the strip only rebuilds when it would visibly move.
      (rig.yaw * 200).round() / 200,
      anchors == null ? null : toward(anchors.lighthouse.x, anchors.lighthouse.z),
      [
        for (final beach in landed)
          if (spawns?.of(beach) case final points? when points.isNotEmpty)
            ?toward(
              points.map((p) => p.x).reduce((a, b) => a + b) / points.length,
              points.map((p) => p.z).reduce((a, b) => a + b) / points.length,
            ),
      ],
      [
        for (final (_, b, t) in w.query2<Brazier, SceneTransform>().snapshot())
          if (b.lit) ?toward(t.x, t.z),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Bearings &&
      other.heading == heading &&
      _close(other.lighthouse, lighthouse) &&
      _same(other.landings, landings) &&
      _same(other.fires, fires);

  @override
  int get hashCode => heading.hashCode;

  static bool _close(double? a, double? b) =>
      a == b || (a != null && b != null && (a - b).abs() < 0.005);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() >= 0.005) return false;
    }
    return true;
  }
}

double _wrap(double a) {
  var d = a % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  if (d < -math.pi) d += math.pi * 2;
  return d;
}

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.b);

  final _Bearings b;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    final line = size.height - 10;
    double? xOf(double rel) =>
        rel.abs() > _span ? null : mid + rel / _span * mid;

    // A hairline, fading out at both ends.
    canvas.drawRect(
      Offset(0, line) & Size(size.width, 1),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00E9E5DC), Palette.faint, Palette.faint, Color(0x00E9E5DC)],
          stops: [0, 0.25, 0.75, 1],
        ).createShader(Offset.zero & size),
    );

    // Ticks every 15 degrees, letters on the quarters.
    const letters = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    for (var deg = 0; deg < 360; deg += 15) {
      final rel = _wrap(deg * math.pi / 180 - b.heading);
      final x = xOf(rel);
      if (x == null) continue;
      final fade = 1 - (rel.abs() / _span);
      final letter = letters[deg];
      if (letter != null) {
        _text(canvas, letter, Offset(x, line - 9),
            labelStyle(letter == 'N' ? 15 : 13,
                color: (letter == 'N' ? Palette.bone : Palette.dim)
                    .withValues(alpha: fade)));
      } else {
        canvas.drawLine(
          Offset(x, line - (deg % 45 == 0 ? 6 : 3)),
          Offset(x, line),
          Paint()
            ..color = Palette.bone.withValues(alpha: 0.35 * fade)
            ..strokeWidth = 1,
        );
      }
    }

    // Markers above the line, pinned to the ends when behind.
    double xAt(double rel) => mid + rel.clamp(-_span, _span) / _span * mid;
    final markerY = line - 24;
    for (final fire in b.fires) {
      canvas.drawCircle(Offset(xAt(fire), markerY), 3, Paint()..color = Palette.lamp);
    }
    if (b.lighthouse case final l?) {
      final x = xAt(l);
      canvas.drawPath(
        Path()
          ..moveTo(x, markerY - 6)
          ..lineTo(x + 4, markerY + 4)
          ..lineTo(x - 4, markerY + 4)
          ..close(),
        Paint()..color = Palette.bone,
      );
    }
    for (final landing in b.landings) {
      final x = xAt(landing);
      canvas.drawPath(
        Path()
          ..moveTo(x - 6, markerY - 4)
          ..lineTo(x, markerY + 3)
          ..lineTo(x + 6, markerY - 4),
        Paint()
          ..color = Palette.danger
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Where the view points.
    canvas.drawLine(
      Offset(mid, line - 10),
      Offset(mid, line + 4),
      Paint()
        ..color = Palette.bone
        ..strokeWidth = 1.5,
    );
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.b != b;
}
