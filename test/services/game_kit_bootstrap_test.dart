import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla/services/game_kit_bootstrap.dart';
import 'package:yalla/services/storage_service.dart';

void main() {
  test('settings UI config follows the active locale', () {
    final english = buildYallaGameKitSettingsUiConfig(const Locale('en'));
    final arabic = buildYallaGameKitSettingsUiConfig(const Locale('ar'));

    expect(english.aboutDescription, contains('30-second challenge'));
    expect(arabic.aboutDescription, contains('تحدي الثلاثين ثانية'));
    expect(english.showCrossPromo, isTrue);
    expect(arabic.fontFamily, english.fontFamily);
  });

  test('storage exposes legacy haptics only when the old key exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final emptyStorage = StorageService();
    await emptyStorage.init();

    expect(emptyStorage.getLegacyHapticsEnabledOrNull(), isNull);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'haptics_enabled': false,
    });
    final legacyStorage = StorageService();
    await legacyStorage.init();

    expect(legacyStorage.getLegacyHapticsEnabledOrNull(), isFalse);
  });
}
