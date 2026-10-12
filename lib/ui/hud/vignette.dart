import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../common/settings.dart';
import '../../features/keeper/keeper.dart';
import '../../features/lighthouse/lighthouse.dart';
import '../theme.dart';

/// Full screen: a red edge flash when the keeper is hit, and an amber→red
/// heartbeat at 1 Hz while the Flame is under 30 %. Reduce-flashing turns
/// both off. Haptics ride the same events.
class Vignette extends StatelessWidget {
  const Vignette({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.world.resource<Settings>();
    return WorldEventListener<KeeperHit>(
      onEvent: (_, _) {
        if (settings.haptics) HapticFeedback.mediumImpact();
      },
      child: WorldEventListener<HarpoonHit>(
        onEvent: (_, _) {
          if (settings.haptics) HapticFeedback.lightImpact();
        },
        child: WorldEventListener<ShellCracked>(
          onEvent: (_, _) {
            if (settings.haptics) HapticFeedback.mediumImpact();
          },
          child: IgnorePointer(
            child: WorldBuilder<int>.pulse(
              select: (w) =>
                  w.query<Hearts>().having<Keeper>().firstOrNull?.$2.current ?? 5,
              trigger: (previous, next) => next < previous,
              duration: 0.5,
              pulseBuilder: (context, hit, _) => WorldBuilder<bool>(
                select: (w) => w.resource<Flame>().fraction < 0.3,
                builder: (context, low) => _Edge(hit: hit, low: low),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Edge extends StatefulWidget {
  const _Edge({required this.hit, required this.low});

  final double hit;
  final bool low;

  @override
  State<_Edge> createState() => _EdgeState();
}

class _EdgeState extends State<_Edge> with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _beat,
    builder: (context, _) {
      // Heartbeat: two quick thumps a second.
      final t = _beat.value;
      final beat = widget.low
          ? math.max(0.0, math.sin(t * math.pi * 2)) * 0.6 +
              math.max(0.0, math.sin(t * math.pi * 4 - 0.6)) * 0.3
          : 0.0;
      final color = Color.lerp(Palette.lamp, Palette.danger, t)!;
      final strength = math.max(beat * 0.55, widget.hit * 0.8);
      if (strength < 0.01) return const SizedBox.expand();
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.1,
            colors: [
              Colors.transparent,
              (widget.hit > beat ? Palette.danger : color)
                  .withValues(alpha: strength),
            ],
            stops: const [0.62, 1],
          ),
        ),
      );
    },
  );
}
