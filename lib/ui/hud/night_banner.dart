import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../features/crabs/crabs.dart';
import '../../features/light/light.dart' show Brazier;
import '../../features/nights/nights.dart';
import '../strings.dart';
import '../theme.dart';

/// Top left, straight over the scene: the night, crabs remaining, signal
/// fires, and a red arrow line for each beach that just took a landing
/// (arrow + text, never colour alone).
class NightBanner extends StatefulWidget {
  const NightBanner({super.key});

  @override
  State<NightBanner> createState() => _NightBannerState();
}

class _NightBannerState extends State<NightBanner> {
  final Map<Beach, DateTime> _warnings = {};

  @override
  Widget build(BuildContext context) => WorldEventListener<WaveLanded>(
    onEvent: (context, wave) {
      setState(() => _warnings[wave.beach] = DateTime.now());
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _warnings.removeWhere(
            (_, at) => DateTime.now().difference(at).inSeconds >= 5,
          ));
        }
      });
    },
    child: WorldBuilder<(int, int, int, int)>(
      select: (w) {
        var lit = 0, total = 0;
        w.query<Brazier>().each((_, b) {
          total++;
          if (b.lit) lit++;
        });
        return (
          w.resource<Run>().night,
          w.query<Crab>().without<Dead>().count(),
          lit,
          total,
        );
      },
      builder: (context, value) {
        final (night, crabs, lit, total) = value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.nightOf(night).toUpperCase(), style: titleStyle(22)),
            const SizedBox(height: 6),
            const Rule(width: 120),
            const SizedBox(height: 6),
            Text(Strings.crabsLeft(crabs).toUpperCase(), style: labelStyle(13)),
            if (total > 0) ...[
              const SizedBox(height: 2),
              Text(
                Strings.brazierTally(lit, total).toUpperCase(),
                style: labelStyle(13, color: lit > 0 ? Palette.lamp : Palette.dim),
              ),
            ],
            for (final beach in _warnings.keys) ...[
              const SizedBox(height: 6),
              _BeachChip(beach),
            ],
          ],
        );
      },
    ),
  );
}

class _BeachChip extends StatelessWidget {
  const _BeachChip(this.beach);

  final Beach beach;

  @override
  Widget build(BuildContext context) {
    final (icon, name) = switch (beach) {
      Beach.north => (Icons.arrow_upward, Strings.north),
      Beach.east => (Icons.arrow_forward, Strings.east),
      Beach.south => (Icons.arrow_downward, Strings.south),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Palette.danger, shadows: overScene),
        const SizedBox(width: 4),
        Text(Strings.beachWarning(name).toUpperCase(),
            style: labelStyle(14, color: Palette.danger)),
      ],
    );
  }
}
