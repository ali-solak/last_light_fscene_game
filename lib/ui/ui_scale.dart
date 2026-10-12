import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Lays [child] out as if the screen were at least [minHeight] logical
/// pixels tall and scales it down to fit, so on a phone in landscape the
/// whole UI shrinks together (text, panels, buttons) instead of crowding
/// and overlapping. Larger screens are untouched.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.child, this.minHeight = 520});

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.min(1.0, constraints.maxHeight / minHeight);
      if (scale >= 1) return child;
      final size = constraints.biggest / scale;
      final media = MediaQuery.of(context);
      return FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: size,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              padding: media.padding / scale,
              viewPadding: media.viewPadding / scale,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
