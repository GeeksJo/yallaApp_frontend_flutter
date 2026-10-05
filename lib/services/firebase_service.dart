import 'dart:async';

import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:game_kit/game_kit.dart';

import '../const/remote_config_keys.dart';

enum RemoteConfigEntrySource { staticValue, defaultValue, remoteValue }

@visibleForTesting
class RemoteConfigEntry {
  const RemoteConfigEntry({required this.source, required this.stringValue});

  final RemoteConfigEntrySource source;
  final String stringValue;

  bool get isRemote => source == RemoteConfigEntrySource.remoteValue;
}

@visibleForTesting
abstract class RemoteConfigClient {
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  });

  Future<void> setDefaults(Map<String, Object> defaults);

  Future<bool> activate();

  Future<bool> fetchAndActivate();

  RemoteConfigEntry getValue(String key);

  Stream<void> get onConfigUpdated;
}

class _FirebaseRemoteConfigClient implements RemoteConfigClient {
  _FirebaseRemoteConfigClient(this._delegate);

  final FirebaseRemoteConfig _delegate;

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) {
    return _delegate.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: fetchTimeout,
        minimumFetchInterval: minimumFetchInterval,
      ),
    );
  }

  @override
  Future<void> setDefaults(Map<String, Object> defaults) {
    return _delegate.setDefaults(defaults);
  }

  @override
  Future<bool> activate() => _delegate.activate();

  @override
  Future<bool> fetchAndActivate() => _delegate.fetchAndActivate();

  @override
  RemoteConfigEntry getValue(String key) {
    final RemoteConfigValue value = _delegate.getValue(key);
    return RemoteConfigEntry(
      source: switch (value.source) {
        ValueSource.valueRemote => RemoteConfigEntrySource.remoteValue,
        ValueSource.valueDefault => RemoteConfigEntrySource.defaultValue,
        ValueSource.valueStatic => RemoteConfigEntrySource.staticValue,
      },
      stringValue: value.asString(),
    );
  }

  @override
  Stream<void> get onConfigUpdated => _delegate.onConfigUpdated.map((_) {});
}

typedef RemoteConfigClientFactory = RemoteConfigClient Function();
typedef DefaultFirebaseInitializer = Future<void> Function();

/// The host `[DEFAULT]` Firebase app, Remote Config, and the ads kill switch.
///
/// **Everything here degrades to defaults when Firebase is not configured.**
/// The app must not fail to launch over a missing config file, and a missing
/// kill switch must not read as "ads off".
class FirebaseService {
  FirebaseService._({
    DefaultFirebaseInitializer? ensureDefaultFirebaseApp,
    RemoteConfigClientFactory? remoteConfigFactory,
  }) : _ensureDefaultFirebaseApp =
           ensureDefaultFirebaseApp ?? _ensureDefaultFirebaseAppProduction,
       _remoteConfigFactory =
           remoteConfigFactory ?? _remoteConfigFactoryProduction;

  @visibleForTesting
  FirebaseService.forTesting({
    required DefaultFirebaseInitializer ensureDefaultFirebaseApp,
    required RemoteConfigClientFactory remoteConfigFactory,
  }) : this._(
         ensureDefaultFirebaseApp: ensureDefaultFirebaseApp,
         remoteConfigFactory: remoteConfigFactory,
       );

  static final FirebaseService instance = FirebaseService._();

  static const Duration _fetchTimeout = Duration(seconds: 10);
  static const Duration _releaseFetchInterval = Duration(hours: 1);

  static const Map<String, Object> _defaults = <String, Object>{
    RemoteConfigKeys.adsEnabled: true,
    RemoteConfigKeys.interstitialCooldownSeconds: 40,
    RemoteConfigKeys.levelPlayAppKeyAndroid: '',
    RemoteConfigKeys.levelPlayAppKeyIos: '',
    RemoteConfigKeys.levelPlayAndroidBannerId: '',
    RemoteConfigKeys.levelPlayAndroidInterstitialId: '',
    RemoteConfigKeys.levelPlayAndroidRewardedId: '',
    RemoteConfigKeys.levelPlayAndroidNativeId: '',
    RemoteConfigKeys.levelPlayIosBannerId: '',
    RemoteConfigKeys.levelPlayIosInterstitialId: '',
    RemoteConfigKeys.levelPlayIosRewardedId: '',
    RemoteConfigKeys.levelPlayIosNativeId: '',
    RemoteConfigKeys.minRequiredVersion: '',
    RemoteConfigKeys.androidStoreUrl: '',
    RemoteConfigKeys.iosStoreUrl: '',
    RemoteConfigKeys.showAppMoved: false,
    RemoteConfigKeys.newAndroidStoreUrl: '',
    RemoteConfigKeys.newIosStoreUrl: '',
  };

