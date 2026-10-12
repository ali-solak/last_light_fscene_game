/// Every player-facing string, in one place for later localisation (§13).
abstract final class Strings {
  static const title = 'LAST LIGHT';
  static const subtitle = 'Keep the flame through ten nights';
  static const start = 'Start';
  static const settings = 'Settings';
  static const on = 'ON';
  static const off = 'OFF';
  static const resume = 'Resume';
  static const restart = 'Restart run';
  static const quit = 'Quit';
  static const again = 'Again';
  static const ringBell = 'Ring the bell';
  static const chooseBoon = 'Choose a blessing for the night';
  static const duo = 'DUO';
  static const paused = 'Paused';
  static const victory = 'The light held';
  static const victoryLine = 'Ten nights, and the dawn is yours.';
  static const close = 'Close';

  static String nightOf(int night) => 'NIGHT $night / 10';
  static String nightCard(int night) => 'NIGHT $night';
  static String lostOn(int night) => 'Dark on night $night';
  static String crabsLeft(int n) => n == 1 ? '1 crab' : '$n crabs';
  static String mirrorsLeft(int left, int owned) => 'Mirrors $left / $owned';
  static String lampsLeft(int left, int owned) => 'Lamps $left / $owned';
  static String saltLeft(int left, int owned) => 'Salt $left / $owned';
  static String barricadesLeft(int left, int owned) =>
      'Barricades $left / $owned';
  static const killsLabel = 'CRABS';
  static const nightsLabel = 'NIGHTS';
  static const boonsLabel = 'CARRIED';
  static String bestNight(int n) => n == 0 ? '' : 'Best: night $n';
  static String flameRestore(int n) => '+$n Flame';

  static const buildHint =
      'Mirrors: drag toward where the light should go · light the braziers '
      'with thrown light · salt and barricades herd the crabs · Shift: fine';
  static String brazierTally(int lit, int total) => 'Signal fires $lit / $total';
  static const controlsHint =
      'WASD move · mouse look · right mouse lantern · left mouse harpoon · '
      'Q throw lamp · F bash · Space jump · E interact · wheel zoom · Esc pause';
  static const keyLight = 'Focus';
  static const keyThrow = 'Throw';
  static const keyBash = 'Bash';
  static const bash = 'Bash';
  static String lampBack(int seconds) => 'Lamp back in $seconds';

  static String beachWarning(String beach) => 'Landing: $beach';
  static const north = 'north';
  static const east = 'east';
  static const south = 'south';


  // Settings.
  static const settingHaptics = 'Haptics';
  static const settingShake = 'Screen shake';
  static const settingToggleFocus = 'Lantern focus toggles';
  static const settingThirdPerson = 'Third-person camera';

  // HUD.
  static const harpoonReady = 'Ready';
  static const harpoonLabel = 'HARPOON';
  static const oilLabel = 'OIL';
  static const oilDry = 'DRY · BASH TO REKINDLE';
  static const healthLabel = 'HEALTH';
  static const harpoonFlying = 'Flying';
  static const harpoonReeling = 'Reeling';
  static const harpoonReloading = 'Reloading';
  static const lantern = 'Lantern';
  static const harpoon = 'Harpoon';
  static const dodge = 'Jump';
  static const interact = 'Use';
  static const throwLamp = 'Throw';
  static const tideMother = 'THE TIDE MOTHER';
}
