import 'package:material_ui/material_ui.dart';

import '../../features/boons/boons.dart';
import '../theme.dart';

/// A menu entry: left-aligned text in a list. Pointed at (hover, focus)
/// or [primary], it brightens and a lamp-orange bar marks it; otherwise it
/// sits dim. No box, no border.
class MenuItem extends StatefulWidget {
  const MenuItem(
    this.label, {
    super.key,
    required this.onPressed,
    this.primary = false,
    this.size = 26,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final double size;

  @override
  State<MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<MenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lit = _hover || widget.primary;
    return FocusableActionDetector(
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _hover = v),
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Motion.quick,
                curve: Motion.ease,
                width: lit ? 18 : 0,
                height: 2,
                margin: EdgeInsets.only(right: lit ? 12 : 0),
                color: Palette.lamp,
              ),
              AnimatedDefaultTextStyle(
                duration: Motion.quick,
                style: titleStyle(
                  widget.size,
                  color: lit ? Palette.bone : Palette.dim,
                ),
                child: Text(widget.label.toUpperCase()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A menu screen over the scene: a scrim, and on the left a heading, a
/// hairline, then [children] in a column (scrolling if the screen is
/// short), with an optional [footer] at the bottom.
class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.heading,
    required this.children,
    this.headingColor = Palette.bone,
    this.footer,
  });

  final String heading;
  final Color headingColor;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Palette.scrim,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 40, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading.toUpperCase(), style: titleStyle(52, color: headingColor)),
                    const SizedBox(height: 14),
                    const Rule(width: 320),
                    const SizedBox(height: 18),
                    ...children,
                  ],
                ),
              ),
            ),
            ?footer,
          ],
        ),
      ),
    ),
  );
}

/// A boon's family colour and its icon.
Color familyColor(BoonFamily family) => switch (family) {
  BoonFamily.ember => Palette.ember,
  BoonFamily.tide => Palette.tide,
  BoonFamily.salt => Palette.salt,
  BoonFamily.glass => Palette.glass,
  BoonFamily.duo => Palette.duo,
};

IconData boonIcon(String name) => switch (name) {
  'local_fire_department' => Icons.local_fire_department,
  'whatshot' => Icons.whatshot,
  'sports_handball' => Icons.sports_handball,
  'flare' => Icons.flare,
  'call_split' => Icons.call_split,
  'phishing' => Icons.phishing,
  'waves' => Icons.waves,
  'tsunami' => Icons.tsunami,
  'grain' => Icons.grain,
  'restart_alt' => Icons.restart_alt,
  'inventory_2' => Icons.inventory_2,
  'trip_origin' => Icons.trip_origin,
  'crop_portrait' => Icons.crop_portrait,
  'auto_awesome' => Icons.auto_awesome,
  'lens' => Icons.lens,
  'change_history' => Icons.change_history,
  'wb_sunny' => Icons.wb_sunny,
  'water' => Icons.water,
  _ => Icons.star,
};

/// A small boon mark (strips and summaries): its icon in its family's
/// colour, no badge around it.
class BoonBadge extends StatelessWidget {
  const BoonBadge(this.boon, {super.key, this.size = 30});

  final Boon boon;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '${boon.title}: ${boon.text}',
    child: SizedBox(
      width: size,
      height: size,
      child: Icon(
        boonIcon(boon.icon),
        size: size * 0.7,
        color: familyColor(boon.family),
        shadows: overScene,
      ),
    ),
  );
}
