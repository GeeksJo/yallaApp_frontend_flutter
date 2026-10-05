import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import 'audio_preference_migration.dart';
import 'firebase_service.dart';
import 'game_kit_products.dart';
import 'storage_service.dart';

// Call sites for `game_kit` in this app:
//
// - [GameKit.ads.levelCompleted] - between rounds in [QuestionScreen] and at
//   end of match on [ScoreboardScreen] (`failed: true` skips cadence on timeout).
// - [GameKit.ads.requestAdGrant] - free-coins chain in [LockedCategorySheet]
//   (via [CoinProvider.watchAdForCoins]).
// - [GameKit.notifications.markPlayedToday] - first frame [QuestionScreen].
// - [GameKit.notifications.initialize] - inside [GameKit.initialize] on cold start;
//   [refreshGameKitAfterResume] calls it again on app resume ([YallaApp] lifecycle).
// - [GameKit.notifications.onFirstDailyCompletion] - [ScoreboardScreen] after
//   a finished match, including Remove Ads. Permission is requested there, not
//   on launch.
// - [GameKitRatingPrompt.presentIfEligible] - after a successful round's
//   interstitial, or on [ScoreboardScreen] after its interstitial. The level
//   is the cumulative correct-answer count, not the in-game round.
// - [GameKit.iap] - purchases / restore / prices in [SettingsScreen] & [QuestionScreen].
// - [GameKit.crossPromo] - catalog sheet; badge on home settings.
// - [GameKit.share] - settings share row.
// - [GameKit.haptics] / [GameKit.sounds] - gameplay feedback (countdown, answers, UI).

/// About-card blurb for the kit settings screen, per locale.
///
/// Plain constants rather than ARB lookups because [initializeGameKit] runs
/// before the localization delegate has loaded.
const String _aboutDescriptionAr =
    'يلا: اذكر ثلاثة أشياء قبل ما يخلص الوقت. أنت تختار وقت الإجابة لكل جولة. '
    'لعبة سريعة للجلسات مع الأصدقاء والعائلة.';

const String _aboutDescriptionEn =
    'Yalla: name three things before time runs out. You choose the answer '
    'time for each round. A fast party game for friends and family.';

/// SFX play through the iOS silent switch. The in-app sound switch is the mute.
const yallaSoundConfig = SoundConfig(respectSilentMode: false);

/// Vibration follows the kit preference. This config adds no extra gate.
const yallaHapticsConfig = HapticsConfig();

/// Kit rating policy: second session, four cumulative successes, and the
/// kit's own lifetime, dismissal, and post-ad limits.
const yallaRatingConfig = RatingConfig();

/// Android package, iOS bundle, and the More Games exclusion id.
const yallaStoreId = 'com.majoon.yalla';

const yallaIosAppId = '6763862332';

/// Share sheet copy uses [YallaGameKitLocalizationsDelegate]. [analyticsGameName]
/// is the stable host identity on `share_tapped`.
const yallaShareConfig = ShareConfig(
  appName: 'Yalla! - 5 seconds',
  androidPackageName: yallaStoreId,
  iosAppId: yallaIosAppId,
  analyticsGameName: 'yalla',
);

/// Mon/Wed/Fri at 18:00 local. The 48-hour install delay and the stop after
/// three ignored reminders are the kit defaults. Title, body, and the Android
/// channel label stay unset so they follow the kit's Arabic/English strings
/// (the title falls back to the share app name).
const yallaNotificationsConfig = NotificationsConfig(
  days: [DateTime.monday, DateTime.wednesday, DateTime.friday],
  hour: 18,
  androidChannelId: 'yalla_reminders',
  enableFcm: true,
);

String _aboutDescriptionFor(Locale locale) =>
    locale.languageCode == 'ar' ? _aboutDescriptionAr : _aboutDescriptionEn;

