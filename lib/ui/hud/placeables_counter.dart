import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../features/lamps/lamps.dart';
import '../../features/mirrors/mirrors.dart';
import '../theme.dart';

/// Bottom right, over the scene: lamps lit and mirrors upright, as text
/// (red when one is down).
class PlaceablesCounter extends StatelessWidget {
  const PlaceablesCounter({super.key});

  @override
  Widget build(BuildContext context) => WorldBuilder<(int, int, int, int)>(
    select: (w) {
      var lit = 0, lamps = 0, upright = 0, mirrors = 0;
      w.query<LampPost>().each((_, l) {
        lamps++;
        if (l.lit) lit++;
      });
      w.query<Mirror>().each((_, m) {
        mirrors++;
        if (m.upright) upright++;
      });
      return (lit, lamps, upright, mirrors);
    },
    builder: (context, v) {
      final (lit, lamps, upright, mirrors) = v;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lamps > 0) _Row('LAMPS', lit, lamps),
          if (mirrors > 0) _Row('MIRRORS', upright, mirrors),
        ],
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.good, this.total);

  final String label;
  final int good;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(label, style: labelStyle(12)),
      const SizedBox(width: 8),
      Text(
        '$good/$total',
        style: titleStyle(18, color: good < total ? Palette.danger : Palette.bone),
      ),
    ],
  );
}
