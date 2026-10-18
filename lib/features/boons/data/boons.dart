part of '../boons.dart';

enum BoonFamily { ember, tide, salt, glass, duo }

/// One boon. [apply] adds a component to the keeper or changes a resource;
/// [needs] names the families a duo requires.
final class const Boon(
  final String id,
  final BoonFamily family,
  final String title,
  final String text,
  final String icon,
  final void Function(World world) apply, {
  final Set<BoonFamily> needs = const {},
});

void _tag(World world, Object tag) {
  final keeper = world.entitiesWith<Keeper>().firstOrNull;
  if (keeper != null) world.add(keeper, tag);
}

void _hotWick(World w) => _tag(w, const HotWick());
void _kindling(World w) => _tag(w, const Kindling());
void _smash(World w) => _tag(w, const Smash());
void _flashpoint(World w) => _tag(w, const Flashpoint());
void _barbed(World w) => _tag(w, const Barbed());
void _whalersReel(World w) => _tag(w, const WhalersReel());
void _undertow(World w) => _tag(w, const Undertow());
void _riptide(World w) => _tag(w, const Riptide());
void _brineLight(World w) => _tag(w, const BrineLight());
void _saltedWicks(World w) => _tag(w, const SaltedWicks());
void _preserves(World w) => _tag(w, const Preserves());
void _saltRing(World w) => _tag(w, const SaltRing());
void _sunfire(World w) => _tag(w, const Sunfire());
void _brineWave(World w) => _tag(w, const BrineWave());
void _spareMirror(World w) => w.resource<Run>().mirrorsOwned += boonSpareMirrors;
void _polished(World w) => w.resource<Beam>().bounceLoss = 0;
void _lensGrind(World w) => w.resource<Beam>().halfWidth *= boonLensGrindWidth;
void _prism(World w) => w.resource<Run>().prisms += boonPrisms;
void _whiplash(World w) => _tag(w, const Whiplash());
void _tripleBolt(World w) => _tag(w, const TripleBolt());
void _flare(World w) => _tag(w, const Flare());
void _wisp(World w) => _tag(w, const Wisp());
void _saltCellar(World w) => w.resource<Run>().saltOwned += boonExtraSalt;
void _driftwood(World w) =>
    w.resource<Run>().barricadesOwned += boonExtraBarricades;

/// The initial set (§5.10).
const List<Boon> allBoons = [
  Boon('hot_wick', .ember, 'Hot Wick', 'Focused light burns 50% hotter.',
      'local_fire_department', _hotWick),
  Boon('kindling', .ember, 'Kindling',
      'Lit crabs keep burning for 3 s after leaving the light.', 'whatshot',
      _kindling),
  Boon('smash', .ember, 'Firebomb',
      'The thrown lamp bursts wider and a new one is lit in 3.5 s.',
      'sports_handball', _smash),
  Boon('flashpoint', .ember, 'Flashpoint',
      'Jumping flashes: crabs within 3 m cower for 1 s.', 'flare',
      _flashpoint),
  Boon('flare', .ember, 'Flare',
      'Let a held focus go to flare: a short cone burns and dazzles.',
      'flashlight_on', _flare),
  Boon('wisp', .ember, "Will-o'-Wisp",
      'The thrown lamp leaves a wisp: crabs within 6 m go to it for 4 s.',
      'emoji_objects', _wisp),
  Boon('barbed', .tide, 'Barbed', 'The harpoon pierces three crabs.',
      'call_split', _barbed),
  Boon('whalers_reel', .tide, "Whaler's Reel",
      'Harpoon a rock or a wall to reel yourself to it.', 'phishing',
      _whalersReel),
  Boon('whiplash', .tide, 'Whiplash',
      'Reeling whips the chain through the crabs it sweeps.', 'gesture',
      _whiplash),
  Boon('triple_bolt', .tide, 'Triple Bolt',
      'Each shot fans two darts out beside the bolt.', 'call_split',
      _tripleBolt),
  Boon('undertow', .tide, 'Undertow', 'Jumping knocks crabs back 2 m.',
      'waves', _undertow),
  Boon('riptide', .tide, 'Riptide',
      'The beam pushes crabs outward, 1 m/s.', 'tsunami', _riptide),
  Boon('brine_light', .salt, 'Brine Light', 'Lit crabs move 30% slower.',
      'grain', _brineLight),
  Boon('salted_wicks', .salt, 'Salted Wicks',
      'Snuffed lamps relight themselves after 6 s.', 'restart_alt',
      _saltedWicks),
  Boon('preserves', .salt, 'Preserves',
      'Dawn restores 25 Flame instead of 15.', 'inventory_2', _preserves),
  Boon('salt_cellar', .salt, 'Salt Cellar',
      'Two more salt lines to lay each dawn.', 'grain', _saltCellar),
  Boon('driftwood', .salt, 'Driftwood',
      'Two more barricades to build each dawn.', 'fence', _driftwood),
  Boon('salt_ring', .salt, 'Salt Ring',
      'Crabs cannot climb for the first 10 s of each night.', 'trip_origin',
      _saltRing),
  Boon('spare_mirror', .glass, 'Spare Mirror', 'One more mirror to place.',
      'crop_portrait', _spareMirror),
  Boon('polished', .glass, 'Polished', 'Bounces lose no intensity.',
      'auto_awesome', _polished),
  Boon('lens_grind', .glass, 'Lens Grind', 'The beam is 40% wider.',
      'lens', _lensGrind),
  Boon('prism', .glass, 'Prism',
      'One placed mirror becomes a prism: it splits the beam in three.',
      'change_history', _prism),
  Boon('sunfire', .duo, 'Sunfire', 'Bounced beam segments do 50% more damage.',
      'wb_sunny', _sunfire, needs: {.ember, .glass}),
  Boon('brine_wave', .duo, 'Brine Wave', 'Undertow also slows crabs for 2 s.',
      'water', _brineWave, needs: {.tide, .salt}),
];

Boon? boonById(String id) {
  for (final boon in allBoons) {
    if (boon.id == id) return boon;
  }
  return null;
}
