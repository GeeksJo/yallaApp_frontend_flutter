# Kit Firebase

The host already has a `[DEFAULT]` Firebase app for its own Analytics / RC /
Crashlytics. The kit boots an optional **named** app `game_kit` for one thing:
**shared Remote Config** (ad timing, support email, website) that lives once
for every title, with each app able to override.

The named app does **no analytics**. Every event, kit-owned ones included,
goes to the host `[DEFAULT]` property. See [ANALYTICS.md](ANALYTICS.md).

`lib/src/firebase/` · `GameKitConfig.firebase` · `GameKitFirebaseConfig.builtIn()`

## Why this shape

Set `firebase:` on initialize. Host `[DEFAULT]` is untouched. Kit Remote
Config (`GameKit.remoteConfig`) is layered: a key the **host** console sets
wins, otherwise the kit project answers, otherwise the compiled default.

| Kit RC key | Used by |
|------------|---------|
| `interstitial_cooldown_seconds` | Ads cooldown (clamp 0-600) |
| `interstitial_startup_grace_seconds` | Seconds after launch with no interstitial (clamp 0-600) |
| `support_email` | Settings contact |
| `website_url` | Settings website and cross-promo catalog origin |

A key that does not exist in the console falls back to the value the host
compiled in. Firebase answers a missing key with `0` / `false` / `""` rather
than an error, so `FirebaseGameKitRemoteConfig` checks the value's *source*
before trusting it. Without that check an absent `interstitial_cooldown_seconds`
read as a **zero-second** cooldown and showed interstitials back to back.

Force update **`min_required_version`** stays on **host** RC.
See [FORCE_UPDATE.md](FORCE_UPDATE.md).

**FCM** also stays on host `[DEFAULT]` - not this named app.
See [FCM.md](FCM.md).

Host wiring checklist: [KIT_FIREBASE_INTEGRATION_PROMPT.md](KIT_FIREBASE_INTEGRATION_PROMPT.md).

## Known limits

- Omit `firebase` and kit RC stays on code defaults (and the host adapter,
  if passed). Analytics is unaffected. Ads and IAP still run.
- Tests pass `remoteConfig:` / `analytics:` on `GameKitConfig` to skip
  the named app.
- Packaged options live in this repo (`flutterfire configure` in this package,
  not in each host).
- Do not register `gameKitFirebaseMessagingBackgroundHandler` against the
  named `game_kit` app.
