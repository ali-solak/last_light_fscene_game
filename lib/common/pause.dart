import 'package:scene_dash_v2/scene_dash_v2.dart';

import 'events.dart';
import 'inputs.dart';
import 'sets.dart';
import 'states.dart';

/// Pause is its own state machine; entering it stops the game clock.
void installPause(GameBuilder game) {
  game
    ..addSystem(
      Schedules.update,
      _togglePause,
      reads: const {},
      inSet: GameSets.feedback,
      runIf: hasEvents<PauseToggled>(),
    )
    ..addSystem(OnEnter(Pause.paused), _freeze, reads: const {})
    ..addSystem(OnExit(Pause.paused), _thaw, reads: const {});
}

void _togglePause(World world) {
  world.consumeAny<PauseToggled>();
  final status = world.state<GameStatus>();
  if (status == GameStatus.title ||
      status == GameStatus.lost ||
      status == GameStatus.won) {
    return;
  }
  world.setState(
    world.state<Pause>() == Pause.running ? Pause.paused : Pause.running,
  );
}

void _freeze(World world) {
  world.clock.paused = true;
  world.buttons<KeeperAction>().releaseAll();
  world.axes<KeeperAxis>().clear();
}

void _thaw(World world) => world.clock.paused = false;
