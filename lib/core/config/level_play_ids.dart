// App keys and ad unit IDs are public identifiers, not secrets.
// Checked against the LevelPlay dashboard (levelplay_tools_node) on 2026-11-10.

/// Compiled LevelPlay identifiers, before any Remote Config override.
///
/// A fresh install has no Remote Config cache when the ids are frozen at
/// launch, so without these its whole first session would load no ads.
abstract final class LevelPlayIds {
  static const String appKeyAndroid = '286d22c95';
  static const String appKeyIos = '286d2661d';
  static const String bannerAndroid = 'jb31fqpa4bvfm3d8';
  static const String bannerIos = 'yiyb48zj4gxxr8ms';
  static const String interstitialAndroid = 'i84sy4y6e83ghxnt';
  static const String interstitialIos = 'ssodjiwc1v2rmuiu';
  static const String nativeAndroid = 'juhjifqa745x1u1y';
  static const String nativeIos = 'pb1jjvy2day2rz2t';
  static const String rewardedAndroid = '8zbj7ngk9koobeel';
  static const String rewardedIos = '7ms0f73ajixdf2e3';
}
