import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../features/boons/boons.dart';
import '../../features/nights/nights.dart';
import '../strings.dart';
import '../theme.dart';
import 'common.dart';
import 'settings_sheet.dart';

/// Dusk: the night's number large and tracked out, a hairline, the
/// forecast; fading out over 2.5 s.
class DuskCard extends StatelessWidget {
  const DuskCard({super.key});

  @override
  Widget build(BuildContext context) {
    final night = context.world.resource<Run>().night;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2500),
        builder: (context, t, child) {
          // In for a fifth, hold, then fade.
          final opacity = t < 0.2 ? t / 0.2 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
          return Opacity(opacity: opacity.clamp(0, 1), child: child);
        },
        child: Container(
          color: const Color(0x8C060607),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Strings.nightCard(night).toUpperCase(),
                style: titleStyle(88).copyWith(letterSpacing: 22),
              ),
              const SizedBox(height: 14),
              const Rule(width: 220, color: Palette.dim),
              const SizedBox(height: 14),
              Text(nightForecast(night), style: uiStyle(20, color: Palette.dim)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pause: the scene dimmed, the menu a list on the left, the controls
/// written small at the bottom.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return MenuPage(
      heading: Strings.paused,
      footer: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(Strings.controlsHint, style: uiStyle(14, color: Palette.dim)),
      ),
      children: [
        MenuItem(Strings.resume, primary: true,
            onPressed: () => game.emit(const PauseToggled())),
        MenuItem(Strings.settings, onPressed: () => showSettings(context)),
        MenuItem(Strings.restart,
            onPressed: () => game.emit(const RestartRequested())),
        MenuItem(Strings.quit, onPressed: () => game.emit(const QuitRequested())),
      ],
    );
  }
}

/// The run summary for game over and victory: what happened, as a short
/// ledger, the boons carried, and what next.
class RunSummary extends StatelessWidget {
  const RunSummary({super.key, required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final run = context.world.resource<Run>();
    final boons = boonsOf(run);
    return MenuPage(
      heading: won ? Strings.victory : Strings.lostOn(run.night),
      headingColor: won ? Palette.lamp : Palette.bone,
      children: [
        if (won) ...[
          Text(Strings.victoryLine, style: uiStyle(18, color: Palette.dim)),
          const SizedBox(height: 16),
        ],
        _Ledger(Strings.nightsLabel, '${won ? 10 : run.night}'),
        _Ledger(Strings.killsLabel, '${run.kills}'),
        if (boons.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(Strings.boonsLabel, style: labelStyle(13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [for (final boon in boons) BoonBadge(boon, size: 30)],
          ),
        ],
        const SizedBox(height: 24),
        MenuItem(Strings.again, primary: true,
            onPressed: () => game.emit(const RestartRequested())),
        MenuItem(Strings.quit, onPressed: () => game.emit(const QuitRequested())),
      ],
    );
  }
}

/// One line of the ledger: a small label, and its value large.
class _Ledger extends StatelessWidget {
  const _Ledger(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 110, child: Text(label, style: labelStyle(14))),
        Text(value, style: titleStyle(30)),
      ],
    ),
  );
}