GameKitSettingsUiConfig buildYallaGameKitSettingsUiConfig(Locale locale) {
  return GameKitSettingsUiConfig(
    seedColor: AppColors.primary,
    aboutDescription: _aboutDescriptionFor(locale),
    iconColor: AppColors.primary,
    fontFamily: AppFonts.family,
    sectionCardAppearance: GameKitSectionCardAppearance.frosted,
    showCrossPromo: true,
    dialog: GameKitSettingsDialogUiConfig(
      darkSurfaceColor: AppColors.surface,
      darkBorderColor: AppColors.cardBorder,
      darkTitleColor: AppColors.textPrimary,
      darkBodyColor: AppColors.textSecondary,
      alertSurfaceColor: AppColors.surface,
      alertOutlineColor: AppColors.cardBorder,
      alertTitleColor: AppColors.textPrimary,
      alertBodyColor: AppColors.textSecondary,
    ),
  );
}

void updateGameKitPresentationLocale(Locale locale) {
  GameKit.updateLocale(locale);
  GameKit.updateSettingsUi(buildYallaGameKitSettingsUiConfig(locale));
  unawaited(refreshGameKitReminders());
}

Future<void> initializeGameKit(StorageService storage) async {
  final persistedLocale = Locale(storage.getLocale());
  final prefs = await SharedPreferences.getInstance();
  // Captured before init so a default written during startup is not treated
  // as a saved player choice that should block legacy migration.
  final audioMigration = AudioPreferenceMigration.resolve(
    kitSoundAlreadyStored: prefs.containsKey(
      AudioPreferenceMigration.soundsEnabledKey,
    ),
    kitVibrationAlreadyStored: prefs.containsKey(
      AudioPreferenceMigration.vibrationsEnabledKey,
    ),
    legacySound: storage.getLegacySoundEnabledOrNull(),
    legacyHaptics: storage.getLegacyHapticsEnabledOrNull(),
  );

  // Frozen for this process. LevelPlay cannot be re-keyed after init, and a
  // published unit id must not swap mid-session. Native ids are on the same
  // snapshot; the kit's production id type has no native slot, so they are
  // not passed into [AdsConfig].
  final levelPlay = FirebaseService.instance.freezeLevelPlayPlacements();
  final interstitialCooldownSeconds = FirebaseService.instance
      .resolveInterstitialCooldownSeconds();

  await GameKit.initialize(
    GameKitConfig(
      locale: persistedLocale,
      crossPromoSheetSeedColor: AppColors.primary,
      // The kit's own named `game_kit` Firebase app: shared Remote Config
      // (interstitial cooldown, launch grace, support email) plus More Games
      // analytics. Its options are packaged inside the kit, so this needs no
      // host config file. Separate from the host [DEFAULT] app that
      // FirebaseService brings up for the kill switch and push.
      firebase: GameKitFirebaseConfig.builtIn(),
      // Lets the kit read Remote Config through this app. Without it the kit
      // falls back to its compiled defaults and console values are ignored -
      // the gap Sawaleef also had.
      remoteConfig: const YallaRemoteConfigAdapter(),
      settingsUi: buildYallaGameKitSettingsUiConfig(persistedLocale),
      iap: IapConfig(
        removeAdsProductId: GameKitProducts.removeAds,
        donationSmallProductId: GameKitProducts.donationSmall,
        donationMediumProductId: GameKitProducts.donationMedium,
        donationLargeProductId: GameKitProducts.donationLarge,
        donationAmountsByProductId: {
          GameKitProducts.donationSmall: 0.99,
          GameKitProducts.donationMedium: 4.99,
          GameKitProducts.donationLarge: 9.99,
        },
      ),
      ads: AdsConfig(
        interstitialEveryNLevels: 2,
        // Always the real ids. LevelPlay has no always-fill demo units the way
        // AdMob did - Unity's demo app key returns no fill - so a "test"
        // environment here would mean no ads at all in debug. Safe testing
        // comes from Unity dashboard test mode plus registered test devices.
        adEnvironment: AdUnitEnvironment.prod,
        prodLevelPlayUnitIds: LevelPlayProdUnitIds(
          appKeyAndroid: levelPlay.appKeyAndroid,
          appKeyIos: levelPlay.appKeyIos,
          interstitialAndroid: levelPlay.interstitialAndroid,
          interstitialIos: levelPlay.interstitialIos,
          bannerAndroid: levelPlay.bannerAndroid,
          bannerIos: levelPlay.bannerIos,
          rewardedAndroid: levelPlay.rewardedAndroid,
          rewardedIos: levelPlay.rewardedIos,
        ),
        interstitialCooldownSeconds: interstitialCooldownSeconds,
        // Handed to the kit rather than checked at each call site, so a
        // switched-off build still reaches the kit's *capped* free grant
        // instead of leaving the free-coins button dead. Reads Remote Config
        // on every call, so a console publish takes effect without a release.
        //
        // This app had no Remote Config at all until now, which meant no way
        // to turn ads off without shipping.
        adsEnabled: () => FirebaseService.instance.resolveAdsEnabled(),
        gatherUmpConsent: FirebaseService.instance.resolveAdsEnabled(),
        showPromoInterstitial: true,
      ),
      rating: yallaRatingConfig,
      notifications: yallaNotificationsConfig,
      share: yallaShareConfig,
      storage: const StorageConfig(
        backend: GameKitStoreBackend.sharedPreferences,
      ),
      sound: yallaSoundConfig,
      haptics: yallaHapticsConfig,
      crossPromoAppIdentifier: Platform.isAndroid
          ? yallaStoreId
          : yallaIosAppId,
    ),
  );

  await applyAudioPreferenceMigration(
    audioMigration,
    setSoundsEnabled: GameKit.preferences.setSoundsEnabled,
    setVibrationsEnabled: GameKit.preferences.setVibrationsEnabled,
  );

  // `preloadAds` brings the network up and warms both formats, so there is no
  // separate init call and no rewarded-enabled branch to get wrong.
  unawaited(GameKit.ads.preloadAds());

  await _migrateLegacyDonationTotal(storage);
  await _prefetchIapCatalog();
  GameKitAdBridge.attach();
}

