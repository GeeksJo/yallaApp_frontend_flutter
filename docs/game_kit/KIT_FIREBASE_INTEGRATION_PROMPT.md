# Kit Firebase integration (game_kit)

Copy this file into Cursor when wiring **kit Remote Config** (shared ad timing, contact details) into a host game that already uses `game_kit`.

Analytics needs **no** kit Firebase: every kit event (More Games included) goes to the host's own property automatically. See `docs/ANALYTICS.md`.

This prompt does **not** cover force update. Force update stays on the **host** `[DEFAULT]` Firebase project - see `docs/FORCE_UPDATE_AND_ANALYTICS_PROMPT.md` if needed.

---

## Goal

Enable the shared **game_kit** Firebase app (`game-kit-d3a27`, named app `game_kit`) so that:

1. Ad timing (interstitial cooldown, startup grace, free-grant window, rewarded wait) can be tuned once for every app via kit Remote Config.
2. Settings contact email + website can be changed via kit Remote Config.

Any key the host's own Remote Config sets overrides the kit value.

Do **not** replace or remove the host game’s own Firebase `[DEFAULT]` app.

---

## Host change (required)

In the host `GameKit.initialize` call, add:

```dart
await GameKit.initialize(
  GameKitConfig(
    locale: const Locale('ar'), // or en - match the game
    crossPromoSheetSeedColor: /* brand color */,
    crossPromoAppIdentifier: 'com.geeksjo.YOUR_GAME', // real package / bundle id
    firebase: GameKitFirebaseConfig.builtIn(),
    // ...existing iap, ads, rating, notifications, share, storage...
  ),
);
```

Requirements:

- Import `package:game_kit/game_kit.dart` (exports `GameKitFirebaseConfig`).
- Keep the rest of `GameKitConfig` as the game already has it.
- Set `crossPromoAppIdentifier` to this game’s real Android package / iOS bundle id - it is More Games' `app_identifier` and filters self-promotion.

---

## What this enables (no extra host code)

| Feature | Behavior |
| ------- | -------- |
| Interstitial cooldown | Reads kit RC `interstitial_cooldown_seconds` (default **40** in code if RC missing/failed) |
| Settings Contact rows | Read kit RC `support_email` / `website_url` (packaged defaults if RC missing/failed) |

Contact rows in `GameKitSettingsBody` resolve in this order: `GameKitSettingsUiConfig.feedbackMailto` / `websiteUrl` (host override) → kit RC → `GameKitDefaultContact`. Leave the host overrides unset when the game should follow the centrally managed values.

---

## Kit Firebase project (shared, once)

Project: **`game-kit-d3a27`**

### Remote Config

| Key | Type | Suggested default |
| --- | ---- | ----------------- |
| `interstitial_cooldown_seconds` | Number | `40` |
| `support_email` | String | `office@majoonstudio.com` |
| `website_url` | String | `https://majoonstudio.com` |

Create + publish in Firebase Console if not already present.

`support_email` accepts `support@example.com` or `mailto:support@example.com`. `website_url` may omit the scheme. Invalid values fall back to packaged defaults. Cross-promo catalog requests use the same `website_url` plus `/api/games`.

---

## Do not

- Do not require a new `google-services.json` / `GoogleService-Info.plist` in the host for kit Firebase - the package boots a **named** secondary app with packaged options.
- Do not put FCM on the named `game_kit` app. Remote push uses host `[DEFAULT]` Firebase. See `docs/FCM.md`.
- Do not implement custom logging for more-games events; use the built-in sheet.
- Do not block gameplay if kit Firebase/RC fails - kit already falls back to the host adapter and `AdsConfig` defaults.

---

## Acceptance checklist

- [ ] Host passes `firebase: GameKitFirebaseConfig.builtIn()`
- [ ] `crossPromoAppIdentifier` matches this game
- [ ] Kit RC key `interstitial_cooldown_seconds` exists (or accept code default 40)
- [ ] Kit RC keys `support_email` / `website_url` exist (or accept packaged defaults)
- [ ] Settings → Contact shows the RC email/website when host overrides are unset
- [ ] Host `[DEFAULT]` Firebase (if any) still works unchanged
