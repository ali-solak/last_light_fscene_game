import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene_input/flutter_scene_input.dart' show PointerLock;
import 'package:material_ui/material_ui.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

import '../../common/events.dart';
import '../../common/inputs.dart';
import '../../common/states.dart';
import '../../features/camera/camera.dart';

/// Keyboard and mouse (§7). Writes only input resources and events:
/// WASD move, the cursor aims (as a ray; the island resolves it onto the
/// ground), right mouse holds the lantern, left mouse aims and fires the
/// harpoon (or places and drags at dawn), Space jumps, E interacts,
/// Q throws (Smash), Esc pauses, Shift is the fine modifier.
class KeyboardMouseControls extends StatefulWidget {
  const KeyboardMouseControls({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardMouseControls> createState() => _KeyboardMouseControlsState();
}

class _KeyboardMouseControlsState extends State<KeyboardMouseControls>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode(debugLabel: 'game');
  final Set<LogicalKeyboardKey> _held = {};
  late final AppLifecycleListener _lifecycle;
  late World _world;

  Offset? _down;
  bool _dragging = false;
  static const double _dragSlop = 6;

  /// Where the reticle sits, as a fraction of the view (aim goes through it).
  static const Offset _reticle = Offset(0.5, 0.45);

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _releaseAll, onPause: _releaseAll);
    _ticker = createTicker(_onFrame)..start();
  }

  /// Every frame: the night captures the mouse as soon as it runs (and
  /// again on resume), so looking around never waits for a click;
  /// mouse-look while locked, aiming through the reticle; the lock ends
  /// whenever the night does.
  void _onFrame(Duration _) {
    final lock = PointerLock.instance;
    final night = _world.state<GameStatus>() == GameStatus.night &&
        _world.state<Pause>() == Pause.running;
    if (night && !lock.isLocked && lock.isSupported && _focus.hasFocus) {
      lock.lock();
    }
    if (!lock.isLocked) return;
    if (!night) {
      lock.unlock();
      return;
    }
    final move = lock.movement;
    _world.resource<CameraInput>()
      ..lookX += move.dx
      ..lookY += move.dy;
    final size = context.size;
    final fp = _world.resource<CameraRig>().firstPerson;
    if (size != null) {
      _aim(Offset(size.width * 0.5, size.height * (fp ? 0.5 : _reticle.dy)));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _world = GameScope.of(context).world;
  }

  @override
  void dispose() {
    PointerLock.instance.unlock();
    _ticker.dispose();
    _releaseAll();
    _lifecycle.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _releaseAll() {
    _held.clear();
    _world.buttons<KeeperAction>().releaseAll();
    _world.axes<KeeperAxis>().clear();
    _world.resource<CameraInput>().orbitRate = 0;
  }

  ButtonInput<KeeperAction> get _buttons => _world.buttons<KeeperAction>();

  bool get _shift =>
      _held.contains(LogicalKeyboardKey.shiftLeft) ||
      _held.contains(LogicalKeyboardKey.shiftRight);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final down = event is KeyDownEvent || event is KeyRepeatEvent;
    if (event is KeyDownEvent) _held.add(key);
    if (event is KeyUpEvent) _held.remove(key);

    void edge(KeeperAction action) {
      _buttons.setPressed(action, down);
      if (event is KeyDownEvent) _world.buffer<KeeperAction>().record(action);
    }

    switch (key) {
      case LogicalKeyboardKey.space:
        edge(KeeperAction.jump);
      case LogicalKeyboardKey.keyE:
        edge(KeeperAction.interact);
      case LogicalKeyboardKey.keyQ:
        edge(KeeperAction.throwLamp);
      // F, under the index finger beside WASD, swings the lamp. (The
      // right button focuses it.)
      case LogicalKeyboardKey.keyF:
        edge(KeeperAction.bash);
      case LogicalKeyboardKey.escape when event is KeyDownEvent:
        PointerLock.instance.unlock();
        GameScope.of(context).emit(const PauseToggled());
      case LogicalKeyboardKey.shiftLeft || LogicalKeyboardKey.shiftRight:
        _buttons.setPressed(KeeperAction.fine, down);
      case LogicalKeyboardKey.digit1 when event is KeyDownEvent:
        _world.resource<BuildSelection>().tool = .mirror;
      case LogicalKeyboardKey.digit2 when event is KeyDownEvent:
        _world.resource<BuildSelection>().tool = .lamp;
      case LogicalKeyboardKey.digit3 when event is KeyDownEvent:
        _world.resource<BuildSelection>().tool = .salt;
      case LogicalKeyboardKey.digit4 when event is KeyDownEvent:
        _world.resource<BuildSelection>().tool = .barricade;
    }
    _world.resource<CameraInput>().orbitRate =
        (_held.contains(LogicalKeyboardKey.keyC) ? 1.0 : 0.0) -
        (_held.contains(LogicalKeyboardKey.keyZ) ? 1.0 : 0.0);
    _updateAxes();
    return KeyEventResult.handled;
  }

  void _updateAxes() {
    bool held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        _held.contains(a) || _held.contains(b);
    final x = (held(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) ? 1.0 : 0.0) -
        (held(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft) ? 1.0 : 0.0);
    final y = (held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) ? 1.0 : 0.0) -
        (held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) ? 1.0 : 0.0);
    _world.axes<KeeperAxis>()
      ..setValue(KeeperAxis.moveX, x)
      ..setValue(KeeperAxis.moveY, y);
  }

  /// The camera ray through a point of the view.
  (Vector3, Vector3)? _ray(Offset local) {
    final size = context.size;
    final view = _world.query<CameraView>().firstOrNull?.$2;
    if (size == null || view == null) return null;
    final ray = view.camera.screenPointToRay(local, size);
    return (ray.origin, ray.direction);
  }

  void _aim(Offset local) {
    if (_ray(local) case (final origin, final direction)) {
      _world.resource<AimInput>().setRay(origin, direction);
    }
  }

  /// A press released: a tap places, a drag ends.
  void _finishBuild(Offset at) {
    if (_down case final start?) {
      _build(_dragging ? at : start,
          _dragging ? BuildPhase.dragEnd : BuildPhase.tap);
    }
    _down = null;
    _dragging = false;
  }

  void _build(Offset local, BuildPhase phase) {
    if (_ray(local) case (final origin, final direction)) {
      GameScope.of(context).emit(
        BuildPointer(origin, direction, phase, fine: _shift),
      );
    }
  }

  bool get _building => _world.state<GameStatus>() == GameStatus.dawnBuild;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: _onKey,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerHover: (e) {
        if (!PointerLock.instance.isLocked) _aim(e.localPosition);
      },
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          _world.resource<CameraInput>().zoom += e.scrollDelta.dy.sign;
        }
      },
      onPointerDown: (e) {
        _focus.requestFocus();
        // A finger at dawn builds like the left button: tap to place,
        // drag to aim a mirror. (At night the touch controls own touch.)
        if (e.kind != PointerDeviceKind.mouse) {
          if (_building) {
            _down = e.localPosition;
            _dragging = false;
          }
          return;
        }
        // A click at night (re)captures the mouse and still acts.
        final lock = PointerLock.instance;
        if (_world.state<GameStatus>() == GameStatus.night &&
            lock.isSupported &&
            !lock.isLocked) {
          lock.lock();
        }
        if (!lock.isLocked) _aim(e.localPosition);
        // The wheel click or a thumb button swings the lamp too, at night
        // (by day the wheel drag orbits the view).
        if (_world.state<GameStatus>() == GameStatus.night &&
            e.buttons & (kMiddleMouseButton | kBackMouseButton | kForwardMouseButton) != 0) {
          _world.buffer<KeeperAction>().record(KeeperAction.bash);
        }
        if (e.buttons & kSecondaryMouseButton != 0) {
          _buttons.setPressed(KeeperAction.focus, true);
          _world.buffer<KeeperAction>().record(KeeperAction.focus);
        }
        if (e.buttons & kPrimaryMouseButton != 0) {
          if (_building) {
            _down = e.localPosition;
            _dragging = false;
          } else {
            _buttons.setPressed(KeeperAction.harpoon, true);
          }
        }
      },
      onPointerMove: (e) {
        if (!PointerLock.instance.isLocked) _aim(e.localPosition);
        if (e.buttons & kMiddleMouseButton != 0) {
          _world.resource<CameraInput>().orbit += e.delta.dx * 0.01;
        }
        final start = _down;
        if (start == null || !_building) return;
        if (!_dragging && (e.localPosition - start).distance > _dragSlop) {
          _dragging = true;
          _build(start, BuildPhase.dragStart);
        }
        if (_dragging) _build(e.localPosition, BuildPhase.drag);
      },
      onPointerUp: (e) {
        if (e.kind != PointerDeviceKind.mouse) {
          _finishBuild(e.localPosition);
          return;
        }
        if (e.buttons & kSecondaryMouseButton == 0) {
          _buttons.setPressed(KeeperAction.focus, false);
        }
        if (e.buttons & kPrimaryMouseButton == 0) {
          _buttons.setPressed(KeeperAction.harpoon, false);
          _finishBuild(e.localPosition);
        }
      },
      onPointerCancel: (_) {
        _down = null;
        _dragging = false;
      },
      child: widget.child,
    ),
  );
}
