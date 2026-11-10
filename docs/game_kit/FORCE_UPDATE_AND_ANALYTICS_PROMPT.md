# Force update + kit Firebase (game_kit)

Copy this file into Cursor when wiring **force update** and **kit Remote Config** into a host app that already uses `game_kit`.

Analytics needs no wiring here: every kit event goes to the host's own property. See `docs/ANALYTICS.md`.

---

## Host setup

```dart
// Host Firebase (force update RC)
await Firebase.initializeApp();
await FirebaseRemoteConfig.instance.fetchAndActivate();
final androidMinVersion = FirebaseRemoteConfig.instance
    .getString('min_required_version_android');
final iosMinVersion = FirebaseRemoteConfig.instance
    .getString('min_required_version_ios');

// Kit Firebase (shared Remote Config: ad timing, contact)
await GameKit.initialize(
  GameKitConfig(
    crossPromoAppIdentifier: 'com.geeksjo.barra',
    firebase: GameKitFirebaseConfig.builtIn(),
    // ...iap, ads, share, storage
  ),
);

final forceUpdateConfig = ForceUpdateConfig(
  androidMinRequiredVersion: androidMinVersion,
  iosMinRequiredVersion: iosMinVersion,
  iosAppId: '6763862332',
  androidPackageName: 'com.majoon.yalla',
  // colors...
);

runApp(
  ForceUpdateGate(
    config: forceUpdateConfig,
    service: ForceUpdateService(
      config: forceUpdateConfig,
      remoteConfig: const YallaRemoteConfigAdapter(),
    ),
    strings: (c) => ForceUpdateStrings.arabic(),
    child: MyApp(),
  ),
);
```

## Two Firebase projects

| Concern | Firebase project |
| ------- | ---------------- |
| Force update `min_required_version_android` / `min_required_version_ios` | **Host** `[DEFAULT]` |
| Ads cooldown `interstitial_cooldown_seconds` | **Kit** `game_kit` app |
| All analytics, More Games included | **Host** `[DEFAULT]` |

The installed version is read by the kit. Yalla's adapter translates the key
names to the kit's platform keys and disables its legacy shared fallback.
For live updates and resume checks, use the existing `HostEmergencyGate`,
which re-reads the active host values on each check. A missing or empty
platform minimum allows that platform through. Publish each minimum only
after its version is available on the corresponding store.

## Kit Remote Config

| Key | Default |
| --- | ------- |
| `interstitial_cooldown_seconds` | `40` |
| `support_email` | `office@majoonstudio.com` |
| `website_url` | `https://majoonstudio.com` |

## FlutterFire in this package

Run `flutterfire configure` in the package root and update `lib/firebase_options.dart`.
