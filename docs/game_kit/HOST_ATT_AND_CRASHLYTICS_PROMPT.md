# Host iOS ATT + Firebase Crashlytics (game_kit)

Copy this entire file into Cursor (or `@`-reference it) when wiring a **GeeksJo GameKit host app** to match the **Sawaleef** pattern: system **App Tracking Transparency** before ads, and **Crashlytics** on the host `[DEFAULT]` Firebase app.

Reference host (golden): `partyGames_frontend_flutter` (`sawaleef_mobile_app`) — `lib/app_init.dart`, `lib/main.dart`, `lib/core/game_kit/bootstrap_game_kit.dart`, `ios/Runner/Info.plist`, `ios/Runner/*.lproj/InfoPlist.strings`.

Kit docs: [IOS_APP_TRACKING.md](IOS_APP_TRACKING.md), [FIREBASE.md](FIREBASE.md), [FCM.md](FCM.md).

---

## Agent prompt (copy from here)

You are wiring **iOS App Tracking Transparency (ATT)** and **Firebase Crashlytics** in a Flutter host app that uses **`game_kit`**. Match the **Sawaleef** host pattern. This is a **focused integration** — do not refactor unrelated features.

### Success criteria

- **ATT:** On a fresh install (tracking status *not determined*), the **system ATT dialog** appears **before** UMP / LevelPlay init — i.e. during **`GameKit.initialize`**, while the host splash / `GameKitReadyGate` loading UI is visible.
- **ATT plist:** `NSUserTrackingUsageDescription` uses kit canonical copy (English in `Info.plist`, English + Arabic in `InfoPlist.strings`). No invented per-app tracking wording unless the user explicitly asks.
- **Analytics deferral:** After host `Firebase.initializeApp`, call **`GameKitIosAppTracking.deferFirebaseAnalyticsCollection()`** before `runApp` and before `GameKit.initialize`.
- **Crashlytics:** Reports go to the host's **`[DEFAULT]`** Firebase project — not the named `game_kit` app. The host makes **one call**, `await GameKitCrashlytics.install()`, in **`AppInit` / `main`** after Firebase init, before `runApp`. No hand-written `FlutterError.onError` / `PlatformDispatcher.instance.onError` in the host. Android Gradle + iOS dSYM upload configured.
- **Init order (strict):**
  1. `WidgetsFlutterBinding.ensureInitialized()`
  2. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` (host project)
  3. `await GameKitIosAppTracking.deferFirebaseAnalyticsCollection()`
  4. `FirebaseMessaging.onBackgroundMessage(gameKitFirebaseMessagingBackgroundHandler)` — top-level, after `[DEFAULT]` Firebase, before `runApp`
  5. Crashlytics: `await GameKitCrashlytics.install()`
  6. `runApp(...)`
  7. Post–first-frame: `GameKit.initialize(...)` (ATT runs inside kit when `AdsConfig.requestIosAppTrackingAuthorization` is true — default)
- **Do not** register FCM background handler or Crashlytics against the named **`game_kit`** Firebase app.
- **Do not** duplicate ATT request logic in the host if kit already requests it in `GameKit.initialize` — only add host plist + defer analytics + correct bootstrap timing.
- **`flutter analyze`** clean; document any intentional opt-out (`requestIosAppTrackingAuthorization: false`) in a short comment + tell the user.

### Read first (host repo)

- `pubspec.yaml` — `game_kit` dependency (path or git `development`), Firebase packages
- `lib/app_init.dart` or `lib/core/firebase/bootstrap_firebase.dart` — Firebase + defer + Crashlytics + FCM
- `lib/main.dart` — `runApp` then post-frame `GameKit.initialize` / `completeGameKitBootstrap`
- `lib/core/game_kit/*` — bootstrap, `GameKitReadyGate`, `AdsConfig` passed into `GameKitConfig`
- `ios/Runner/Info.plist`, `ios/Runner/en.lproj/InfoPlist.strings`, `ios/Runner/ar.lproj/InfoPlist.strings`, `ios/Runner.xcodeproj/project.pbxproj` (InfoPlist.strings variant group)
- `android/settings.gradle.kts`, `android/app/build.gradle.kts` — Google services + Crashlytics plugins
- `firebase_options.dart` — host `[DEFAULT]` app

### Read first (game_kit package — resolved dependency)

- `lib/src/privacy/ios_app_tracking.dart` — `GameKitIosAppTracking`
- `lib/src/privacy/att_usage_descriptions.dart` — `GameKitAttUsageDescriptions`
- `templates/ios/Runner/` — plist string templates
- `docs/IOS_APP_TRACKING.md`

---

### Phase 1 — Dependencies

**Host `pubspec.yaml`:**

- `firebase_core`
- `firebase_messaging` if FCM topic `all_users` is used (kit default)
- `game_kit` with ATT support (`app_tracking_transparency` transitively) and Crashlytics (`firebase_crashlytics` transitively — the host does not need to list it)

Run `flutter pub get`. If iOS pods stale: `cd ios && pod install`.

Crashlytics handling lives in `game_kit` (`GameKitCrashlytics`) so every app records the same way; it still reports to each host's own Firebase project.

---

### Phase 2 — Dart (`AppInit` / bootstrap)

**After** `Firebase.initializeApp`:

```dart
await GameKitIosAppTracking.deferFirebaseAnalyticsCollection();
```

**FCM** (if using kit notifications with host Firebase):

```dart
FirebaseMessaging.onBackgroundMessage(gameKitFirebaseMessagingBackgroundHandler);
```

Import from `package:game_kit/game_kit.dart`.

**Crashlytics** (same file, right after `Firebase.initializeApp`, before `runApp`):

```dart
await GameKitCrashlytics.install();
```

- Framework errors are recorded **non-fatal**: the kit reports recoverable
  failures (ads, notifications, Remote Config) through
  `FlutterError.reportError`, and those must not count as crashes. Uncaught
  async errors are fatal. Debug builds send nothing. Each report carries the
  key `app_identifier` (package / bundle id).
- **If `main` uses `runZonedGuarded`**, forward the zone's errors — they never
  reach `PlatformDispatcher.onError`:

  ```dart
  (Object error, StackTrace stack) {
    GameKitCrashlytics.recordUncaughtError(error, stack);
    // keep the app's existing logging
  },
  ```
- **Host already wired by hand** (`FlutterError.onError =
  FirebaseCrashlytics.instance.recordFlutterFatalError` etc.): delete those
  lines and use the `install()` call instead, or every kit-reported problem
  counts as a crash.

**`main.dart` pattern:**

- `await AppInit().beforeAppInit()` then `runApp`
- `WidgetsBinding.instance.addPostFrameCallback` → `completeGameKitBootstrap()` / `GameKit.initialize`
- Wrap app with **`GameKitReadyGate`** (or equivalent) so ads/IAP are not touched before init completes

**`AdsConfig`:** Keep **`requestIosAppTrackingAuthorization: true`** (default). Do not set `false` without user approval.

**Remove** duplicate host ATT helpers that call `AppTrackingTransparency.requestTrackingAuthorization` outside kit — one request path only.

---

### Phase 3 — iOS ATT plist

1. **`Info.plist`** — add or replace:

   - `NSUserTrackingUsageDescription` = exact English string from `GameKitAttUsageDescriptions.english`:
     `We use this permission to show you more relevant ads and measure ad performance.`

2. **Localized strings** — create or merge:

   - `ios/Runner/en.lproj/InfoPlist.strings` — tracking key only (merge with existing notification strings)
   - `ios/Runner/ar.lproj/InfoPlist.strings` — Arabic from `GameKitAttUsageDescriptions.arabic`

   Copy from kit: `templates/ios/Runner/en.lproj/InfoPlist.strings` and `ar.lproj/InfoPlist.strings`.

3. **Xcode project** — ensure `InfoPlist.strings` is a **variant group** with `en` and `ar` children and both are in **Copy Bundle Resources** (see Sawaleef `project.pbxproj` if unsure).

4. **Recommended plist flags** (when app supports Arabic):

   - `CFBundleDevelopmentRegion` = `en`
   - `CFBundleAllowMixedLocalizations` = `true`
   - `CFBundleLocalizations` = `en`, `ar`

5. **Ads:** Keep host `GADApplicationIdentifier` and `SKAdNetworkItems` as already configured for LevelPlay / mediation — ATT is separate from those keys.

**Dialog language:** System title/buttons follow **device language**. Subtitle follows localized `NSUserTrackingUsageDescription`. You cannot force English system chrome from the app.

---

### Phase 4 — Android + iOS Crashlytics (native)

**Android** (`settings.gradle.kts`):

```kotlin
id("com.google.firebase.crashlytics") version("3.0.8") apply false
```

The Crashlytics plugin 3 requires `com.google.gms.google-services` **4.4.1 or newer** — bump older apps to `4.4.4` (the build otherwise fails with "requires Google-Services 4.4.1 and above").

**Android** (`app/build.gradle.kts` plugins block):

```kotlin
id("com.google.gms.google-services")
id("com.google.firebase.crashlytics")
```

Host must have `google-services.json` for its package name.

**iOS:**

- Depends on `firebase_crashlytics` pod (via Flutter plugin after `pod install`).
- Add FlutterFire **upload Crashlytics symbols** build phase if missing:

  ```bash
  flutterfire configure
  ```

  or copy the **"flutterfire upload-crashlytics-symbols"** run script from Sawaleef `ios/Runner.xcodeproj/project.pbxproj`.

**Verify:** Test crash in **profile or release** build — debug often does not report to console.

---

### Phase 5 — App Store Connect / privacy

- If ATT + personalized ads: privacy labels must declare **tracking** / **Device ID** consistently (host doc checklist).
- For Guideline **2.1** rejections: attach screen recording — fresh install → ATT on splash → Allow/Deny → home. See host `docs/app-review-att.md` if present.

---

### Phase 6 — Verification checklist

| Check | How |
|-------|-----|
| ATT shows | Delete app or Settings → Privacy → Tracking → reset; cold launch on physical device |
| ATT before ads | Breakpoint or logs: ATT completes before LevelPlay / UMP in `GameKit.initialize` |
| No double ATT | Only kit requests; no second call in host |
| Crashlytics | Release build with a temporary error after `runApp`; launch, force-stop, relaunch (reports upload on next start); event in host Firebase Crashlytics (filter Crashes + Non-fatals) with key `app_identifier` |
| iOS symbols | Release archive; confirm dSYM upload build phase succeeds |
| Screenshot builds | `SCREENSHOT_MODE=true` skips ATT — do not ship to App Review |

---

### Report back to the user

When done, list:

- Files changed (Dart, plist, Gradle, pbxproj)
- Whether ATT was already determined on your test device
- Whether Crashlytics test crash was sent
- Anything **not** done (e.g. missing `firebase_options.dart`, no physical iOS device)

---

## End of agent prompt
