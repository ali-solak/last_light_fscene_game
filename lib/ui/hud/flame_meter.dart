import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../features/lighthouse/lighthouse.dart';
import '../theme.dart';

/// Top centre: the Flame as a thin line with its number. It flashes red
/// on every drain and stays red when low; a faint tick marks where low
/// begins.
class FlameMeter extends StatelessWidget {
  const FlameMeter({super.key});

  @override
  Widget build(BuildContext context) => WorldBuilder<double>.pulse(
    select: (w) => w.resource<Flame>().current,
    trigger: (previous, next) => next < previous,
    duration: 0.35,
    pulseBuilder: (context, pulse, child) => WorldBuilder<double>(
      select: (w) => (w.resource<Flame>().fraction * 100).roundToDouble(),
      builder: (context, percent) => _Meter(
        fraction: percent / 100,
        pulse: pulse,
      ),
    ),
  );
}

const double _width = 260;
const double _low = 0.3;

class _Meter extends StatelessWidget {
  const _Meter({required this.fraction, required this.pulse});

  final double fraction;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final low = fraction < _low;
    final fill = Color.lerp(low ? Palette.danger : Palette.bone, Palette.danger, pulse)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('FLAME', style: labelStyle(12)),
              const Spacer(),
              Text(
                '${(fraction * 100).round()}',
                style: titleStyle(22, color: low ? Palette.danger : Palette.bone),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: _width,
          height: 3,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: ColoredBox(color: Palette.faint)),
              AnimatedFractionallySizedBox(
                duration: Motion.standard,
                curve: Motion.ease,
                widthFactor: fraction.clamp(0, 1),
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: ColoredBox(color: fill),
              ),
              const Positioned(
                left: _width * _low,
                top: -3,
                child: SizedBox(width: 1, height: 9, child: ColoredBox(color: Palette.dim)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
