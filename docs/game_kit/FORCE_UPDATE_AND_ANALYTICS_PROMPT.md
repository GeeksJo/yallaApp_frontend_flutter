# Force update + kit Firebase (game_kit)

Copy this file into Cursor when wiring **force update** and **kit Remote Config** into a host app that already uses `game_kit`.

Analytics needs no wiring here: every kit event goes to the host's own property. See `docs/ANALYTICS.md`.

---

## Host setup

```dart
// Host Firebase (force update RC)
await Firebase.initializeApp();
await FirebaseRemoteConfig.instance.fetchAndActivate();
final minVersion = FirebaseRemoteConfig.instance
    .getString('min_required_version');

// Kit Firebase (shared Remote Config: ad timing, contact)
await GameKit.initialize(
  GameKitConfig(
    crossPromoAppIdentifier: 'com.geeksjo.barra',
    firebase: GameKitFirebaseConfig.builtIn(),
    // ...iap, ads, share, storage
  ),
);

runApp(
  ForceUpdateGate(
    config: ForceUpdateConfig(
      currentVersion: packageInfo.version,
      minRequiredVersion: minVersion,
      iosAppId: '...',
      androidPackageName: 'com.geeksjo.barra',
      // colors...
    ),
    strings: (c) => ForceUpdateStrings.arabic(),
    child: MyApp(),
  ),
);
```

## Two Firebase projects

| Concern | Firebase project |
| ------- | ---------------- |
| Force update `min_required_version` | **Host** `[DEFAULT]` |
| Ads cooldown `interstitial_cooldown_seconds` | **Kit** `game_kit` app |
| All analytics, More Games included | **Host** `[DEFAULT]` |

## Kit Remote Config

| Key | Default |
| --- | ------- |
| `interstitial_cooldown_seconds` | `40` |
| `support_email` | `office@majoonstudio.com` |
| `website_url` | `https://majoonstudio.com` |

## FlutterFire in this package

Run `flutterfire configure` in the package root and update `lib/firebase_options.dart`.