  final DefaultFirebaseInitializer _ensureDefaultFirebaseApp;
  final RemoteConfigClientFactory _remoteConfigFactory;

  RemoteConfigClient? _remoteConfig;
  bool _ready = false;
  bool _hasDefaultFirebaseApp = false;
  Future<void>? _initFuture;
  Future<void>? _refreshFuture;
  StreamSubscription<void>? _realtimeSubscription;
  LevelPlayPlacementIds? _levelPlayPlacements;

  /// True once cached, fetched, or default Remote Config values are usable.
  bool get isReady => _ready && _remoteConfig != null;

  /// True once the host `[DEFAULT]` Firebase app exists.
  ///
  /// FCM depends on the default app but not on Remote Config readiness, so it
  /// must not use [isReady] as a proxy.
  bool get hasDefaultFirebaseApp => _hasDefaultFirebaseApp;

  /// Increments whenever activated values are synced into host-facing state.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Mirrors [resolveAdsEnabled] after each fetch, for widgets that listen.
  final ValueNotifier<bool> adsEnabled = ValueNotifier<bool>(true);

  /// Mirrors [resolveAppMoved] after each fetch. Default off.
  final ValueNotifier<bool> appMovedEnabled = ValueNotifier<bool>(false);

  /// Brings up `[DEFAULT]` Firebase and activates cached Remote Config values.
  ///
  /// Single-flight, safe when Firebase is not configured, and deliberately
  /// cache-first: the launch path does not wait for a network fetch.
  Future<void> initialize() => _initFuture ??= _initializeOnce();

  /// Fetches and activates values now, coalescing overlapping requests.
  Future<void> refresh() => _refreshFuture ??= _refreshOnce();

  Future<void> _initializeOnce() async {
    try {
      await _ensureDefaultFirebaseApp();
      _hasDefaultFirebaseApp = true;

      final RemoteConfigClient rc = _remoteConfigFactory();
      await rc.setConfigSettings(
        fetchTimeout: _fetchTimeout,
        minimumFetchInterval: kReleaseMode
            ? _releaseFetchInterval
            : Duration.zero,
      );
      await rc.setDefaults(_defaults);

      _remoteConfig = rc;
      _ready = true;

      try {
        await rc.activate();
      } on Object catch (error) {
        debugPrint('Remote Config cache activate failed: $error');
      }

      _syncFromRemoteConfig();
      _listenForRemoteUpdates(rc);
      unawaited(refresh());
    } on Object catch (error) {
      debugPrint('Firebase not configured, running without it: $error');
      _ready = false;
    }
  }

  Future<void> _refreshOnce() async {
    final RemoteConfigClient? rc = _remoteConfig;
    if (rc == null || !_ready) {
      _refreshFuture = null;
      return;
    }

    try {
      await rc.fetchAndActivate().timeout(_fetchTimeout);
      _syncFromRemoteConfig();
    } on TimeoutException {
      debugPrint('Remote Config refresh timed out');
    } on Object catch (error) {
      debugPrint('Remote Config refresh failed: $error');
    } finally {
      _refreshFuture = null;
    }
  }

