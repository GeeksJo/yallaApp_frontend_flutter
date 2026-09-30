# Firebase setup

All the code is wired. Two files are missing, and they can only come from the
Firebase console.

## What to add

| File | Where it goes |
| --- | --- |
| `google-services.json` | `android/app/google-services.json` |
| `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` (add to the Runner target in Xcode) |

Both come from a Firebase project with an Android app registered as
`com.majoon.yalla` and an iOS app registered with the matching bundle id.

Nothing else is needed: `FirebaseService` calls `Firebase.initializeApp()` with
no options, which reads these native files directly, so there is no generated
`firebase_options.dart` to keep in sync.

## What works before they arrive

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

`interstitial_cooldown_seconds` and `interstitial_startup_grace_seconds` are
read by `game_kit` from **its own** `game_kit` Firebase project, not this one.
See `gameKit_package_flutter/docs/FIREBASE.md`.

## Messaging

`NotificationsConfig.enableFcm` is on. The kit is a receiver only: one topic
(`all_users`), title and body from the console, no data payloads or custom
routing. Devices join the topic after the same permission gate as local
reminders, not on first launch.

The background handler is registered in `main()` before `runApp` — Flutter will
not accept a registration from inside `GameKit.initialize`.
