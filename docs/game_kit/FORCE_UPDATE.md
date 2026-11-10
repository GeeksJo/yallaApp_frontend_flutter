# Force update

A broken puzzle or a store-rejected binary needs a **hard stop**, not a
snackbar. Yalla's `HostEmergencyGate` blocks the tree when host Remote Config
`min_required_version_android` (Android) or `min_required_version_ios` (iOS)
(the game kit standard keys) is higher than the installed app version.

`lib/src/force_update/` · wrap the app with `ForceUpdateGate`

## Why this shape

This reads the **host** `[DEFAULT]` Firebase Remote Config, not the kit
`game_kit` app. Store URLs can be overridden with RC `ios_store_url` /
`android_store_url`; otherwise they are built from `iosAppId` /
`androidPackageName`.

The kit reads the installed version through `PackageInfo.version`, which
comes from the host `pubspec.yaml`. Do not pass a hardcoded current version.

If RC is not ready or the installed version is unavailable, the gate **does
not block** (fail open). A blank platform minimum falls back to the legacy
shared `min_required_version`; when that is blank too, nothing blocks.

Compare with `isVersionLowerThan` (numeric segments). Branding
(colors, illustration) is per-app on `ForceUpdateConfig`.

## Host wiring

```dart
HostEmergencyGate(
  remoteConfig: const YallaRemoteConfigAdapter(), // host [DEFAULT] RC
  refresh: FirebaseService.instance.refresh,
  recheck: FirebaseService.instance.revision,
  child: MyApp(),
)
```

The gate passes the same host adapter to `ForceUpdateService`; key names go
to Remote Config unchanged (SA-408). The other platform's minimum never blocks
this platform.

Set each minimum only to a version available on that store. Keep the shared
`min_required_version` for released builds up to 1.0.11, which read only it.
The old `android_min_required_version` / `ios_min_required_version` were read
only by unreleased builds; delete them with the shared key once a build on the
standard keys is live on both stores.

## Known limits

- Not a soft “please update” banner. No skip / later.
- Kit Firebase `GameKitRemoteConfigKeys.minRequiredVersion` is documented for
  adapters; the gate does not use kit RC.
