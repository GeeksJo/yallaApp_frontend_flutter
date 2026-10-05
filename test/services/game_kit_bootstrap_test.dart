import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:yalla/l10n/yalla_game_kit_localizations.dart';
import 'package:yalla/services/game_kit_bootstrap.dart';
import 'package:yalla/services/storage_service.dart';

void main() {
  test('settings UI config follows the active locale', () {
    final english = buildYallaGameKitSettingsUiConfig(const Locale('en'));
    final arabic = buildYallaGameKitSettingsUiConfig(const Locale('ar'));

    expect(english.aboutDescription, contains('answer time'));
    expect(english.aboutDescription, isNot(contains('30')));
    expect(arabic.aboutDescription, contains('وقت الإجابة'));
    expect(arabic.aboutDescription, isNot(contains('ثلاثين')));
    expect(english.aboutDescription, isNot(arabic.aboutDescription));
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

  test('sounds ignore the silent switch and haptics add no host gate', () {
    expect(yallaSoundConfig.respectSilentMode, isFalse);
    expect(yallaHapticsConfig.isEnabled, isNull);
  });

  test('rating uses the kit session and level gates', () {
    expect(yallaRatingConfig.minSession, 2);
    expect(yallaRatingConfig.minLevel, 4);
    expect(yallaRatingConfig.maxLifetime, 3);
    expect(yallaRatingConfig.minDaysBetween, 4);
    expect(yallaRatingConfig.minSecondsAfterAd, 60);
    expect(yallaRatingConfig.maxDismissals, 3);
  });

  test('reminders keep the Mon/Wed/Fri 18:00 schedule and kit copy', () {
    expect(yallaNotificationsConfig.days, [
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    ]);
    expect(yallaNotificationsConfig.hour, 18);
    expect(yallaNotificationsConfig.installDelayHours, 48);
    expect(yallaNotificationsConfig.stopAfterIgnoredCount, 3);
    expect(yallaNotificationsConfig.androidChannelId, 'yalla_reminders');
    expect(yallaNotificationsConfig.notificationTitle, isNull);
    expect(yallaNotificationsConfig.notificationBody, isNull);
    expect(yallaNotificationsConfig.androidChannelName, isNull);
    expect(yallaNotificationsConfig.androidChannelDescription, isNull);
    expect(yallaNotificationsConfig.enableFcm, isTrue);
    expect(yallaNotificationsConfig.fcmTopics, ['all_users']);
  });

  test('share identity is yalla and More Games excludes this app', () {
    expect(yallaShareConfig.analyticsGameName, 'yalla');
    expect(yallaShareConfig.androidPackageName, yallaStoreId);
    expect(yallaShareConfig.iosAppId, yallaIosAppId);
    expect(yallaStoreId, 'com.majoon.yalla');
  });

  test('share copy stays the shipped Arabic and English lines', () async {
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final arabic = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(
      YallaGameKitLocalizationsEn().shareAppMessage('ignored'),
      english.shareAppMessage,
    );
    expect(
      YallaGameKitLocalizationsAr().shareAppMessage('ignored'),
      arabic.shareAppMessage,
    );
    expect(english.shareAppMessage, isNot(arabic.shareAppMessage));
  });

  test('catalog refresh does nothing before GameKit starts', () async {
    await refreshGameKitCatalog();
  });

  test('reminder refresh does nothing before GameKit starts', () async {
    await refreshGameKitReminders();
  });
}
