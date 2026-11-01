import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:yalla/const/remote_config_keys.dart';
import 'package:yalla/services/force_update_remote_config.dart';

void main() {
  for (final isIos in <bool>[false, true]) {
    final platform = isIos ? 'iOS' : 'Android';
    final minimumKey = isIos
        ? RemoteConfigKeys.iosMinRequiredVersion
        : RemoteConfigKeys.androidMinRequiredVersion;
    final otherKey = isIos
        ? RemoteConfigKeys.androidMinRequiredVersion
        : RemoteConfigKeys.iosMinRequiredVersion;
    final storeKey = isIos
        ? RemoteConfigKeys.iosStoreUrl
        : RemoteConfigKeys.androidStoreUrl;

    group(platform, () {
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
              'min_required_version': '9.0.0',
              'min_required_version_android': '9.0.0',
              'min_required_version_ios': '9.0.0',
            },
          );

          expect(status.isRequired, isFalse);
          expect(status.minimumVersion, isNull);
        });
      }

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
    remoteConfig: YallaForceUpdateRemoteConfig(
      FakeGameKitRemoteConfig(isReady: isReady, strings: strings),
    ),
    installedVersionLoader: () async => '1.0.9',
    isIos: isIos,
  ).evaluate();
}
