/// One-time copy of legacy host mute flags into kit preferences.
///
/// An existing kit value wins, so a choice saved by the settings switches is
/// never replaced. When vibration has no kit value yet, an explicit legacy
/// haptics flag wins, then the legacy sound flag, then enabled.
class AudioPreferenceMigration {
  const AudioPreferenceMigration({
    required this.migrateSound,
    required this.migrateVibration,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  static const soundsEnabledKey = 'game_kit.preferences.soundsEnabled';
  static const vibrationsEnabledKey = 'game_kit.preferences.vibrationsEnabled';

  final bool migrateSound;
  final bool migrateVibration;
  final bool soundEnabled;
  final bool vibrationEnabled;

  factory AudioPreferenceMigration.resolve({
    required bool kitSoundAlreadyStored,
    required bool kitVibrationAlreadyStored,
    required bool? legacySound,
    required bool? legacyHaptics,
  }) {
    return AudioPreferenceMigration(
      migrateSound: !kitSoundAlreadyStored,
      migrateVibration: !kitVibrationAlreadyStored,
      soundEnabled: legacySound ?? true,
      vibrationEnabled: legacyHaptics ?? legacySound ?? true,
    );
  }
}

Future<void> applyAudioPreferenceMigration(
  AudioPreferenceMigration migration, {
  required Future<void> Function(bool enabled) setSoundsEnabled,
  required Future<void> Function(bool enabled) setVibrationsEnabled,
}) async {
  if (migration.migrateSound) {
    await setSoundsEnabled(migration.soundEnabled);
  }
  if (migration.migrateVibration) {
    await setVibrationsEnabled(migration.vibrationEnabled);
  }
}
