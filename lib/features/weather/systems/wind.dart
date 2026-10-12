part of '../weather.dart';

void installWind(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.night), _forecast, reads: const {})
    ..addSystem(OnEnter(GameStatus.dawnBoons), _clearSkies, reads: const {})
    ..addSystem(
      Schedules.fixedUpdate,
      _blow,
      reads: const {},
      inSet: GameSets.input,
    );
}

/// A night's weather: storms on the storm nights, a breeze otherwise, the
/// wind from a seeded direction.
void _forecast(World world) {
  final weather = world.resource<Weather>();
  final night = world.tryResource<Run>()?.night ?? 1;
  final seed = world.tryResource<RunSeed>()?.fixed ?? 0;
  final rng = math.Random(seed * 31 + night);
  weather
    ..stormGoal = weatherStormNights.contains(night) ? 1 : 0
    ..headingGoal = rng.nextDouble() * math.pi * 2
    ..nextBolt = weatherBoltMin + rng.nextDouble() * 4;
}

void _clearSkies(World world) => world.resource<Weather>().stormGoal = 0;

/// The wind eases toward the night's weather, veers slowly, and gusts.
void _blow(World world) {
  final wind = world.resource<Wind>();
  final weather = world.resource<Weather>();
  final dt = world.dt;
  weather.time += dt;
  final blend = smoothBlend(dt, weatherEase);
  wind.storm += (weather.stormGoal - wind.storm) * blend;
  final turn = angleBetween(weather.heading, weather.headingGoal);
  weather.heading += turn.clamp(-weatherVeer * dt, weatherVeer * dt);
  wind.blowToward(weather.heading);
  wind.strength = weatherCalmWind +
      (weatherStormWind - weatherCalmWind) * wind.storm;
  // Gusts: two slow incommensurate swells, sharpened.
  final t = weather.time;
  final swell = 0.5 + 0.5 * math.sin(t * 0.37) * math.sin(t * 0.61 + 1.3);
  final gustiness = weatherGustCalm + (weatherGustStorm - weatherGustCalm) * wind.storm;
  wind.gust = math.pow(swell, 3).toDouble() * gustiness;
}

/// The signed shortest turn from [a] to [b].
double angleBetween(double a, double b) {
  var d = (b - a) % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  if (d < -math.pi) d += math.pi * 2;
  return d;
}
