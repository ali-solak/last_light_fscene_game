import 'package:flutter_scene_input/flutter_scene_input.dart' show PointerLock;
import 'package:material_ui/material_ui.dart';

import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../features/camera/camera.dart' show CameraRig;
import '../../features/crabs/crabs.dart' show Exposed, Shroud;
import '../../features/keeper/keeper.dart' show interactPrompt;
import '../../common/interact.dart';
import '../world/world_icons.dart' show KeyPrompt;
import '../theme.dart';

/// The aiming reticle while the mouse is captured; a hint to capture it
/// otherwise.
class Reticle extends StatelessWidget {
  const Reticle({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PointerLock.instance,
    builder: (context, _) {
      final lock = PointerLock.instance;
      // With a captured mouse, or on a touch screen (no pointer to
      // capture; the view itself aims), the crosshair shows.
      if (lock.isLocked || !lock.isSupported) {
        return WorldBuilder<bool>(
          select: (w) => w.resource<CameraRig>().firstPerson,
          builder: (context, fp) => Align(
            alignment: Alignment(0, fp ? 0 : -0.1),
            child: const IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: Size(28, 28), painter: _ReticlePainter()),
                  _HitMarker(),
                  _UsePrompt(),
                ],
              ),
            ),
          ),
        );
      }
      if (!lock.isSupported) return const SizedBox.shrink();
      return Align(
        alignment: const Alignment(0, 0.35),
        child: IgnorePointer(
          child: Text('CLICK TO LOOK AROUND', style: labelStyle(14, color: Palette.bone)),
        ),
      );
    },
  );
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final shadow = Paint()
      ..color = Colors.black54
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = Palette.bone
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final paint in [shadow, line]) {
      canvas
        ..drawLine(c + const Offset(-12, 0), c + const Offset(-5, 0), paint)
        ..drawLine(c + const Offset(5, 0), c + const Offset(12, 0), paint)
        ..drawLine(c + const Offset(0, -12), c + const Offset(0, -5), paint)
        ..drawLine(c + const Offset(0, 5), c + const Offset(0, 12), paint);
    }
    canvas.drawCircle(c, 1.4, Paint()..color = Palette.bone);
  }

  @override
  bool shouldRepaint(_ReticlePainter oldDelegate) => false;
}

/// What a harpoon hit did, as the crosshair shows it.
enum _Hit {
  /// Off a brine shroud: barely a scratch. Burn it first.
  glance(Palette.dim, 7),
  hit(Palette.bone, 8),
  /// Into a crab the lamp laid bare.
  exposed(Palette.lamp, 10),
  weakSpot(Palette.danger, 10),
  kill(Palette.danger, 14);

  const _Hit(this.color, this.size);
  final Color color;
  final double size;
}

/// The hit marker: an X flashed over the crosshair on every harpoon hit,
/// coloured and sized by what the hit did, fading out.
class _HitMarker extends StatefulWidget {
  const _HitMarker();

  @override
  State<_HitMarker> createState() => _HitMarkerState();
}

class _HitMarkerState extends State<_HitMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  _Hit _hit = _Hit.hit;
  Entity? _last;

  void _show(_Hit hit) {
    // A stronger mark wins over a weaker one in the same instant.
    if (_fade.isAnimating && _fade.value < 0.25 && hit.index < _hit.index) {
      return;
    }
    setState(() => _hit = hit);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorldEventListener<HarpoonHit>(
    onEvent: (context, hit) {
      final crab = hit.target;
      if (hit.kind != HarpoonTargetKind.crab || crab == null) return;
      final world = GameScope.of(context).world;
      _last = crab;
      _show(switch (crab) {
        _ when world.has<Exposed>(crab) => _Hit.exposed,
        _ when (world.tryGet<Shroud>(crab)?.value ?? 0) > 0 => _Hit.glance,
        _ => _Hit.hit,
      });
    },
    child: WorldEventListener<WeakSpotHit>(
      onEvent: (context, _) => _show(_Hit.weakSpot),
      child: WorldEventListener<CrabKilled>(
        onEvent: (context, killed) {
          if (killed.entity == _last) _show(_Hit.kill);
        },
        child: AnimatedBuilder(
          animation: _fade,
          builder: (context, _) => CustomPaint(
            size: const Size(44, 44),
            painter: _HitPainter(_hit, Curves.easeOut.transform(_fade.value)),
          ),
        ),
      ),
    ),
  );
}

class _HitPainter extends CustomPainter {
  const _HitPainter(this.hit, this.t);

  final _Hit hit;

  /// 0 just hit .. 1 faded.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final fade = 1 - t;
    // Pops out from the centre, then settles as it fades.
    final r = hit.size * (0.8 + 0.4 * fade);
    final gap = r * 0.45;
    final paint = Paint()
      ..color = hit.color.withValues(alpha: fade)
      ..strokeWidth = hit == _Hit.kill ? 3 : 2
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
      canvas.drawLine(
        c + Offset(dx * gap, dy * gap),
        c + Offset(dx * r, dy * r),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HitPainter old) => old.t != t || old.hit != hit;
}

/// Under the crosshair, through his eyes: the key for whatever he can use
/// (a mirror to aim, a lamp to relight, the bell), where the eye already is.
class _UsePrompt extends StatelessWidget {
  const _UsePrompt();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, 62),
    child: WorldBuilder<PromptVerb?>(
      select: (w) => w.resource<CameraRig>().firstPerson
          ? interactPrompt(w)?.$2
          : null,
      builder: (context, verb) => AnimatedSwitcher(
        duration: Motion.quick,
        child: verb == null
            ? const SizedBox.shrink()
            : Transform.scale(
                key: ValueKey(verb),
                scale: 0.75,
                child: KeyPrompt(verb),
              ),
      ),
    ),
  );
}
