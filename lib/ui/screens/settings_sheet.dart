import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/events.dart';
import '../../common/settings.dart';
import '../strings.dart';
import '../theme.dart';
import '../ui_scale.dart';
import 'common.dart';

/// Settings (§10): haptics, shake, focus toggle, camera. Writes only
/// `SettingChanged` events.
void showSettings(BuildContext context) {
  final game = GameScope.of(context);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: Strings.close,
    barrierColor: Colors.transparent,
    transitionDuration: Motion.standard,
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (_, _, _) => GameScope(
      game: game,
      child: const UiScale(child: SettingsSheet()),
    ),
  );
}

/// The settings page: one row per setting, its value written plainly on
/// the right (ON / OFF, or ticks for volume); tap a row to change it.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static const _toggles = [
    (SettingKey.haptics, Strings.settingHaptics),
    (SettingKey.screenShake, Strings.settingShake),
    (SettingKey.holdToToggleFocus, Strings.settingToggleFocus),
    (SettingKey.thirdPerson, Strings.settingThirdPerson),
  ];

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: MenuPage(
      heading: Strings.settings,
      children: [
        for (final (key, label) in _toggles) _ToggleRow(key, label),
        const SizedBox(height: 18),
        MenuItem(Strings.close, primary: true,
            onPressed: () => Navigator.of(context).pop()),
      ],
    ),
  );
}

/// A settings row: its name on the left, its value at a fixed column.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.onTap});

  final String label;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 260, child: Text(label, style: uiStyle(20))),
          value,
        ],
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(this.setting, this.label);

  final SettingKey setting;
  final String label;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return WorldBuilder<bool>(
      select: (w) => w.resource<Settings>().get(setting),
      builder: (context, on) => _Row(
        label: label,
        onTap: () => game.emit(SettingChanged(setting, !on)),
        value: Text(
          on ? Strings.on : Strings.off,
          style: labelStyle(18, color: on ? Palette.lamp : Palette.dim),
        ),
      ),
    );
  }
}
