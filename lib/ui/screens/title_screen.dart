import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../common/settings.dart';
import '../strings.dart';
import '../theme.dart';
import 'common.dart';
import 'settings_sheet.dart';

/// The island orbits behind; the name sits low on the left over a dark
/// wash, the menu a plain list under it.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xE0060607), Color(0x00060607)],
          stops: [0.25, 0.75],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(64, 32, 32, 48),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Motion.ease,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Strings.title, style: titleStyle(76)),
                  const SizedBox(height: 10),
                  Text(Strings.subtitle, style: uiStyle(18, color: Palette.dim)),
                  const SizedBox(height: 14),
                  const Rule(width: 320),
                  const SizedBox(height: 18),
                  MenuItem(
                    Strings.start,
                    primary: true,
                    onPressed: () => game.emit(const GameStarted()),
                  ),
                  MenuItem(
                    Strings.settings,
                    onPressed: () => showSettings(context),
                  ),
                  const SizedBox(height: 14),
                  WorldBuilder<int>(
                    select: (w) => w.resource<Settings>().bestNight,
                    builder: (context, best) => Text(
                      Strings.bestNight(best).toUpperCase(),
                      style: labelStyle(13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
