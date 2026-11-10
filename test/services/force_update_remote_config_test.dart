import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:yalla/const/remote_config_keys.dart';

void main() {
  for (final isIos in <bool>[false, true]) {
    final platform = isIos ? 'iOS' : 'Android';
    final minimumKey = isIos
        ? RemoteConfigKeys.minRequiredVersionIos
        : RemoteConfigKeys.minRequiredVersionAndroid;
    final otherKey = isIos
        ? RemoteConfigKeys.minRequiredVersionAndroid
        : RemoteConfigKeys.minRequiredVersionIos;
    final storeKey = isIos
        ? RemoteConfigKeys.iosStoreUrl
        : RemoteConfigKeys.androidStoreUrl;

    group(platform, () {
      test('host key is the kit standard key', () {
        expect(
          minimumKey,
          isIos
              ? ForceUpdateRemoteConfigKeys.minRequiredVersionIos
              : ForceUpdateRemoteConfigKeys.minRequiredVersionAndroid,
        );
      });

      test('uses its own minimum and store URL', () async {
        final status = await _evaluate(
          isIos: isIos,
          strings: <String, String>{
            minimumKey: ' 1.0.10 ',
            otherKey: '1.0.8',
            storeKey: 'https://example.com/$platform',
          },
        );

        expect(status.isRequired, isTrue);
        expect(status.minimumVersion, '1.0.10');
        expect(status.storeUrl, 'https://example.com/$platform');
      });

      for (final minimum in <String>['1.0.8', '1.0.9']) {
        test('allows installed version at or above $minimum', () async {
          final status = await _evaluate(
            isIos: isIos,
            strings: <String, String>{minimumKey: minimum, otherKey: '9.0.0'},
          );

          expect(status.isRequired, isFalse);
        });
      }

      for (final minimum in <String?>[null, '   ']) {
        test('ignores other keys when its minimum is $minimum', () async {
          final status = await _evaluate(
            isIos: isIos,
            strings: <String, String>{
              if (minimum != null) minimumKey: minimum,
              otherKey: '9.0.0',
              'android_min_required_version': '9.0.0',
              'ios_min_required_version': '9.0.0',
            },
          );

          expect(status.isRequired, isFalse);
          expect(status.minimumVersion, isNull);
        });
      }

      test('falls back to the legacy shared minimum when blank', () async {
        final status = await _evaluate(
          isIos: isIos,
          strings: <String, String>{
            minimumKey: '',
            'min_required_version': '1.0.10',
          },
        );

        expect(status.isRequired, isTrue);
      });

      test('fails open when Remote Config is not ready', () async {
        final status = await _evaluate(
          isIos: isIos,
          isReady: false,
          strings: <String, String>{minimumKey: '9.0.0'},
        );

        expect(status.isRequired, isFalse);
      });

      test('builds the platform store URL when no override is set', () async {
        final status = await _evaluate(
          isIos: isIos,
          strings: <String, String>{minimumKey: '9.0.0'},
        );

        expect(status.isRequired, isTrue);
        expect(
          status.storeUrl,
          isIos
              ? 'https://apps.apple.com/app/id6763862332'
              : 'https://play.google.com/store/apps/details?id=com.majoon.yalla',
        );
      });
    });
  }
}

Future<ForceUpdateStatus> _evaluate({
  required bool isIos,
  required Map<String, String> strings,
  bool isReady = true,
}) {
  return ForceUpdateService(
    config: const ForceUpdateConfig(
      iosAppId: '6763862332',
      androidPackageName: 'com.majoon.yalla',
      backgroundColor: Colors.black,
      textColor: Colors.white,
      buttonColor: Colors.white,
      buttonTextColor: Colors.black,
    ),
    remoteConfig: FakeGameKitRemoteConfig(isReady: isReady, strings: strings),
    installedVersionLoader: () async => '1.0.9',
    isIos: isIos,
  ).evaluate();
}
