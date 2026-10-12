import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../features/crabs/crabs.dart';
import '../strings.dart';
import '../theme.dart';

/// Top: the Tide Mother's health, three thin red segments, one per shell.
class BossBar extends StatelessWidget {
  const BossBar({super.key});

  @override
  Widget build(BuildContext context) => EntityBuilder<Health, int>.matching(
    where: (q) => q.having<Boss>().without<Dead>(),
    select: (h) => (h.fraction * 300).round(),
    absent: const SizedBox.shrink(),
    builder: (context, permille) {
      final fraction = permille / 300;
      return SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Text(Strings.tideMother.toUpperCase(), style: labelStyle(14, color: Palette.danger)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 2; i >= 0; i--)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 3,
                      color: Palette.faint,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            ((fraction - (2 - i) / 3) * 3).clamp(0.0, 1.0),
                        child: const ColoredBox(color: Palette.danger),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
