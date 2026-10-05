# Upgrading a host app

For whoever updates an app's `game_kit` dependency - developer or agent.
Newest first. Each section says what changes for the app, what (if anything)
to do, and how to verify. Details live in [CHANGELOG.md](../CHANGELOG.md).

Update with `flutter pub upgrade game_kit`, then build and run once.

---

## Installs attributed to the sister app and campaign (Android)

No code changes, in the app that shows the ads or the one being promoted.
House-ad and More Games taps now open Play with an install referrer, and
`more_games_clicked` gains `promoted_package`.

Verify: tap a house ad's button or a More Games tile on Android; logcat
shows the Play intent with `referrer=utm_source%3D<your package>...`.

Console (each app, once): register `promoted_package` as a custom
dimension. Installs then show in the **promoted** app's GA4 property under
User acquisition → *First user source / medium* (`<sister app> / house_ad`
or `more_games`) and *First user campaign*.

---

## House ad in landscape, rewarded waits for close (after `3a874d6`)

No code changes.

- The house-ad interstitial now has a landscape layout. Before, an app that
  showed it on a landscape screen got the portrait creative squashed.
- A rewarded ad is waited on until the player closes it. Before, one still
  open after 3 minutes (long playable, store redirect) ended as `skipped`
  and paid nothing even when it had been watched.

Verify: trigger a house ad while the app is in landscape - image beside the
text, nothing cut off, X closes it (`promo_ad_dismissed`). Watch a rewarded
ad for coins and close it only after its end card; the console shows
`ad_grant {... tier: rewarded ...}` and the coins land.

Do not rotate the app to portrait yourself just to show the house ad.

---

## Notification permission asked once (after `2c78ffe`)

No code changes. Android players are now asked for notification permission
**once** after their first round; before, a player who declined saw the same
prompt again immediately. Verify on Android 13+: finish a round, tap
"Don't allow" - the prompt must not come back.

---

## To `3477861` (October 2026): one analytics pipe, house-ad analytics, ads fixes

Covers `d8fcccc`, `68ad70a` and `3477861` on `development`.

### Code changes needed

None expected. Removed APIs (no app on this kit used them; the build fails if
yours does - delete the arguments):

- `GameKitFirebaseConfig(androidMeasurementId:, androidMeasurementProtocolApiSecret:, iosMeasurementId:, iosMeasurementProtocolApiSecret:)`
- `Ga4MeasurementProtocolGameKitAnalytics`, `FirebaseGameKitAnalytics`, `GameKitGa4MeasurementProtocolCredentials`

### Behavior that changes

1. **`ads_enabled = false` stops only interstitials and banners.** A rewarded
   ad the player taps for (coins, unlocks) still plays. Before, it skipped the
   ad and paid a capped free reward. To stop **all** ads, also set
   `AdsConfig.rewardedAdsEnabled: false`.
2. **The interstitial cooldown starts when the player closes the ad,**
   including an ad left open past 60 seconds (before, such an ad started no
   cooldown at all).
3. **House ads (promo campaigns):** a failed campaign fetch no longer wipes
   the cached campaigns; a CTA tap only converts when the store actually
   opened, otherwise the ad stays up.
4. **All kit analytics go to the app's own Firebase / GA4 property**, More
   Games included. Before, More Games events went to the shared `game-kit`
   property, and were dropped in apps without `GameKitConfig.firebase`.
   New house-ad events: `promo_ad_shown`, `_clicked`, `_dismissed`,
   `_retired`, `_unavailable`, `_fetch_failed`, `_catalog_changed`,
   `_image_failed`. Catalog: [ANALYTICS.md](ANALYTICS.md).
5. `GameKitConfig.firebase` / `GameKitFirebaseConfig.builtIn()` is now for
   **shared Remote Config only**. Keep it if the app has it; do not add it
   for analytics.

### Do not

- Log More Games events yourself; the built-in sheet does.
- Wrap rewarded ads in your own `if (adsEnabled)`; the kit applies the switch.
- Treat a missing house ad as a bug before checking `promo_ad_unavailable`
  and `promo_ad_fetch_failed` in Analytics.

### Verify

- Debug build, open More Games → console shows
  `GameAnalytics: sent more_games_sheet_opened {app_identifier: <package>}`.
  `GameKitAnalytics: skipped (no-op sink)` means the app is still on an old
  kit.
- Page names: automatic screen reporting off (AndroidManifest + Info.plist)
  and `GameAnalyticsNavigatorObserver` registered, or GA shows `MainActivity`.
  See [HOST_ANALYTICS.md § Screen names](HOST_ANALYTICS.md#screen-names).
- Optional: Firebase DebugView
  (`adb shell setprop debug.firebase.analytics.app <package>`).

### Console work (app owner, once per app)

Link the app's Firebase project to BigQuery in the shared Cloud project, and
register the custom dimensions in its GA4 property:
[CROSS_APP_REPORTING.md](CROSS_APP_REPORTING.md).
