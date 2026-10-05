# FCM

Local reminders already know when not to nag. Remote campaigns need a
**receiver**, not a second scheduler: one topic, title + body from the
Firebase Console, OS display in background, a local banner in foreground.

`lib/src/notifications/` · `NotificationsConfig.enableFcm` ·
`gameKitFirebaseMessagingBackgroundHandler`

## Why this shape

FCM tokens and background delivery only work on the host **`[DEFAULT]`**
Firebase app (`google-services.json` / `GoogleService-Info.plist`). The
named `game_kit` app is Remote Config only; it cannot receive
background pushes. See [FIREBASE.md](FIREBASE.md).

Campaigns send a **notification** message (title and body). The kit does
not parse data payloads, routes, or custom params. Tap opens the app as a
normal launch.

Every device joins topic **`all_users`** after the same permission gate as
local reminders (`onFirstDailyCompletion`) - not on first launch.

Foreground FCM is invisible unless the kit posts a local notification on
the existing Android channel. Reminder reschedule cancels **reminder ids
only**, so that banner is not wiped.

The background handler **must** be registered in host `main()` before
`runApp`. Flutter will not accept a registration from `GameKit.initialize`.

## Host wiring

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // host [DEFAULT]
  FirebaseMessaging.onBackgroundMessage(
    gameKitFirebaseMessagingBackgroundHandler,
  );
  await GameKit.initialize(gameKitConfig);
  runApp(const MyApp());
}
```

`NotificationsConfig.enableFcm` defaults to **true**. FCM is skipped when
`[DEFAULT]` Firebase is missing (example app, most unit tests) or when
the host sets `enableFcm: false`. Tests inject `GameKitConfig.fcmClient`
(`FakeFcmClient`). Extra topics: `fcmTopics`.

Send from the **host** Firebase Console → Cloud Messaging → topic
`all_users` → notification title and message. Do not send data-only
messages if you expect a tray notification.

## Platform

- **Android:** `POST_NOTIFICATIONS` (API 33+), host `google-services.json`.
- **iOS:** Push Notifications capability, Background Modes → Remote
  notifications, APNs key on the **host** Firebase project.

## Known limits

- One FCM send does not fan out to every game. Each title’s `[DEFAULT]`
  project has its own `all_users` topic.
- Example app does not initialize host Firebase; FCM no-ops there.
