import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:game_kit/game_kit.dart';

/// Remote Config parameter names published in the Firebase console.
///
/// Keep these spellings: renaming one silently falls back to the compiled
/// default instead of erroring, which is the hardest kind of config bug to
/// notice.
abstract final class RemoteConfigKeys {
  /// Ads kill switch. Only a value actually set on the server turns ads off.
  static const String adsEnabled = 'ads_enabled';

  /// Force update (host project, not the kit's).
  static const String minRequiredVersion = 'min_required_version';
  static const String androidStoreUrl = 'android_store_url';
  static const String iosStoreUrl = 'ios_store_url';

  /// App-moved gate.
  static const String showAppMoved = 'show_app_moved';
  static const String newAndroidStoreUrl = 'new_android_store_url';
  static const String newIosStoreUrl = 'new_ios_store_url';
}

/// The host `[DEFAULT]` Firebase app, Remote Config, and the ads kill switch.
///
/// This app had no Firebase at all, which meant no way to switch ads off
/// without shipping a release - the only app in the portfolio in that state.
///
/// **Everything here degrades to defaults when Firebase is not configured.**
/// `Firebase.initializeApp()` reads `android/app/google-services.json` and
/// `ios/Runner/GoogleService-Info.plist` natively; until those two files are
/// added, [initialize] logs and returns, [isReady] stays false, every getter
/// answers with its caller's default, and ads stay **on**. The app must not
/// fail to launch over a missing config file, and a missing kill switch must
/// not read as "ads off".
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  FirebaseRemoteConfig? _remoteConfig;
  bool _ready = false;
  Future<void>? _initFuture;

  /// True once Remote Config has values that can be trusted.
  bool get isReady => _ready && _remoteConfig != null;

  /// Mirrors [resolveAdsEnabled] after each fetch, for widgets that listen.
  final ValueNotifier<bool> adsEnabled = ValueNotifier<bool>(true);

  /// Brings up `[DEFAULT]` Firebase and does one Remote Config fetch.
  ///
  /// Single-flight, and safe to call when Firebase is not configured yet.
  Future<void> initialize() => _initFuture ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    try {
      if (Firebase.apps.isEmpty) {
        // No generated `firebase_options.dart`: on Android and iOS this reads
        // the native config files, so adding those two files is the only step
        // left. Throws if they are absent, which the catch below absorbs.
        await Firebase.initializeApp();
      }

      final FirebaseRemoteConfig rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 1)
              : Duration.zero,
        ),
      );
      await rc.setDefaults(<String, dynamic>{
        RemoteConfigKeys.adsEnabled: true,
        RemoteConfigKeys.minRequiredVersion: '',
        RemoteConfigKeys.androidStoreUrl: '',
        RemoteConfigKeys.iosStoreUrl: '',
        RemoteConfigKeys.showAppMoved: false,
        RemoteConfigKeys.newAndroidStoreUrl: '',
        RemoteConfigKeys.newIosStoreUrl: '',
      });

      _remoteConfig = rc;
      _ready = true;

      await rc.fetchAndActivate();
      _applyAdsEnabled();

      // A console publish mid-session updates the switch without a relaunch.
      rc.onConfigUpdated.listen((_) async {
        await rc.activate();
        _applyAdsEnabled();
      });
    } on Object catch (error) {
      // Almost always "no google-services.json yet". Ads stay enabled.
      //
      // One line, no stack: this is an expected state until the config files
      // land, and a stack trace here reads like a crash in test output.
      debugPrint('Firebase not configured, running without it: $error');
      _ready = false;
    }
  }

  /// Publishes a newly resolved kill-switch value to the app and the kit.
  ///
  /// Interstitials re-read the switch at show time, but the kit's banner slot
  /// hangs off a ValueNotifier and adsEnabled reaches it as a closure, which
  /// cannot be listened to - so the kit is told to look again.
  void _applyAdsEnabled() {
    adsEnabled.value = resolveAdsEnabled();
    if (GameKit.isInitialized) {
      GameKit.ads.refreshAdsEnabled();
    }
  }

  /// Remote Config when the server has a value, otherwise `true`.
  ///
  /// Only a value **actually set on the server** can turn ads off. An absent
  /// key, a failed fetch or missing Firebase all leave ads on: the switch
  /// exists to stop ads deliberately, never by accident.
  bool resolveAdsEnabled() {
    final FirebaseRemoteConfig? rc = _remoteConfig;
    if (rc == null || !_ready) return true;

    final RemoteConfigValue value = rc.getValue(RemoteConfigKeys.adsEnabled);
    if (value.source != ValueSource.valueRemote) return true;

    final String raw = value.asString().trim().toLowerCase();
    if (raw.isEmpty) return true;
    return raw != 'false' && raw != '0' && raw != 'no';
  }

  String getString(String key) {
    final FirebaseRemoteConfig? rc = _remoteConfig;
    if (rc == null || !_ready) return '';
    return rc.getString(key).trim();
  }

  int getInt(String key, {required int defaultValue}) {
    final FirebaseRemoteConfig? rc = _remoteConfig;
    if (rc == null || !_ready) return defaultValue;
    final RemoteConfigValue value = rc.getValue(key);
    // Firebase answers a key that does not exist with 0 rather than an error,
    // so an unset key must not read as a deliberate zero.
    if (value.source == ValueSource.valueStatic) return defaultValue;
    return value.asInt();
  }
}

/// Bridges [FirebaseService] to the kit's Remote Config interface.
///
/// `extends`, not `implements`: the kit gives `getBool` and `getDouble`
/// concrete bodies that parse [getString], and `implements` would not inherit
/// them, so this class would have to hand-roll the same two parsers.
class YallaRemoteConfigAdapter extends GameKitRemoteConfig {
  const YallaRemoteConfigAdapter();

  @override
  bool get isReady => FirebaseService.instance.isReady;

  @override
  String getString(String key, {String defaultValue = ''}) {
    final String value = FirebaseService.instance.getString(key);
    return value.isEmpty ? defaultValue : value;
  }

  @override
  int getInt(String key, {required int defaultValue}) =>
      FirebaseService.instance.getInt(key, defaultValue: defaultValue);
}
