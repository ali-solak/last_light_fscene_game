
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

import '../../common/inputs.dart';
import '../../common/states.dart';
import '../../features/keeper/keeper.dart';
import '../strings.dart';
import '../theme.dart';

/// Touch, the mobile-shooter way: the left thumb walks on a stick, the
/// right thumb drags anywhere free to look (the crosshair aims), and a
/// thumb arc bottom right holds the lamp (hold to focus), the harpoon
/// (hold to aim, release to fire), jump, throw, and use when something is
/// in reach (hold it to aim a mirror). At dawn, the scene takes taps and
/// drags directly.
class TouchControls extends StatefulWidget {
  const TouchControls({super.key});

  /// Touch controls show on phones and tablets.
  static bool get wanted =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

class _TouchControlsState extends State<TouchControls> {
  static const double _stickRadius = 56;

  late World _world;
  Offset _stick = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _world = GameScope.of(context).world;
  }

  @override
  void dispose() {
    _world.buttons<KeeperAction>().releaseAll();
    _world.axes<KeeperAxis>().clear();
    super.dispose();
  }

  void _moveStick(Offset delta) {
    final clamped = delta.distance > _stickRadius
        ? delta / delta.distance * _stickRadius
        : delta;
    setState(() => _stick = clamped);
    _world.axes<KeeperAxis>()
      ..setValue(KeeperAxis.moveX, clamped.dx / _stickRadius)
      ..setValue(KeeperAxis.moveY, -clamped.dy / _stickRadius);
  }

  /// The right thumb's drag turns the view (radians per logical pixel,
  /// as a multiple of the mouse's).
  static const double _lookGain = 2.5;

  void _look(Offset delta) => _world.resource<CameraInput>()
    ..lookX += delta.dx * _lookGain
    ..lookY += delta.dy * _lookGain;

  /// A held action: pressed while the finger is down, and buffered so a
  /// quick tap still counts.
  ({VoidCallback down, VoidCallback up}) _hold(KeeperAction action) => (
    down: () {
      _world.buttons<KeeperAction>().setPressed(action, true);
      _world.buffer<KeeperAction>().record(action);
    },
    up: () => _world.buttons<KeeperAction>().setPressed(action, false),
  );

  @override
  Widget build(BuildContext context) => GameStateBuilder<GameStatus>(
    builder: (context, status) {
      if (status != GameStatus.night) return const SizedBox.shrink();
      final harpoon = _hold(KeeperAction.harpoon);
      final lantern = _hold(KeeperAction.focus);
      final use = _hold(KeeperAction.interact);
      return Stack(
        children: [
          // The right side of the screen looks around (under the buttons).
          Positioned(
            left: MediaQuery.sizeOf(context).width * 0.4,
            top: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _look(d.delta),
            ),
          ),
          // Left stick.
          Positioned(left: 28, bottom: 28, child: _stickPad()),
          // The thumb arc, bottom right: harpoon in the corner, the lamp
          // beside it, jump and throw above, use when something is near.
          Positioned(
            right: 20,
            bottom: 20,
            child: _RoundButton(Icons.phishing, Strings.harpoon,
                big: true, onDown: harpoon.down, onUp: harpoon.up),
          ),
          Positioned(
            right: 116,
            bottom: 20,
            child: _RoundButton(Icons.light_mode, Strings.lantern,
                big: true, onDown: lantern.down, onUp: lantern.up),
          ),
          Positioned(
            right: 28,
            bottom: 116,
            child: _RoundButton(Icons.directions_run, Strings.dodge,
                onDown: () => _world.buffer<KeeperAction>().record(KeeperAction.jump)),
          ),
          Positioned(
            right: 124,
            bottom: 116,
            child: _RoundButton(Icons.sports_handball, Strings.throwLamp,
                onDown: () => _world.buffer<KeeperAction>().record(KeeperAction.throwLamp)),
          ),
          Positioned(
            right: 212,
            bottom: 20,
            child: _RoundButton(Icons.flare, Strings.bash,
                onDown: () => _world.buffer<KeeperAction>().record(KeeperAction.bash)),
          ),
          Positioned(
            right: 28,
            bottom: 196,
            child: WorldBuilder<bool>(
              select: (w) =>
                  w.query<KeeperBrain>().having<Keeper>().firstOrNull?.$2.inReach != null,
              builder: (context, near) => near
                  ? _RoundButton(Icons.pan_tool, Strings.interact,
                      onDown: use.down, onUp: use.up)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      );
    },
  );

  Widget _stickPad() => GestureDetector(
    onPanStart: (_) => _moveStick(Offset.zero),
    onPanUpdate: (d) => _moveStick(_stick + d.delta),
    onPanEnd: (_) => _moveStick(Offset.zero),
    child: Container(
      width: _stickRadius * 2.4,
      height: _stickRadius * 2.4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x26000000),
        border: Border.all(color: Palette.faint, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Transform.translate(
        offset: _stick,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99E9E5DC)),
        ),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(this.icon, this.label, {this.onDown, this.onUp, this.big = false});

  final IconData icon;
  final String label;
  final VoidCallback? onDown;
  final VoidCallback? onUp;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 82.0 : 64.0;
    return Listener(
      onPointerDown: onDown == null ? null : (_) => onDown!(),
      onPointerUp: onUp == null ? null : (_) => onUp!(),
      onPointerCancel: onUp == null ? null : (_) => onUp!(),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x33000000),
          border: Border.all(color: Palette.dim, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Palette.bone, size: big ? 30 : 22, shadows: overScene),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: labelStyle(9, color: Palette.bone)),
          ],
        ),
      ),
    );
  }
}
