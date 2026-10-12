import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../common/inputs.dart';
import '../../features/defenses/defenses.dart';
import '../../features/lamps/lamps.dart';
import '../../features/light/light.dart' show Brazier;
import '../../features/mirrors/mirrors.dart';
import '../../features/nights/nights.dart';
import '../strings.dart';
import '../theme.dart';
import 'common.dart';
import 'dawn_boons.dart';

/// The build bar over the island overview: no panel, a dark band at the
/// bottom with the tools on the left as text (the selected one bright and
/// underlined), the hint above them, and on the right how many signal
/// fires the light reaches and the bell. Wraps on a narrow screen.
class DawnBuildScreen extends StatelessWidget {
  const DawnBuildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1000;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: compact ? 6 : 16),
          const BoonStrip(),
          const Spacer(),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xE6060607), Color(0x00060607)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 24 : 48,
                48,
                compact ? 24 : 48,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact) ...[
                    Text(
                      Strings.buildHint,
                      style: uiStyle(15, color: Palette.dim),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Full width, so the bell sits at the far right.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 28,
                      runSpacing: 10,
                      children: [
                        _Tools(compact: compact),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _FireTally(),
                            const SizedBox(width: 28),
                            MenuItem(
                              Strings.ringBell,
                              primary: true,
                              onPressed: () =>
                                  GameScope.of(context).emit(const BellRung()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four build tools, each with what is left of it.
class _Tools extends StatelessWidget {
  const _Tools({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) =>
      WorldBuilder<(int, int, int, int, int, int, int, int, BuildTool)>(
        select: (w) {
          final run = w.resource<Run>();
          return (
            w.query<Mirror>().count(),
            run.mirrorsOwned,
            w.query<LampPost>().count(),
            run.lampsOwned,
            w.entitiesWith<SaltLine>().count(),
            run.saltOwned,
            w.entitiesWith<Barricade>().count(),
            run.barricadesOwned,
            w.resource<BuildSelection>().tool,
          );
        },
        builder: (context, v) {
          final (
            mirrors,
            mirrorsOwned,
            lamps,
            lampsOwned,
            salts,
            saltOwned,
            walls,
            wallsOwned,
            tool,
          ) = v;
          final world = GameScope.of(context).world;
          Widget chip(
            BuildTool kind,
            IconData icon,
            Color color,
            String hotkey,
            int left,
            int owned,
            String Function(int, int) label,
          ) => _ToolChip(
            icon: icon,
            label: compact ? '$left/$owned' : label(left, owned),
            hotkey: compact ? null : hotkey,
            color: color,
            selected: tool == kind,
            onTap: () => world.resource<BuildSelection>().tool = kind,
          );
          return Wrap(
            spacing: compact ? 18 : 28,
            runSpacing: 6,
            children: [
              chip(
                .mirror,
                Icons.crop_portrait,
                Palette.glass,
                '1',
                mirrorsOwned - mirrors,
                mirrorsOwned,
                Strings.mirrorsLeft,
              ),
              chip(
                .lamp,
                Icons.light,
                Palette.lamp,
                '2',
                lampsOwned - lamps,
                lampsOwned,
                Strings.lampsLeft,
              ),
              chip(
                .salt,
                Icons.grain,
                Palette.dim,
                '3',
                saltOwned - salts,
                saltOwned,
                Strings.saltLeft,
              ),
              chip(
                .barricade,
                Icons.fence,
                Palette.lamp,
                '4',
                wallsOwned - walls,
                wallsOwned,
                Strings.barricadesLeft,
              ),
            ],
          );
        },
      );
}

/// How many signal fires the light as set would reach.
class _FireTally extends StatelessWidget {
  const _FireTally();

  @override
  Widget build(BuildContext context) => WorldBuilder<(int, int)>(
    select: (w) {
      var reach = 0, total = 0;
      w.query<Brazier>().each((_, b) {
        total++;
        if (b.reachable) reach++;
      });
      return (reach, total);
    },
    builder: (context, v) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department,
          size: 18,
          color: v.$1 > 0 ? Palette.lamp : Palette.dim,
          shadows: overScene,
        ),
        const SizedBox(width: 6),
        Text(
          Strings.brazierTally(v.$1, v.$2).toUpperCase(),
          style: labelStyle(14, color: v.$1 > 0 ? Palette.bone : Palette.dim),
        ),
      ],
    ),
  );
}

/// One build tool, as text: its key, its name and what is left. The
/// selected one is bright with a lamp-orange underline.
class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.hotkey,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Its keyboard key (none on a touch screen).
  final String? hotkey;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (hotkey case final key?) ...[
                Text(key, style: labelStyle(12, color: Palette.faint)),
                const SizedBox(width: 8),
              ],
              Icon(
                icon,
                size: 18,
                color: selected ? color : Palette.dim,
                shadows: overScene,
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: titleStyle(
                  22,
                  color: selected ? Palette.bone : Palette.dim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: Motion.quick,
            height: 2,
            width: selected ? 40 : 0,
            color: Palette.lamp,
          ),
        ],
      ),
    ),
  );
}