/// Moves `StorageService` donation total into [GameKit.iap] once, if present.
Future<void> _migrateLegacyDonationTotal(StorageService storage) async {
  try {
    final legacy = storage.getDonationTotalAmount();
    if (legacy <= 0) return;
    final current = await GameKit.iap.getTotalDonations();
    if (current > 0) {
      await storage.clearDonationTotal();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    const prefix = 'game_kit.iap.';
    final existing = prefs.getInt('${prefix}totalDonationsCents');
    if (existing == null || existing <= 0) {
      await prefs.setInt(
        '${prefix}totalDonationsCents',
        (legacy * 100).round(),
      );
    }
    await storage.clearDonationTotal();
  } catch (_) {}
}

Future<void> _prefetchIapCatalog() async {
  if (!GameKit.iap.isAvailable) return;
  try {
    await GameKit.iap.loadStoreProducts();
  } catch (_) {}
}

Future<void> refreshGameKitReminders() async {
  if (!GameKit.isInitialized) return;
  try {
    await GameKit.notifications.initialize();
  } catch (_) {
    // Scheduling is best-effort. A plugin failure must not block locale or resume.
  }
}

Future<void> refreshGameKitCatalog() async {
  if (!GameKit.isInitialized) return;
  try {
    await GameKit.crossPromo.softRefreshIfDue();
  } catch (_) {
    // A failed refresh keeps the last cached catalog.
  }
}

Future<void> refreshGameKitAfterResume() async {
  await refreshGameKitReminders();
  await refreshGameKitCatalog();
  GameKitAdBridge.preloadAds();
}

/// Round-boundary ad adapter.
///
/// The host only reports completed levels and supplies a [BuildContext]. The
/// kit owns loading, house-ad alternation, cooldowns, show caps, adClosed, and
/// the remove-ads prompt.
final class GameKitAdBridge {
  GameKitAdBridge._();

  static void attach() {
    // Interstitials are driven from [presentAfterLevel] at round boundaries.
  }

  /// Fire-and-forget ad warmup. The kit guards duplicate loads internally.
  static void preloadAds() {
    if (GameKit.iap.adsRemoved.value) return;
    unawaited(GameKit.ads.preloadAds());
  }

  static Future<void> presentAfterLevel({
    required BuildContext context,
    required bool failed,
  }) async {
    if (GameKit.iap.adsRemoved.value) return;

    var shouldShow = false;
    final sub = GameKit.ads.onShouldShowInterstitial.listen((_) {
      shouldShow = true;
    });
    try {
      await GameKit.ads.levelCompleted(failed: failed);
    } finally {
      await sub.cancel();
    }

    if (!shouldShow) return;
    if (!context.mounted) return;
    await GameKit.ads.runInterstitialCycle(context: context);
  }

  static Future<void> detach() async {}
}
