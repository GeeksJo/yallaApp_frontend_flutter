import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yalla/const/remote_config_keys.dart';
import 'package:yalla/services/firebase_service.dart';

/// The ads kill switch, and what happens before Firebase is configured.
///
/// This app shipped with no Remote Config at all, so there was no way to turn
/// ads off without a release. These tests pin the two rules that make the new
/// switch safe to add to a live app:
///
/// 1. It fails **on**. A missing config file, a failed fetch or an unset key
///    must never read as "ads off" - that would silently kill revenue.
/// 2. Nothing here may throw when Firebase is absent. The config files arrive
///    separately from this code, so every build in between has to launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ads stay enabled when Firebase was never configured', () {
    // No initialize() call, so no [DEFAULT] app - the state every build is in
    // until google-services.json and GoogleService-Info.plist are added.
    expect(
      FirebaseService.instance.resolveAdsEnabled(),
      isTrue,
      reason: 'a missing config file must not read as a deliberate "ads off"',
    );
  });

  test(
    'isReady is false without Firebase, and says so rather than throwing',
    () {
      expect(FirebaseService.instance.isReady, isFalse);
    },
  );

  test('getters answer with the caller default instead of throwing', () {
    // Firebase answers an unset key with 0 / "" rather than an error, so the
    // fallbacks matter even once it is configured. An absent
    // interstitial_cooldown_seconds read as 0 means no cooldown at all.
    expect(FirebaseService.instance.getString(RemoteConfigKeys.adsEnabled), '');
    expect(
      FirebaseService.instance.getInt(
        'interstitial_cooldown_seconds',
        defaultValue: 40,
      ),
      40,
    );
    expect(
      FirebaseService.instance.getInt('a_key_nobody_created', defaultValue: 7),
      7,
    );
  });

  test('initialize completes rather than throwing with no Firebase', () async {
    // main() awaits this before runApp; if it threw, the app would not start.
    await expectLater(FirebaseService.instance.initialize(), completes);
  });

  group('the kit adapter', () {
    const YallaRemoteConfigAdapter adapter = YallaRemoteConfigAdapter();

    test('reports not-ready so the kit uses its compiled defaults', () {
      expect(adapter.isReady, isFalse);
    });

    test('hands back the default the kit asked for', () {
      expect(
        adapter.getString('support_email', defaultValue: 'x@y.z'),
        'x@y.z',
      );
      expect(
        adapter.getInt('interstitial_cooldown_seconds', defaultValue: 40),
        40,
      );
    });

    test('inherits getBool and getDouble from the kit', () {
      // It extends GameKitRemoteConfig rather than implementing it, so these
      // come from the kit and no host parser is duplicated here. If it is ever
      // changed back to `implements`, this stops compiling - which is the point.
      expect(adapter.getBool('show_app_moved', defaultValue: false), isFalse);
      expect(adapter.getBool('some_flag', defaultValue: true), isTrue);
      expect(adapter.getDouble('some_rate', defaultValue: 1.5), 1.5);
    });
  });

  group('with an injected Remote Config client', () {
    late _FakeRemoteConfigClient remoteConfig;
    late FirebaseService service;

    setUp(() {
      remoteConfig = _FakeRemoteConfigClient();
      service = FirebaseService.forTesting(
        ensureDefaultFirebaseApp: () async {},
        remoteConfigFactory: () => remoteConfig,
      );
    });

    tearDown(() async {
      remoteConfig.completeFetch();
      await service.disposeForTesting();
      await remoteConfig.dispose();
    });

    test('initializes from cache/defaults without waiting for fetch', () async {
      remoteConfig.holdFetch();

      await service.initialize();

      expect(service.isReady, isTrue);
      expect(service.hasDefaultFirebaseApp, isTrue);
      expect(remoteConfig.fetchCalls, 1);
      expect(remoteConfig.fetchCompleter?.isCompleted, isFalse);

      remoteConfig.completeFetch();
      await service.refresh();
    });

    test('does not expose local defaults as host kit overrides', () async {
      await service.initialize();
      remoteConfig.completeFetch();

      expect(
        service.getString(
          RemoteConfigKeys.interstitialCooldownSeconds,
          defaultValue: 'kit-default',
        ),
        'kit-default',
      );
      expect(
        service.getInt(
          RemoteConfigKeys.interstitialCooldownSeconds,
          defaultValue: 40,
        ),
        40,
      );
    });

    test('preserves published zero and ignores malformed integers', () async {
      remoteConfig.setRemote(RemoteConfigKeys.interstitialCooldownSeconds, '0');
      remoteConfig.setRemote(RemoteConfigTestKeys.malformedInt, 'oops');

      await service.initialize();
      remoteConfig.completeFetch();

      expect(
        service.getInt(
          RemoteConfigKeys.interstitialCooldownSeconds,
          defaultValue: 40,
        ),
        0,
      );
      expect(
        service.getInt(RemoteConfigTestKeys.malformedInt, defaultValue: 4),
        4,
      );
    });

    test('ads kill switch only turns off on a published false value', () async {
      await service.initialize();
      remoteConfig.completeFetch();

      expect(service.resolveAdsEnabled(), isTrue);

      remoteConfig.setRemote(RemoteConfigKeys.adsEnabled, '0');
      expect(service.resolveAdsEnabled(), isFalse);

      remoteConfig.setRemote(RemoteConfigKeys.adsEnabled, 'no');
      expect(service.resolveAdsEnabled(), isFalse);

      remoteConfig.setRemote(RemoteConfigKeys.adsEnabled, 'not a bool');
      expect(service.resolveAdsEnabled(), isTrue);
    });

    test('app moved is true only for a published truthy value', () async {
      await service.initialize();
      remoteConfig.completeFetch();

      expect(service.resolveAppMoved(), isFalse);

      remoteConfig.setRemote(RemoteConfigKeys.showAppMoved, 'yes');
      expect(service.resolveAppMoved(), isTrue);

      remoteConfig.setRemote(RemoteConfigKeys.showAppMoved, 'no');
      expect(service.resolveAppMoved(), isFalse);
    });

    test('realtime updates activate and publish notifier values', () async {
      await service.initialize();
      remoteConfig.completeFetch();
      final initialRevision = service.revision.value;

      remoteConfig.setRemote(RemoteConfigKeys.adsEnabled, 'false');
      remoteConfig.emitRealtimeUpdate();
      await pumpEventQueue();

      expect(remoteConfig.activateCalls, greaterThanOrEqualTo(2));
      expect(service.adsEnabled.value, isFalse);
      expect(service.revision.value, greaterThan(initialRevision));
    });

    test('refresh calls are coalesced', () async {
      await service.initialize();
      remoteConfig.completeFetch();
      await service.refresh();
      expect(remoteConfig.fetchCalls, 1);

      remoteConfig.holdFetch();
      final first = service.refresh();
      final second = service.refresh();

      expect(remoteConfig.fetchCalls, 2);
      remoteConfig.completeFetch();
      await Future.wait<void>(<Future<void>>[first, second]);
    });
  });
}

