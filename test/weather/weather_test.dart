import 'package:flutter_test/flutter_test.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:last_light/common/states.dart';
import 'package:last_light/common/wind.dart';
import 'package:last_light/features/nights/nights.dart';
import 'package:last_light/features/weather/weather.dart';

import '../support/harness.dart';

void main() {
  test('night 1 is calm; a storm night blows up a gale', () {
    final game = makeGame()..quietNight();
    final wind = game.world.resource<Wind>();
    game.seconds(5);
    expect(wind.storm, lessThan(0.1));
    expect(wind.strength, closeTo(weatherCalmWind, 0.05));

    game.world.resource<Run>().night = weatherStormNights.first;
    game.world.setState(GameStatus.dusk);
    game.frame();
    game.world.setState(GameStatus.night);
    game.frame();
    game.seconds(20);
    expect(wind.storm, greaterThan(0.85));
    expect(wind.strength, greaterThan(weatherCalmWind + 0.3));
  });

  test('the wind gusts', () {
    final game = makeGame()..quietNight();
    final wind = game.world.resource<Wind>();
    var low = 1.0, high = 0.0;
    for (var i = 0; i < 40; i++) {
      game.seconds(0.5);
      if (wind.gust < low) low = wind.gust;
      if (wind.gust > high) high = wind.gust;
    }
    expect(high - low, greaterThan(0.1));
  });
}
