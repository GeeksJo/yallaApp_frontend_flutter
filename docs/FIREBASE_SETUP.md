# Firebase setup

Both config files are in place, from Firebase project `yalla-f87b1`.

## Where they live

| File | Where it goes |
| --- | --- |
| `google-services.json` | `android/app/google-services.json` |
| `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist`, in the Runner target's Resources build phase (`project.pbxproj`) |

Both are from a Firebase project with an Android app registered as
`com.majoon.yalla` and an iOS app registered with the matching bundle id. To
replace them (new project, regenerated keys), drop the new files over the old
ones; the Xcode reference is by path, so no project edit is needed.

Nothing else is needed: `FirebaseService` calls `Firebase.initializeApp()` with
no options, which reads these native files directly, so there is no generated
`firebase_options.dart` to keep in sync.

## What works if they are ever missing

The app builds and runs on iOS, and every Firebase-dependent path degrades:

- `FirebaseService.isReady` stays `false`
- Remote Config getters return the caller's default
- **Ads stay enabled.** A missing config file must never read as a deliberate
  "ads off"
- FCM registration is skipped
- `initialize()` logs one line and returns; it never throws

The **Android build fails** until `google-services.json` exists, with
`File google-services.json is missing`. That is the `com.google.gms.google-services`
Gradle plugin, and it is left in deliberately: a Firebase that configured
itself silently would mean no kill switch and no push, with nothing to notice.

## Remote Config keys to publish

| Key | Type | Suggested default | Used for |
| --- | --- | --- | --- |
| `ads_enabled` | Boolean | `true` | Ads kill switch. Only a value **set on the server** turns ads off |
| `min_required_version` | String | empty | Force update |
| `android_store_url` / `ios_store_url` | String | empty | Force update links |
| `show_app_moved` | Boolean | `false` | App-moved gate |
| `new_android_store_url` / `new_ios_store_url` | String | empty | App-moved links |

The kit's ads tunables (`interstitial_cooldown_seconds`,
`interstitial_startup_grace_seconds`, `free_grant_cooldown_minutes`,
`rewarded_wait_timeout_seconds`, `levelplay_app_key_android` / `_ios`) are
read **this console first, then the kit's own `game_kit` project, then the
compiled `AdsConfig` default** - the kit layers `YallaRemoteConfigAdapter` over
its project. An unset host key stays empty on that path, so a local default
cannot mask the kit project. A published `interstitial_cooldown_seconds` of
`0` is a real zero-second cooldown. Set a key here only to override the fleet
value. See `gameKit_package_flutter/docs/ADS.md`.

LevelPlay app keys and unit ids are not compiled into the app. `initializeGameKit`
copies the published `levelplay_app_key_android` / `levelplay_app_key_ios`,
`levelplay_android_banner_id`, `levelplay_android_interstitial_id`,
`levelplay_android_rewarded_id`, and the `levelplay_ios_*` twins into
`AdsConfig` once per process. An unset key stays empty, and an empty prod unit
id is skipped rather than replaced with a built-in id. The kit can still
replace an app key from this console or its own project at init. Native ids
(`levelplay_android_native_id`, `levelplay_ios_native_id`) are read into the
same snapshot. `LevelPlayProdUnitIds` has no native field, so they are not
sent to the SDK.

## Messaging

`NotificationsConfig.enableFcm` is on. The kit is a receiver only: one topic
(`all_users`), title and body from the console, no data payloads or custom
routing. Devices join the topic after the same permission gate as local
reminders, not on first launch.

The background handler is registered in `main()` before `runApp` — Flutter will
not accept a registration from inside `GameKit.initialize`.
