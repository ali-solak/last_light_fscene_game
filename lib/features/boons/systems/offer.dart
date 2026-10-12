part of '../boons.dart';

void installBoonOffer(GameBuilder game) {
  game
    ..addSystem(OnEnter(GameStatus.dawnBoons), _rollOffer, reads: {Keeper})
    ..addSystem(
      Schedules.update,
      _pickBoon,
      reads: {Keeper},
      inSet: GameSets.feedback,
      runIf: hasEvents<BoonPicked>(),
    );
}

/// Rolls three distinct boons from the run's RNG, weighted toward owned
/// families; duos only when both families are owned. A fresh run first
/// strips every boon from the last run.
void _rollOffer(World world) {
  final run = world.resource<Run>();
  if (run.fresh) _clearBoons(world);
  final owned = {
    for (final id in run.boons)
      if (boonById(id) case final boon?) boon.family,
  };
  final pool = [
    for (final boon in allBoons)
      if (!run.boons.contains(boon.id) &&
          (boon.family != BoonFamily.duo || owned.containsAll(boon.needs)))
        boon,
  ];
  final offer = world.resource<BoonOffer>().boons..clear();
  while (offer.length < boonOfferSize && pool.isNotEmpty) {
    final weights = [
      for (final boon in pool)
        owned.contains(boon.family) || boon.family == BoonFamily.duo
            ? boonOwnedFamilyWeight
            : 1.0,
    ];
    var pick = run.rng.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    var i = 0;
    while (i < pool.length - 1 && pick >= weights[i]) {
      pick -= weights[i];
      i++;
    }
    offer.add(pool.removeAt(i));
  }
}

/// A boon picked from the UI: apply it, record it, go build.
void _pickBoon(World world) {
  final run = world.resource<Run>();
  final offer = world.resource<BoonOffer>();
  for (final picked in world.events<BoonPicked>()) {
    final boon = offer.boons.where((b) => b.id == picked.id).firstOrNull;
    if (boon == null || world.state<GameStatus>() != GameStatus.dawnBoons) {
      continue;
    }
    boon.apply(world);
    run.boons.add(boon.id);
    offer.boons.clear();
    world.setState(GameStatus.dawnBuild);
    break;
  }
}

void _clearBoons(World world) {
  final keeper = world.entitiesWith<Keeper>().firstOrNull;
  if (keeper != null) {
    world
      ..remove<HotWick>(keeper)
      ..remove<Kindling>(keeper)
      ..remove<Smash>(keeper)
      ..remove<Flashpoint>(keeper)
      ..remove<Barbed>(keeper)
      ..remove<WhalersReel>(keeper)
      ..remove<Undertow>(keeper)
      ..remove<Riptide>(keeper)
      ..remove<BrineLight>(keeper)
      ..remove<SaltedWicks>(keeper)
      ..remove<Preserves>(keeper)
      ..remove<SaltRing>(keeper)
      ..remove<Sunfire>(keeper)
      ..remove<BrineWave>(keeper);
  }
  final fresh = Beam();
  world.resource<Beam>()
    ..bounceLoss = fresh.bounceLoss
    ..halfWidth = fresh.halfWidth
    ..degreesPerSecond = fresh.degreesPerSecond;
}

/// The run's boons in pick order, for the HUD strip and summaries.
List<Boon> boonsOf(Run run) => [
  for (final id in run.boons) ?boonById(id),
];

/// A random pick for the balance bot.
Boon pickRandom(List<Boon> offer, math.Random rng) =>
    offer[rng.nextInt(offer.length)];
