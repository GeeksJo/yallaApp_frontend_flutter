import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
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
}
