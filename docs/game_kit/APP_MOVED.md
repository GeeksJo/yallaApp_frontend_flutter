# App moved

A store listing cannot change its package / bundle id. The last update on
the **old** identifier needs a hard stop that sends people to the new app -
not a snackbar they can dismiss.

`AppMovedGate` blocks the tree when host Remote Config `show_app_moved` is
true. Download URLs come from `new_ios_store_url` / `new_android_store_url`.

`lib/src/app_moved/` · wrap the app root with `AppMovedGate`

## Why this shape

This reads the **host** `[DEFAULT]` Firebase Remote Config, not the kit
`game_kit` app. The console flag is the only on/off switch - publish
`show_app_moved=true` when the new listings exist, and turn it off (or omit
the gate) on any binary that should keep playing.

Force-update keeps `ios_store_url` / `android_store_url` for the **current**
listing. These `new_*` keys are only the successor.

If RC is not ready, or the flag is not `true`/`1`, the gate **does not
block** (fail open).

Layout matches the force-update screen: centered illustration, title, body
paragraphs, full-width button. Branding uses the same four emergency colors
as `ForceUpdateConfig` (`backgroundColor`, `textColor`, `buttonColor`,
`buttonTextColor`). Default art is the kit move icon
(`kGameKitAppMovedDefaultIcon`) - not the force-update rocket and not a host
app logo. Optional `illustration` widget or `illustrationAsset` override.
Copy lives in the kit (`AppMovedStrings` EN/AR from the ambient locale).

Pass `recheck` (a `ValueNotifier` from the host RC adapter) so a console
publish can swap the tree without a new build.

## Host wiring

```dart
AppMovedGate(
  config: AppMovedConfig(
    backgroundColor: ...,
    textColor: ...,
    buttonColor: ...,
    buttonTextColor: ...,
  ),
  service: AppMovedService(remoteConfig: hostRcAdapter),
  recheck: hostAppMovedNotifier,
  child: MyApp(),
)
```

## Console

1. Add Boolean `show_app_moved` (default `false`) and publish.
2. Fill `new_ios_store_url` / `new_android_store_url`.
3. When ready, set `show_app_moved` to `true` and publish.

## Known limits

- People who never open this update never see the screen.
- An empty store URL still shows the screen; the button reports unavailable.
- Local reminder copy that mentions the move is a host concern (chosen at
  GameKit init from the RC cache).
