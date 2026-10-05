# Host gameplay analytics (`GameAnalytics`)

Parent: [ANALYTICS.md](ANALYTICS.md).

**Why this exists:** Every GeeksJo game should emit the **same event names** for starts, completes, ads, IAP, and rating - so you can compare apps in Firebase without inventing a new taxonomy per title.

Everything goes to the host app's **`[DEFAULT]`** Firebase Analytics
property - kit events, More Games included. There is no second property to
wire. Cross-app views come from BigQuery: [CROSS_APP_REPORTING.md](CROSS_APP_REPORTING.md).

No host wiring is required for the sink: the first `GameAnalytics` call
lazily uses `FirebaseAnalytics.instance` (host default app). Ensure the host
has already called `Firebase.initializeApp()` before gameplay starts. If the
default app is missing, logs no-op instead of throwing.

---

## What the kit logs for you (no host code)

After `GameKit.initialize`, these fire automatically on **`GameAnalytics`**:

| When | Event / property |
|------|------------------|
| Rewarded finished (`showRewarded` or grant-chain Tier 1) | `ad_rewarded_completed` (`placement`, optional `category_id`) |
| Grant chain finished (`requestAdGrant`) | `ad_grant` (`placement`, `tier` = `offline`/`rewarded`/`interstitial`/`free`, optional `category_id`) |
| Interstitial actually shown | `ad_interstitial_shown` |
| House ad (promo campaign) | `promo_ad_shown` (+ `ad_interstitial_shown`), `promo_ad_clicked`, `promo_ad_dismissed`, `promo_ad_retired`, `promo_ad_unavailable`, `promo_ad_fetch_failed`, `promo_ad_catalog_changed`, `promo_ad_image_failed` - params in [ANALYTICS.md](ANALYTICS.md#house-ads-promo-campaigns---see-promo_adsmd) |
| More Games sheet | `more_games_sheet_opened` (`app_identifier`), `more_games_clicked` (`app_identifier`, `game_title`) |
| Ad load failure | `ad_failed_to_load` (`ad_format`, `error_code`) |
| Soft rating shown / answered | `rating_prompt_shown`, `rating_prompt_response` |
| Store purchase confirmed (not restore) | `iap_purchased` (`product_id`) - every non-restore SKU |
| Ads removed granted | user property `ads_removed` = `true`/`false` |
| Remove-ads offer UI (kit button / flow) | `iap_offer_shown` when the kit surfaces the offer |

**Entitlement (not an analytics event):** purchasing/restoring `removeAdsProductId` or any ID in `IapConfig.adsRemovedProductIds` sets global `GameKit.iap.adsRemoved` (same flag banners/interstitials already check). List Premium SKUs that include “no ads” there; `purchaseStoreProduct` buys those as non-consumables.

**Host still logs:** `ad_rewarded_offered` / `ad_rewarded_declined` when *you* show an unlock dialog (before calling `requestAdGrant` or `showRewarded`). Skip that dialog when `GameKit.ads.shouldSkipAdGrantOffer`. Pass a stable `placement:` so completed/grant events match offered. Unlock/coin taps must use **`requestAdGrant`** - hard rules + TAP chain in `docs/AD_GRANT.md`.

---

## What every host must wire

### 1. Session lifecycle (required)

Use stable snake_case `game_name` strings (e.g. `spy`, `charades`, `word_ladder`) - **same name forever** after you ship.

```dart
import 'package:game_kit/game_kit.dart';

// When play actually begins (after setup / first meaningful start):
await GameSessionTracker.onStarted(
  'spy',
  categoryIds: ['animals'], // optional; one category_selected per id
);

// Normal finish / results:
await GameSessionTracker.onCompleted('spy');

// Exit-confirm leave mid-game (not a fail screen):
GameSessionTracker.onAbandoned();

// Play again without leaving the screen:
await GameSessionTracker.onReplayed('spy');
// or: await GameSessionTracker.logReplayed('spy');
```

`onStarted` also bumps user property `total_games_played` (`1` / `2-5` / `6-20` / `20+`) via SharedPreferences key `analytics_total_games_played`.

### 2. Optional host helpers

```dart
unawaited(GameAnalytics.logShareTapped('spy'));
unawaited(GameAnalytics.logContentExhausted('spy', categoryId: 'animals'));
unawaited(GameAnalytics.logAdRewardedOffered('spy_category_unlock'));
unawaited(GameAnalytics.logAdRewardedDeclined('spy_category_unlock'));
unawaited(GameAnalytics.logIapOfferShown(
  productId: 'myapp.removeads',
  source: GameAnalyticsKeys.sourceHudIcon, // shop | settings | hud_icon | tooltip | home_card
));
unawaited(GameAnalytics.logFeedbackEmailOpened());
unawaited(GameAnalytics.logGamekitBootstrapFailed('initialize'));
```

Prefer kit `showRewarded(placement: …)` over manually logging `ad_rewarded_completed` (kit already logs once).

### 3. Disable / tests

```dart
GameAnalytics.setSink(const NoOpGameAnalyticsSink());
// or
GameAnalytics.enabled = false;
```

Package unit tests call `GameAnalytics.resetForTest()` (via `test/flutter_test_config.dart`) so `flutter test` never touches Firebase.

In debug builds, successful logs also `debugPrint` as `GameAnalytics: <name> {…}`.

---

## Event inventory (host Firebase)

Keep names in `GameAnalyticsKeys` - **never rename after shipping**.

| Event | Params | Who logs |
|-------|--------|----------|
| `game_started` | `game_name` | Host via `GameSessionTracker` |
| `game_completed` | `game_name`, `duration_seconds` | Host via `GameSessionTracker` |
| `game_replayed` | `game_name` | Host |
| `game_abandoned` | `game_name`, `duration_seconds` | Host |
| `category_selected` | `game_name`, `category_id` | Host (`onStarted`) |
| `share_tapped` | `game_name` | Host |
| `content_exhausted` | `game_name`, `category_id?` | Host |
| `ad_rewarded_offered` / `_declined` | `placement` | Host |
| `ad_rewarded_completed` | `placement`, `category_id?` | **Kit** |
| `ad_grant` | `placement`, `tier`, `category_id?` | **Kit** (`requestAdGrant`) |
| `ad_interstitial_shown` | `placement?` | **Kit** |
| `ad_failed_to_load` | `ad_format`, `error_code` | **Kit** |
| `iap_offer_shown` | `product_id`, `source` | Host and/or kit UI |
| `iap_purchased` | `product_id` | **Kit** |
| `rating_prompt_shown` | `game_name?` | **Kit** |
| `rating_prompt_response` | `response` | **Kit** |
| `feedback_email_opened` | - | Host |
| `gamekit_bootstrap_failed` | `stage` | Host |

**User properties:** `total_games_played`, `ads_removed`.

**IAP rule:** one event `iap_purchased` + `product_id` for every SKU. Do not invent `remove_ads_purchased`. Restores update `ads_removed` only - no purchase event.

---

## Screen names

Automatic screen reporting logs the Android activity and the iOS view
controller. Every Flutter page is `MainActivity` / `FlutterViewController`,
and a full-screen mediated ad is the ad SDK’s own activity. Mapping `MainActivity` to
"Home Screen" would label Settings and the game as Home.

Turn automatic reporting off in each app, then register
`GameAnalyticsNavigatorObserver`. It sends `screen_view` with the same
readable string for `screen_name` and `screen_class` (the dimension GA4
shows by default). Pass a route map for names you want to control; other
page routes are title-cased (`/gameModeSelect` → `Game Mode Select`,
`/` → `Home Screen`). Dialogs are not tracked.

```dart
GetMaterialApp(
  navigatorObservers: [
    GameAnalyticsNavigatorObserver(
      names: const {'/': 'Home Screen', '/shop': 'Shop Screen'},
    ),
  ],
)
```

Android `AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="google_analytics_automatic_screen_reporting_enabled"
    android:value="false" />
```

iOS `Info.plist`:

```xml
<key>FirebaseAutomaticScreenReportingEnabled</key>
<false/>
```

The kit logs `Ad Viewer` when an interstitial or rewarded ad is actually
on screen, and sends the previous page again when that ad closes or fails
to show. Promo creatives are Flutter dialogs, so they keep the current
page name. Dart cannot disable automatic reporting; without the two flags
the class names keep overwriting these events.

---

## Checklist for a new game on `game_kit`

1. Host Firebase Analytics initialized (`[DEFAULT]`).
2. Disable automatic screen reporting (manifest + `Info.plist` above) and add `GameAnalyticsNavigatorObserver`.
3. Call `GameSessionTracker.onStarted` / `onCompleted` / `onAbandoned` (and replay if you have Play Again).
4. Use kit ads APIs so interstitial/rewarded completion events fire.
5. Log rewarded **offer/decline** yourself; pass `placement` into `requestAdGrant` (unlocks/coins) or `showRewarded` (must-watch hints).
6. Log `iap_offer_shown` when *your* UI pitches a product; kit logs `iap_purchased`.
7. Verify in debug console (`GameAnalytics:`) and Firebase DebugView:
   `adb shell setprop debug.firebase.analytics.app <your.package.id>`
8. Link BigQuery and register custom dimensions: [CROSS_APP_REPORTING.md](CROSS_APP_REPORTING.md).

---

## Related

- Event catalog + custom dimensions: `docs/ANALYTICS.md`
- All apps in one dashboard: `docs/CROSS_APP_REPORTING.md`
- Unlock / coin grant chain: `docs/AD_GRANT.md`
- Kit Firebase (shared Remote Config only): `docs/KIT_FIREBASE_INTEGRATION_PROMPT.md`
