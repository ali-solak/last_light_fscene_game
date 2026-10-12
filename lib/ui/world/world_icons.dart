import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/interact.dart';
import '../theme.dart';

/// Over a snuffed lamp.
class LampOutIcon extends StatelessWidget {
  const LampOutIcon({super.key});

  @override
  Widget build(BuildContext context) => const _Badge(
    icon: Icons.light_outlined,
    color: Palette.danger,
    mark: '!',
  );
}

/// Over a toppled mirror.
class MirrorDownIcon extends StatelessWidget {
  const MirrorDownIcon({super.key});

  @override
  Widget build(BuildContext context) => const _Badge(
    icon: Icons.crop_portrait,
    color: Palette.danger,
    mark: '!',
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.mark});

  final IconData icon;
  final Color color;
  final String mark;

  @override
  Widget build(BuildContext context) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 38, shadows: overScene),
        Text(mark, style: titleStyle(38, color: color)),
      ],
    ),
  );
}

/// "E — turn" over whatever the keeper can use.
class InteractPrompt extends StatelessWidget {
  const InteractPrompt(this.verb, {super.key});

  final ValueListenable<PromptVerb?> verb;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PromptVerb?>(
    valueListenable: verb,
    builder: (context, verb, _) => verb == null
        ? const SizedBox.shrink()
        : Center(child: KeyPrompt(verb)),
  );
}

/// The key, and an icon for what it does: no words to read mid-fight.
/// Held (aiming a mirror), the key shows pressed and the icon says look.
class KeyPrompt extends StatelessWidget {
  const KeyPrompt(this.verb, {super.key});

  final PromptVerb verb;

  @override
  Widget build(BuildContext context) {
    final held = verb == PromptVerb.aiming;
    final icon = switch (verb) {
      PromptVerb.aim => Icons.flare,
      PromptVerb.aiming => Icons.visibility,
      PromptVerb.turn => Icons.rotate_right,
      PromptVerb.raise => Icons.upload,
      PromptVerb.relight => Icons.local_fire_department,
      PromptVerb.ring => Icons.notifications_active,
    };
    const shadow = [Shadow(color: Colors.black87, blurRadius: 6)];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.quick,
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: held ? Palette.bone : const Color(0x33000000),
            border: Border.all(color: Palette.bone, width: 2),
          ),
          child: Text(
            'E',
            style: titleStyle(28, color: held ? Palette.night : Palette.bone)
                .copyWith(letterSpacing: 0, shadows: held ? const [] : overScene),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 38, color: Palette.bone, shadows: shadow),
      ],
    );
  }
}