abstract final class RemoteConfigTestKeys {
  static const String malformedInt = 'test_malformed_int';
}

class _FakeRemoteConfigClient implements RemoteConfigClient {
  final Map<String, RemoteConfigEntry> _values = <String, RemoteConfigEntry>{};
  final StreamController<void> _updates = StreamController<void>.broadcast();

  Completer<bool>? fetchCompleter;
  Future<bool>? fetchResult;
  int activateCalls = 0;
  int fetchCalls = 0;

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) async {}

  @override
  Future<void> setDefaults(Map<String, Object> defaults) async {
    for (final entry in defaults.entries) {
      _values.putIfAbsent(
        entry.key,
        () => RemoteConfigEntry(
          source: RemoteConfigEntrySource.defaultValue,
          stringValue: entry.value.toString(),
        ),
      );
    }
  }

  @override
  Future<bool> activate() async {
    activateCalls += 1;
    return true;
  }

  @override
  Future<bool> fetchAndActivate() {
    fetchCalls += 1;
    final result = fetchResult;
    if (result != null) return result;
    return Future<bool>.value(true);
  }

  @override
  RemoteConfigEntry getValue(String key) {
    return _values[key] ??
        const RemoteConfigEntry(
          source: RemoteConfigEntrySource.staticValue,
          stringValue: '',
        );
  }

  @override
  Stream<void> get onConfigUpdated => _updates.stream;

  void setRemote(String key, String value) {
    _values[key] = RemoteConfigEntry(
      source: RemoteConfigEntrySource.remoteValue,
      stringValue: value,
    );
  }

  void emitRealtimeUpdate() {
    _updates.add(null);
  }

  void holdFetch() {
    fetchCompleter = Completer<bool>();
    fetchResult = fetchCompleter!.future;
  }

  void completeFetch() {
    final completer = fetchCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }
    fetchCompleter = null;
    fetchResult = null;
  }

  Future<void> dispose() => _updates.close();
}
