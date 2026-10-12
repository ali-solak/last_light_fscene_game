import 'package:scene_dash_v2/scene_dash_v2.dart';

/// The whole-game flow. `title → dawnBoons → dawnBuild → dusk → night → …`.
enum GameStatus { title, dawnBoons, dawnBuild, dusk, night, lost, won }

/// Orthogonal to [GameStatus]; entering `paused` freezes the game clock.
enum Pause { running, paused }

/// Where the keeper can walk and act: the night, and the dawn build.
final RunCondition inPlay = inState(
  GameStatus.night,
).or(inState(GameStatus.dawnBuild));

/// Either dawn screen: the boon pick or the build.
final RunCondition atDawn = inState(
  GameStatus.dawnBoons,
).or(inState(GameStatus.dawnBuild));

/// Gameplay is live and not paused.
final RunCondition running = inState(Pause.running);
