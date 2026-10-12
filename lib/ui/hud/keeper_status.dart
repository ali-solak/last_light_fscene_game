import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../features/harpoon/harpoon.dart';
import '../../features/keeper/keeper.dart';
import '../../features/lantern/lantern.dart';
import '../strings.dart';
import '../theme.dart';

/// A thin horizontal gauge: a faint track and its fill.
class _Line extends StatelessWidget {
  const _Line({required this.fraction, required this.color, this.width = 140});

  final double fraction;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 3,
    child: Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Palette.faint)),
        AnimatedFractionallySizedBox(
          duration: Motion.standard,
          curve: Motion.ease,
          widthFactor: fraction.clamp(0.0, 1.0),
          heightFactor: 1,
          alignment: Alignment.centerLeft,
          child: ColoredBox(color: color),
        ),
      ],
    ),
  );
}

/// A small label over its gauge.
class _Labelled extends StatelessWidget {
  const _Labelled(this.label, this.child, {this.color});

  final String label;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: labelStyle(12, color: color ?? Palette.dim)),
      const SizedBox(height: 5),
      child,
    ],
  );
}

/// Health: five short bars; the last one standing turns red.
class HeartsRow extends StatelessWidget {
  const HeartsRow({super.key});

  @override
  Widget build(BuildContext context) => EntityBuilder<Hearts, int>.matching(
    where: (q) => q.having<Keeper>(),
    select: (h) => h.current,
    absent: const SizedBox.shrink(),
    builder: (context, hearts) => _Labelled(
      Strings.healthLabel,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keeperHearts; i++)
            AnimatedContainer(
              duration: Motion.standard,
              width: 22,
              height: 3,
              margin: const EdgeInsets.only(right: 4),
              color: i >= hearts
                  ? Palette.faint
                  : hearts == 1
                  ? Palette.danger
                  : Palette.bone,
            ),
        ],
      ),
    ),
  );
}

/// By the oil, on a keyboard: what the lamp keys do, or how long until a
/// thrown lamp is back.
class LampKeys extends StatelessWidget {
  const LampKeys({super.key});

  @override
  Widget build(BuildContext context) => EntityBuilder<Lantern, int>.matching(
    where: (q) => q.having<Keeper>(),
    select: (l) => l.away.ceil(),
    absent: const SizedBox.shrink(),
    builder: (context, away) => AnimatedSwitcher(
      duration: Motion.standard,
      child: away > 0
          ? Text(
              key: const ValueKey('away'),
              Strings.lampBack(away).toUpperCase(),
              style: labelStyle(12, color: Palette.lamp),
            )
          : const Row(
              key: ValueKey('keys'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _KeyHint('RMB', Strings.keyLight),
                SizedBox(width: 16),
                _KeyHint('Q', Strings.keyThrow),
                SizedBox(width: 16),
                _KeyHint('F', Strings.keyBash),
              ],
            ),
    ),
  );
}

class _KeyHint extends StatelessWidget {
  const _KeyHint(this.cap, this.action);

  final String cap;
  final String action;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(cap, style: labelStyle(12, color: Palette.bone)),
      const SizedBox(width: 6),
      Text(action.toUpperCase(), style: labelStyle(12)),
    ],
  );
}

/// The oil: a thin lamp-orange line that brightens while focusing and
/// flickers toward red when nearly dry.
class OilGauge extends StatelessWidget {
  const OilGauge({super.key});

  @override
  Widget build(BuildContext context) =>
      EntityBuilder<Lantern, (double, bool)>.matching(
        where: (q) => q.having<Keeper>(),
        select: (l) => ((l.oil).roundToDouble(), l.focusing),
        absent: const SizedBox.shrink(),
        builder: (context, value) {
          final (oil, focusing) = value;
          return _Oil(fraction: oil / lanternOilMax, focusing: focusing);
        },
      );
}

class _Oil extends StatefulWidget {
  const _Oil({required this.fraction, required this.focusing});

  final double fraction;
  final bool focusing;

  @override
  State<_Oil> createState() => _OilState();
}

class _OilState extends State<_Oil> with SingleTickerProviderStateMixin {
  late final AnimationController _sputter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(_Oil old) {
    super.didUpdateWidget(old);
    final low = widget.fraction < lanternSputterBelow / lanternOilMax;
    if (low && !_sputter.isAnimating) _sputter.repeat(reverse: true);
    if (!low && _sputter.isAnimating) _sputter.stop();
  }

  @override
  void dispose() {
    _sputter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _sputter,
    builder: (context, _) {
      final base = widget.focusing
          ? Palette.lamp
          : Palette.lamp.withValues(alpha: 0.75);
      // Dry, the label says what to do, glowing with the smoulder.
      final dry = widget.fraction <= 0;
      return _Labelled(
        dry ? Strings.oilDry : Strings.oilLabel,
        color: dry
            ? Color.lerp(Palette.ember, Palette.danger, _sputter.value)
            : null,
        _Line(
          fraction: widget.fraction,
          color: Color.lerp(base, Palette.danger, _sputter.value)!,
        ),
      );
    },
  );
}

/// The harpoon state in a word, with a line that fills while it reloads.
class HarpoonIndicator extends StatelessWidget {
  const HarpoonIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      EntityBuilder<Harpoon, (HarpoonMode, int)>.matching(
        where: (q) => q.having<Keeper>(),
        select: (h) => (h.mode.state, (h.mode.elapsed * 20).floor()),
        absent: const SizedBox.shrink(),
        builder: (context, value) {
          final (mode, ticks) = value;
          final (label, color) = switch (mode) {
            HarpoonMode.ready || HarpoonMode.aiming => (Strings.harpoonReady, Palette.bone),
            HarpoonMode.flying => (Strings.harpoonFlying, Palette.lamp),
            HarpoonMode.reeling => (Strings.harpoonReeling, Palette.lamp),
            HarpoonMode.reloading => (Strings.harpoonReloading, Palette.dim),
          };
          final progress = mode == HarpoonMode.reloading
              ? math.min(1.0, ticks / 20 / 1.6)
              : 1.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(Strings.harpoonLabel, style: labelStyle(12)),
                  const SizedBox(width: 8),
                  Text(label.toUpperCase(), style: titleStyle(18, color: color)),
                ],
              ),
              const SizedBox(height: 5),
              _Line(fraction: progress, color: color, width: 120),
            ],
          );
        },
      );
}
