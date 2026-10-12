import 'package:scene_dash_v2/scene_dash_v2.dart';

import 'events.dart';
import 'sets.dart';

/// Player settings and the small save data, read at boot (§9, §10).
final class Settings {
  bool haptics = true;
  bool screenShake = true;
  bool holdToToggleFocus = false;

  /// Over the shoulder instead of through the keeper's eyes.
  bool thirdPerson = false;
  int bestNight = 0;

  void set(SettingKey key, bool value) => switch (key) {
    .haptics => haptics = value,
    .screenShake => screenShake = value,
    .holdToToggleFocus => holdToToggleFocus = value,
    .thirdPerson => thirdPerson = value,
  };

  bool get(SettingKey key) => switch (key) {
    .haptics => haptics,
    .screenShake => screenShake,
    .holdToToggleFocus => holdToToggleFocus,
    .thirdPerson => thirdPerson,
  };

  Map<String, Object> toJson() => {
    for (final key in SettingKey.values) key.name: get(key),
    'bestNight': bestNight,
  };

  void readJson(Map<String, Object?> json) {
    for (final key in SettingKey.values) {
      if (json[key.name] case final bool v) set(key, v);
    }
    if (json['bestNight'] case final int v) bestNight = v;
  }
}

/// Where settings go when they change. The composition root wires it to
/// SharedPreferences; headless runs leave it empty.
final class SaveStore(final void Function(Map<String, Object> data)? persist) {
  void save(Settings settings) => persist?.call(settings.toJson());
}

/// Applies settings events and persists them. Installed by `configureGame`.
void installSettings(GameBuilder game) {
  game.addSystem(
    Schedules.update,
    _applySettings,
    reads: const {},
    inSet: GameSets.feedback,
    runIf: hasEvents<SettingChanged>(),
  );
}

void _applySettings(World world) {
  final settings = world.resource<Settings>();
  var changed = false;
  for (final e in world.events<SettingChanged>()) {
    settings.set(e.key, e.value);
    changed = true;
  }
  if (changed) world.tryResource<SaveStore>()?.save(settings);
}
