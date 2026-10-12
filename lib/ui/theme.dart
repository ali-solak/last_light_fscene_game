import 'package:material_ui/material_ui.dart';

/// Bare survival-horror: the scene carries the mood. The UI is off-white
/// condensed type laid straight over it with a soft shadow, hairline
/// rules, no boxes in play, and colour only where it means something:
/// lamp orange for light, oil and the thing you have selected; red for
/// danger.
abstract final class Palette {
  /// Type and marks, in three strengths.
  static const Color bone = Color(0xFFE9E5DC);
  static const Color dim = Color(0x99E9E5DC);
  static const Color faint = Color(0x3DE9E5DC);

  /// Light, oil, selection.
  static const Color lamp = Color(0xFFEE8E3A);
  static const Color danger = Color(0xFFD9432E);

  /// Behind menus: near-black, and the scrim laid over the scene.
  static const Color night = Color(0xFF09090A);
  static const Color scrim = Color(0xD1060607);

  /// Boon families, muted and earthy.
  static const Color ember = Color(0xFFD9774A);
  static const Color tide = Color(0xFF6F9DB0);
  static const Color salt = Color(0xFFCFC9B8);
  static const Color glass = Color(0xFF8FC1BC);
  static const Color duo = Color(0xFFA996C2);
}

/// Motion: 180–250 ms ease-out; only reward moments bounce.
abstract final class Motion {
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 230);
  static const Curve ease = Curves.easeOutCubic;
  static const Curve reward = Curves.elasticOut;
}

const String _family = 'BarlowCondensed';

/// Lifts type off whatever the scene puts behind it.
const List<Shadow> overScene = [
  Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1)),
];

/// Headings: condensed, semibold, tracked out.
TextStyle titleStyle(double size, {Color color = Palette.bone}) => TextStyle(
  fontFamily: _family,
  fontSize: size,
  fontWeight: FontWeight.w600,
  letterSpacing: size * 0.08,
  height: 1.0,
  color: color,
  shadows: overScene,
);

/// Everything else.
TextStyle uiStyle(
  double size, {
  Color color = Palette.bone,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: _family,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: 0.4,
  height: 1.15,
  color: color,
  shadows: overScene,
);

/// Small tracked-out caps for labels ("OIL", "FLAME").
TextStyle labelStyle(double size, {Color color = Palette.dim}) => TextStyle(
  fontFamily: _family,
  fontSize: size,
  fontWeight: FontWeight.w600,
  letterSpacing: size * 0.18,
  color: color,
  shadows: overScene,
);

ThemeData lastLightTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Palette.night,
  colorScheme: const ColorScheme.dark(
    primary: Palette.lamp,
    secondary: Palette.bone,
    surface: Palette.night,
    error: Palette.danger,
  ),
  fontFamily: _family,
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
);

/// A field for menu content over the scene: a dark wash with a hairline
/// on top. No border, no rounded card.
BoxDecoration panelDecoration({double radius = 0}) => const BoxDecoration(
  color: Color(0xB8060607),
  border: Border(top: BorderSide(color: Palette.faint)),
);

/// A hairline rule.
class Rule extends StatelessWidget {
  const Rule({super.key, this.width, this.color = Palette.faint});

  final double? width;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: width, height: 1, color: color);
}
