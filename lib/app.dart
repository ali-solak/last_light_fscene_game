import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import 'common/states.dart';
import 'ui/controls/keyboard_mouse.dart';
import 'ui/controls/touch_controls.dart';
import 'ui/hud/night_hud.dart';
import 'ui/screens/dawn_boons.dart';
import 'ui/screens/dawn_build.dart';
import 'ui/screens/run_screens.dart';
import 'ui/screens/title_screen.dart';
import 'ui/theme.dart';
import 'ui/ui_scale.dart';

/// The game on screen: the 3D view with the keyboard and mouse on it, and
/// over it the screen for the current state, the touch controls and the
/// pause menu. Widgets only read the world and write inputs or events.
class LastLightApp extends StatelessWidget {
  const LastLightApp(this.game, {super.key});

  final SceneGame game;

  @override
  Widget build(BuildContext context) => GameHost(
    game: game,
    child: MaterialApp(
      title: 'Last Light',
      debugShowCheckedModeBanner: false,
      theme: lastLightTheme(),
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            KeyboardMouseControls(
              child: SceneView(game.scene, onTick: game.onTick),
            ),
            // On a small screen the whole UI scales down together.
            const UiScale(
              child: Stack(
                fit: StackFit.expand,
                children: [_StateScreen(), _TouchControls(), _PauseMenu()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One screen per game state; at night the HUD, hidden while paused.
class _StateScreen extends StatelessWidget {
  const _StateScreen();

  @override
  Widget build(BuildContext context) => GameStateBuilder<GameStatus>(
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
            builder: (context, pause) =>
                pause == Pause.paused ? const SizedBox.shrink() : const NightHud(),
          ),
          GameStatus.lost => const RunSummary(won: false),
          GameStatus.won => const RunSummary(won: true),
        },
      ),
    ),
  );
}

/// The sticks and buttons, on a touch screen, while there is a keeper to
/// drive.
class _TouchControls extends StatelessWidget {
  const _TouchControls();

  @override
  Widget build(BuildContext context) {
    if (!TouchControls.wanted) return const SizedBox.shrink();
    return GameStateBuilder<GameStatus>(
      builder: (context, status) =>
          status == GameStatus.night || status == GameStatus.dusk
          ? const TouchControls()
          : const SizedBox.shrink(),
    );
  }
}

class _PauseMenu extends StatelessWidget {
  const _PauseMenu();

  @override
  Widget build(BuildContext context) => GameStateBuilder<Pause>(
    builder: (context, pause) =>
        pause == Pause.paused ? const PauseOverlay() : const SizedBox.shrink(),
  );
}

/// Shown while the models, materials and shaders load, or with the error
/// if loading failed.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: lastLightTheme(),
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LAST LIGHT', style: titleStyle(56)),
            const SizedBox(height: 20),
            if (error == null)
              const SizedBox(
                width: 160,
                height: 2,
                child: LinearProgressIndicator(color: Palette.bone, backgroundColor: Palette.faint),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$error', style: uiStyle(13, color: Palette.danger)),
              ),
          ],
        ),
      ),
    ),
  );
}