  void _listenForRemoteUpdates(RemoteConfigClient rc) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = rc.onConfigUpdated.listen(
      (_) async {
        try {
          await rc.activate();
          _syncFromRemoteConfig();
        } on Object catch (error) {
          debugPrint('Remote Config realtime activate failed: $error');
        }
      },
      onError: (Object error) {
        debugPrint('Remote Config realtime listen failed: $error');
      },
    );
  }

  void _syncFromRemoteConfig() {
    adsEnabled.value = resolveAdsEnabled();
    appMovedEnabled.value = resolveAppMoved();
    revision.value += 1;

    // Interstitials re-read the switch at show time, but the kit's banner slot
    // hangs off a ValueNotifier and adsEnabled reaches it as a closure, which
    // cannot be listened to - so the kit is told to look again.
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
    final RemoteConfigClient? rc = _remoteConfig;
    if (rc == null || !_ready) return true;

    final RemoteConfigEntry value = rc.getValue(RemoteConfigKeys.adsEnabled);
    if (!value.isRemote) return true;

    final String raw = value.stringValue.trim().toLowerCase();
    if (raw.isEmpty) return true;
    return raw != 'false' && raw != '0' && raw != 'no';
  }

  /// Published cooldown, or [defaultValue] when the host console has not set one.
  ///
  /// A published `0` is kept. The kit still prefers a kit-project value when
  /// this host key is unset, because [readForKit] does not invent `40`.
  int resolveInterstitialCooldownSeconds({int defaultValue = 40}) {
    return getInt(
      RemoteConfigKeys.interstitialCooldownSeconds,
      defaultValue: defaultValue,
    );
  }

  /// LevelPlay ids for [AdsConfig], frozen on the first call.
  ///
  /// The LevelPlay SDK takes its app key and unit ids at init and cannot be
  /// re-keyed, so a later console publish waits for the next cold start.
  LevelPlayPlacementIds freezeLevelPlayPlacements() {
    return _levelPlayPlacements ??= resolveLevelPlayPlacements();
  }

  /// Published LevelPlay ids. An unset key stays empty so ads load from
  /// Remote Config only.
  ///
  /// Native ids are included even though [LevelPlayProdUnitIds] has no native
  /// slot: they stay on this snapshot so a published native unit is not dropped.
  LevelPlayPlacementIds resolveLevelPlayPlacements() {
    return LevelPlayPlacementIds(
      appKeyAndroid: getString(RemoteConfigKeys.levelPlayAppKeyAndroid),
      appKeyIos: getString(RemoteConfigKeys.levelPlayAppKeyIos),
      bannerAndroid: getString(RemoteConfigKeys.levelPlayAndroidBannerId),
      bannerIos: getString(RemoteConfigKeys.levelPlayIosBannerId),
      interstitialAndroid: getString(
        RemoteConfigKeys.levelPlayAndroidInterstitialId,
      ),
      interstitialIos: getString(RemoteConfigKeys.levelPlayIosInterstitialId),
      rewardedAndroid: getString(RemoteConfigKeys.levelPlayAndroidRewardedId),
      rewardedIos: getString(RemoteConfigKeys.levelPlayIosRewardedId),
      nativeAndroid: getString(RemoteConfigKeys.levelPlayAndroidNativeId),
      nativeIos: getString(RemoteConfigKeys.levelPlayIosNativeId),
    );
  }

  String resolveMinRequiredVersion({String defaultValue = ''}) {
    return readForKit(
      RemoteConfigKeys.minRequiredVersion,
      defaultValue: defaultValue,
    );
  }

  String resolveAndroidStoreUrl({String defaultValue = ''}) {
    return readForKit(
      RemoteConfigKeys.androidStoreUrl,
      defaultValue: defaultValue,
    );
  }

  String resolveIosStoreUrl({String defaultValue = ''}) {
    return readForKit(RemoteConfigKeys.iosStoreUrl, defaultValue: defaultValue);
  }

  String resolveNewAndroidStoreUrl({String defaultValue = ''}) {
    return readForKit(
      RemoteConfigKeys.newAndroidStoreUrl,
      defaultValue: defaultValue,
    );
  }

  String resolveNewIosStoreUrl({String defaultValue = ''}) {
    return readForKit(
      RemoteConfigKeys.newIosStoreUrl,
      defaultValue: defaultValue,
    );
  }

  /// Published host value for a kit read.
  ///
  /// Local defaults stay hidden. A non-empty string here overrides the kit
  /// Firebase project, so an unset key must come back empty.
  String readForKit(String key, {String defaultValue = ''}) {
    return switch (key) {
      RemoteConfigKeys.adsEnabled ||
      RemoteConfigKeys.interstitialCooldownSeconds ||
      RemoteConfigKeys.levelPlayAppKeyAndroid ||
      RemoteConfigKeys.levelPlayAppKeyIos ||
      RemoteConfigKeys.levelPlayAndroidBannerId ||
      RemoteConfigKeys.levelPlayAndroidInterstitialId ||
      RemoteConfigKeys.levelPlayAndroidRewardedId ||
      RemoteConfigKeys.levelPlayAndroidNativeId ||
      RemoteConfigKeys.levelPlayIosBannerId ||
      RemoteConfigKeys.levelPlayIosInterstitialId ||
      RemoteConfigKeys.levelPlayIosRewardedId ||
      RemoteConfigKeys.levelPlayIosNativeId ||
      RemoteConfigKeys.minRequiredVersion ||
      RemoteConfigKeys.androidStoreUrl ||
      RemoteConfigKeys.iosStoreUrl ||
      RemoteConfigKeys.showAppMoved ||
      RemoteConfigKeys.newAndroidStoreUrl ||
      RemoteConfigKeys.newIosStoreUrl => getString(
        key,
        defaultValue: defaultValue,
      ),
      _ => getString(key, defaultValue: defaultValue),
    };
  }

  /// Remote Config app-moved flag. Missing, default, and malformed values are
  /// treated as off; only a published truthy value blocks the old listing.
  bool resolveAppMoved() {
    final RemoteConfigClient? rc = _remoteConfig;
    if (rc == null || !_ready) return false;

    final RemoteConfigEntry value = rc.getValue(RemoteConfigKeys.showAppMoved);
    if (!value.isRemote) return false;

    final String raw = value.stringValue.trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  /// Returns a published Remote Config string, otherwise [defaultValue].
  ///
  /// Host defaults are intentionally not exposed through the kit adapter:
  /// LayeredGameKitRemoteConfig treats any non-empty host string as an override,
  /// and compiled host defaults must not mask shared kit console values.
  String getString(String key, {String defaultValue = ''}) {
    final RemoteConfigClient? rc = _remoteConfig;
    if (rc == null || !_ready) return defaultValue;

    final RemoteConfigEntry value = rc.getValue(key);
    if (!value.isRemote) return defaultValue;

    final String trimmed = value.stringValue.trim();
    return trimmed.isEmpty ? defaultValue : trimmed;
  }

  int getInt(String key, {required int defaultValue}) {
    final RemoteConfigClient? rc = _remoteConfig;
    if (rc == null || !_ready) return defaultValue;

    final RemoteConfigEntry value = rc.getValue(key);
    if (!value.isRemote) return defaultValue;

    final String raw = value.stringValue.trim();
    if (raw.isEmpty) return defaultValue;
    return int.tryParse(raw) ?? defaultValue;
  }

  @visibleForTesting
  Future<void> disposeForTesting() async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  static Future<void> _ensureDefaultFirebaseAppProduction() async {
    try {
      Firebase.app();
      return;
    } on FirebaseException catch (error) {
      if (error.code != 'no-app') rethrow;
    }

    await Firebase.initializeApp();
  }

  static RemoteConfigClient _remoteConfigFactoryProduction() {
    return _FirebaseRemoteConfigClient(FirebaseRemoteConfig.instance);
  }
}

