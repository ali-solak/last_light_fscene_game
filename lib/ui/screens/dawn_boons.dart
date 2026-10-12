import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../features/boons/boons.dart';
import '../../features/nights/nights.dart';
import '../strings.dart';
import '../theme.dart';
import 'common.dart';

/// The offer: three choices as columns of type over a dark band, rising
/// in staggered; pointing at one marks it, picking it emits `BoonPicked`.
class DawnBoonsScreen extends StatelessWidget {
  const DawnBoonsScreen({super.key});

  @override
  Widget build(BuildContext context) => WorldBuilder<List<String>>(
    select: (w) => [for (final b in w.resource<BoonOffer>().boons) b.id],
    builder: (context, ids) {
      final offer = [for (final id in ids) ?boonById(id)];
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
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
                padding: const EdgeInsets.fromLTRB(64, 60, 32, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Strings.chooseBoon.toUpperCase(), style: labelStyle(16)),
                    const SizedBox(height: 18),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, boon) in offer.indexed) ...[
                            if (i > 0)
                              const VerticalDivider(
                                width: 40,
                                thickness: 1,
                                color: Palette.faint,
                              ),
                            _SlideUp(
                              delay: Duration(milliseconds: 90 * i),
                              child: BoonCard(boon),
                            ),
                          ],
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
    },
  );
}

/// The boons taken this run, along the top.
class BoonStrip extends StatelessWidget {
  const BoonStrip({super.key});

  @override
  Widget build(BuildContext context) => WorldBuilder<List<String>>(
    select: (w) => List.of(w.resource<Run>().boons),
    builder: (context, ids) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final id in ids)
          if (boonById(id) case final boon?)
            Padding(padding: const EdgeInsets.all(3), child: BoonBadge(boon)),
      ],
    ),
  );
}

class _SlideUp extends StatefulWidget {
  const _SlideUp({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_SlideUp> createState() => _SlideUpState();
}

class _SlideUpState extends State<_SlideUp> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: _shown ? Offset.zero : const Offset(0, 0.4),
    duration: Motion.standard,
    curve: Motion.ease,
    child: AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: Motion.standard,
      child: widget.child,
    ),
  );
}

class BoonCard extends StatefulWidget {
  const BoonCard(this.boon, {super.key});

  final Boon boon;

  @override
  State<BoonCard> createState() => _BoonCardState();
}

class _BoonCardState extends State<BoonCard> {
  bool _lit = false;

  @override
  Widget build(BuildContext context) {
    final boon = widget.boon;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _lit = v),
      onShowFocusHighlight: (v) => setState(() => _lit = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _pick(context),
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context),
        child: SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: Motion.quick,
                curve: Motion.ease,
                width: _lit ? 240 : 28,
                height: 2,
                color: _lit ? Palette.lamp : Palette.faint,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(boonIcon(boon.icon), size: 20,
                      color: familyColor(boon.family), shadows: overScene),
                  const SizedBox(width: 8),
                  Text(
                    boon.family == BoonFamily.duo
                        ? Strings.duo.toUpperCase()
                        : boon.family.name.toUpperCase(),
                    style: labelStyle(13, color: familyColor(boon.family)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: Motion.quick,
                style: titleStyle(30, color: _lit ? Palette.bone : Palette.dim),
                child: Text(boon.title.toUpperCase()),
              ),
              const SizedBox(height: 8),
              Text(boon.text, style: uiStyle(17, color: Palette.dim)),
            ],
          ),
        ),
      ),
    );
  }

  void _pick(BuildContext context) =>
      GameScope.of(context).emit(BoonPicked(widget.boon.id));
}
