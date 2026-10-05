import 'package:flutter_test/flutter_test.dart';
import 'package:yalla/services/audio_preference_migration.dart';

void main() {
  test('preference keys match the kit storage prefix', () {
    expect(
      AudioPreferenceMigration.soundsEnabledKey,
      'game_kit.preferences.soundsEnabled',
    );
    expect(
      AudioPreferenceMigration.vibrationsEnabledKey,
      'game_kit.preferences.vibrationsEnabled',
    );
  });

  test('an existing kit vibration choice is left untouched', () async {
    final migration = AudioPreferenceMigration.resolve(
      kitSoundAlreadyStored: true,
      kitVibrationAlreadyStored: true,
      legacySound: false,
      legacyHaptics: false,
    );
    final sounds = <bool>[];
    final vibrations = <bool>[];

    await applyAudioPreferenceMigration(
      migration,
      setSoundsEnabled: (value) async => sounds.add(value),
      setVibrationsEnabled: (value) async => vibrations.add(value),
    );

    expect(migration.migrateSound, isFalse);
    expect(migration.migrateVibration, isFalse);
    expect(sounds, isEmpty);
    expect(vibrations, isEmpty);
  });

  test('explicit legacy haptics beat the legacy sound flag', () {
    final migration = AudioPreferenceMigration.resolve(
      kitSoundAlreadyStored: false,
      kitVibrationAlreadyStored: false,
      legacySound: true,
      legacyHaptics: false,
    );

    expect(migration.migrateSound, isTrue);
    expect(migration.migrateVibration, isTrue);
    expect(migration.soundEnabled, isTrue);
    expect(migration.vibrationEnabled, isFalse);
  });

  test('legacy sound fills vibration when haptics were never stored', () {
    final migration = AudioPreferenceMigration.resolve(
      kitSoundAlreadyStored: false,
      kitVibrationAlreadyStored: false,
      legacySound: false,
      legacyHaptics: null,
    );

    expect(migration.soundEnabled, isFalse);
    expect(migration.vibrationEnabled, isFalse);
  });

  test('missing legacy flags stay enabled', () {
    final migration = AudioPreferenceMigration.resolve(
      kitSoundAlreadyStored: false,
      kitVibrationAlreadyStored: false,
      legacySound: null,
      legacyHaptics: null,
    );

    expect(migration.soundEnabled, isTrue);
    expect(migration.vibrationEnabled, isTrue);
  });

  test('saved kit vibration is not replaced by legacy sound', () async {
    final migration = AudioPreferenceMigration.resolve(
      kitSoundAlreadyStored: false,
      kitVibrationAlreadyStored: true,
      legacySound: false,
      legacyHaptics: null,
    );
    final sounds = <bool>[];
    final vibrations = <bool>[];

    await applyAudioPreferenceMigration(
      migration,
      setSoundsEnabled: (value) async => sounds.add(value),
      setVibrationsEnabled: (value) async => vibrations.add(value),
    );

    expect(sounds, <bool>[false]);
    expect(vibrations, isEmpty);
  });
}
