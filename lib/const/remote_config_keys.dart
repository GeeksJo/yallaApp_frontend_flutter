/// Firebase Remote Config parameter names.
abstract final class RemoteConfigKeys {
  static const String adsEnabled = 'ads_enabled';

  static const String interstitialCooldownSeconds =
      'interstitial_cooldown_seconds';

  static const String levelPlayAppKeyAndroid = 'levelplay_app_key_android';
  static const String levelPlayAppKeyIos = 'levelplay_app_key_ios';

  static const String levelPlayAndroidBannerId = 'levelplay_android_banner_id';
  static const String levelPlayAndroidInterstitialId =
      'levelplay_android_interstitial_id';
  static const String levelPlayAndroidRewardedId =
      'levelplay_android_rewarded_id';
  static const String levelPlayAndroidNativeId = 'levelplay_android_native_id';
  static const String levelPlayIosBannerId = 'levelplay_ios_banner_id';
  static const String levelPlayIosInterstitialId =
      'levelplay_ios_interstitial_id';
  static const String levelPlayIosRewardedId = 'levelplay_ios_rewarded_id';
  static const String levelPlayIosNativeId = 'levelplay_ios_native_id';

  /// Force update, per store (game kit standard). Raise one only once that
  /// version is live on that store. Blank falls back to the legacy shared
  /// `min_required_version`, which released builds up to 1.0.11 read.
  static const String minRequiredVersionAndroid =
      'min_required_version_android';
  static const String minRequiredVersionIos = 'min_required_version_ios';
  static const String androidStoreUrl = 'android_store_url';
  static const String iosStoreUrl = 'ios_store_url';

  static const String showAppMoved = 'show_app_moved';
  static const String newAndroidStoreUrl = 'new_android_store_url';
  static const String newIosStoreUrl = 'new_ios_store_url';
}