/// Bridges [FirebaseService] to the kit's Remote Config interface.
///
/// `extends`, not `implements`: the kit gives `getBool` and `getDouble`
/// concrete bodies that parse [getString], and `implements` would not inherit
/// them, so this class would have to hand-roll the same two parsers.
class YallaRemoteConfigAdapter extends GameKitRemoteConfig {
  const YallaRemoteConfigAdapter([this._service]);

  final FirebaseService? _service;

  FirebaseService get _firebase => _service ?? FirebaseService.instance;

  @override
  bool get isReady => _firebase.isReady;

  @override
  String getString(String key, {String defaultValue = ''}) {
    return _firebase.readForKit(key, defaultValue: defaultValue);
  }

  @override
  int getInt(String key, {required int defaultValue}) {
    if (key == RemoteConfigKeys.interstitialCooldownSeconds) {
      return _firebase.resolveInterstitialCooldownSeconds(
        defaultValue: defaultValue,
      );
    }
    return _firebase.getInt(key, defaultValue: defaultValue);
  }
}

/// App keys and ad unit ids captured from Remote Config for one process.
class LevelPlayPlacementIds {
  const LevelPlayPlacementIds({
    required this.appKeyAndroid,
    required this.appKeyIos,
    required this.bannerAndroid,
    required this.bannerIos,
    required this.interstitialAndroid,
    required this.interstitialIos,
    required this.rewardedAndroid,
    required this.rewardedIos,
    required this.nativeAndroid,
    required this.nativeIos,
  });

  final String appKeyAndroid;
  final String appKeyIos;
  final String bannerAndroid;
  final String bannerIos;
  final String interstitialAndroid;
  final String interstitialIos;
  final String rewardedAndroid;
  final String rewardedIos;
  final String nativeAndroid;
  final String nativeIos;
}
