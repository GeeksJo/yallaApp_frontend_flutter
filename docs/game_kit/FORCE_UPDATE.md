# Force update

A broken puzzle or a store-rejected binary needs a **hard stop**, not a
snackbar. Yalla's `HostEmergencyGate` blocks the tree when host Remote Config
`android_min_required_version` (Android) or `ios_min_required_version` (iOS)
is higher than the installed app version.

`lib/src/force_update/` · wrap the app with `ForceUpdateGate`

## Why this shape

This reads the **host** `[DEFAULT]` Firebase Remote Config, not the kit
`game_kit` app. Store URLs can be overridden with RC `ios_store_url` /
`android_store_url`; otherwise they are built from `iosAppId` /
`androidPackageName`.

The kit reads the installed version through `PackageInfo.version`, which
comes from the host `pubspec.yaml`. Do not pass a hardcoded current version.

If RC is not ready, the installed version is unavailable, or the platform's
minimum is empty, the gate **does not block** (fail open).

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

The gate passes `YallaForceUpdateRemoteConfig` to `ForceUpdateService`.
It maps the kit's `min_required_version_android` / `min_required_version_ios`
reads to Yalla's `android_min_required_version` / `ios_min_required_version`.
The old shared `min_required_version` is ignored, including when a platform
minimum is missing. The other platform's minimum never blocks this platform.

Publish the two new string parameters in the host Firebase project, with an
empty default. Set each minimum only to a version available on that store.
Keep the shared parameter for older app builds that still read it.

## Known limits

- Not a soft “please update” banner. No skip / later.
- Kit Firebase `GameKitRemoteConfigKeys.minRequiredVersion` is documented for
  adapters; the gate does not use kit RC.
