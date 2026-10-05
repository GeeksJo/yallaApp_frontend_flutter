# Force update

A broken puzzle or a store-rejected binary needs a **hard stop**, not a
snackbar. `ForceUpdateGate` blocks the tree when host Remote Config
`min_required_version` is higher than `ForceUpdateConfig.currentVersion`.

`lib/src/force_update/` · wrap the app with `ForceUpdateGate`

## Why this shape

This reads the **host** `[DEFAULT]` Firebase Remote Config, not the kit
`game_kit` app. Store URLs can be overridden with RC `ios_store_url` /
`android_store_url`; otherwise they are built from `iosAppId` /
`androidPackageName`.

If RC is not ready, the gate **does not block** (fail open) so a config
outage cannot brick installs.

Compare with `isVersionLowerThan` (numeric segments). Branding
(colors, illustration) is per-app on `ForceUpdateConfig`.

## Host wiring

```dart
ForceUpdateGate(
  config: myForceUpdateConfig,
  remoteConfig: hostRcAdapter, // host [DEFAULT] RC
  child: MyApp(),
)
```

## Known limits

- Not a soft “please update” banner. No skip / later.
- Kit Firebase `GameKitRemoteConfigKeys.minRequiredVersion` is documented for
  adapters; the gate does not use kit RC.
