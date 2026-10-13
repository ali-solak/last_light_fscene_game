import 'package:material_ui/material_ui.dart';

import '../controls/touch_controls.dart';
import 'boss_bar.dart';
import 'compass.dart';
import 'flame_meter.dart';
import 'keeper_status.dart';
import 'night_banner.dart';
import 'placeables_counter.dart';
import 'reticle.dart';
import 'vignette.dart';

/// The night HUD (§7).
class NightHud extends StatelessWidget {
  const NightHud({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: Vignette()),
      const Positioned.fill(child: Reticle()),
      const Positioned(
        top: 16,
        left: 0,
        right: 0,
        child: Column(
          children: [
            FlameMeter(),
            SizedBox(height: 4),
            CompassBar(),
            SizedBox(height: 4),
            BossBar(),
          ],
        ),
      ),
      const Positioned(top: 16, left: 16, child: NightBanner()),
      // On touch the thumbs own both bottom corners: the lamp and hearts
      // sit between them, the counters move to the top right, and the
      // keyboard hints go.
      if (TouchControls.wanted)
        const Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [OilGauge(), SizedBox(width: 14), HeartsRow()],
          ),
        )
      else
        const Positioned(
          left: 16,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OilGauge(),
              SizedBox(width: 22),
              LampKeys(),
              SizedBox(width: 36),
              HeartsRow(),
            ],
          ),
        ),
      Positioned(
        right: 16,
        top: TouchControls.wanted ? 16 : null,
        bottom: TouchControls.wanted ? null : 16,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PlaceablesCounter(),
            SizedBox(height: 8),
            HarpoonIndicator(),
          ],
        ),
      ),
    ],
  );
}
