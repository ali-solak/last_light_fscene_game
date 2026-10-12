import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../common/states.dart';
import 'controls/keyboard_mouse.dart';
import 'controls/touch_controls.dart';
import 'hud/boss_bar.dart';
import 'hud/compass.dart';
import 'hud/flame_meter.dart';
import 'hud/keeper_status.dart';
import 'hud/night_banner.dart';
import 'hud/placeables_counter.dart';
import 'hud/reticle.dart';
import 'hud/vignette.dart';
import 'screens/dawn_boons.dart';
import 'screens/dawn_build.dart';
import 'screens/run_screens.dart';
import 'screens/title_screen.dart';
import 'theme.dart';
import 'ui_scale.dart';

/// The scene, the controls over it, and one screen per game state. Widgets
/// only read the world (builders, listeners) and write inputs or events.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context) as SceneGame;
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyboardMouseControls(
          child: SceneView(game.scene, onTick: game.onTick),
        ),
        // Everything over the scene, scaled as one on a small screen.
        Positioned.fill(
          child: UiScale(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameStateBuilder<GameStatus>(
                  builder: (context, status) => AnimatedSwitcher(
                    duration: Motion.standard,
                    switchInCurve: Motion.ease,
                    child: KeyedSubtree(
                      key: ValueKey(status),
                      child: switch (status) {
                        GameStatus.title => const TitleScreen(),
                        GameStatus.dawnBoons => const DawnBoonsScreen(),
                        GameStatus.dawnBuild => const DawnBuildScreen(),
                        GameStatus.dusk => const DuskCard(),
                        GameStatus.night => GameStateBuilder<Pause>(
                          // Paused, the menu stands alone.
                          builder: (context, pause) => pause == Pause.paused
                              ? const SizedBox.shrink()
                              : const NightHud(),
                        ),
                        GameStatus.lost => const RunSummary(won: false),
                        GameStatus.won => const RunSummary(won: true),
                      },
                    ),
                  ),
                ),
                // The sticks and buttons only where there is a keeper to drive.
                if (TouchControls.wanted)
                  GameStateBuilder<GameStatus>(
                    builder: (context, status) =>
                        status == GameStatus.night || status == GameStatus.dusk
                        ? const TouchControls()
                        : const SizedBox.shrink(),
                  ),
                GameStateBuilder<Pause>(
                  builder: (context, pause) => pause == Pause.paused
                      ? const PauseOverlay()
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
