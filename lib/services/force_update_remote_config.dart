import 'package:game_kit/game_kit.dart';

import '../const/remote_config_keys.dart';

class YallaForceUpdateRemoteConfig extends GameKitRemoteConfig {
  const YallaForceUpdateRemoteConfig(this._host);

  final GameKitRemoteConfig _host;

  @override
  bool get isReady => _host.isReady;

  @override
  String getString(String key, {String defaultValue = ''}) {
    // The kit uses suffix-style platform keys and a shared fallback. Yalla
    // uses prefix-style keys and deliberately disables the shared minimum.
    if (key == ForceUpdateRemoteConfigKeys.minRequiredVersion) {
      return defaultValue;
    }
    final hostKey = switch (key) {
      ForceUpdateRemoteConfigKeys.minRequiredVersionAndroid =>
        RemoteConfigKeys.androidMinRequiredVersion,
      ForceUpdateRemoteConfigKeys.minRequiredVersionIos =>
        RemoteConfigKeys.iosMinRequiredVersion,
      _ => key,
    };
    return _host.getString(hostKey, defaultValue: defaultValue);
  }

  @override
  int getInt(String key, {required int defaultValue}) =>
      _host.getInt(key, defaultValue: defaultValue);
}
