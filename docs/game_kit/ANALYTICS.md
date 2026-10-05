# Analytics

One pipe. Every event `game_kit` logs - ads, house ads, More Games, rating,
purchases, screens - goes to the **host app's own** Firebase / GA4 property
through `GameAnalytics`. Apps are compared with each other through BigQuery,
not through a shared property: [CROSS_APP_REPORTING.md](CROSS_APP_REPORTING.md).

`lib/src/analytics/` · host wiring guide [HOST_ANALYTICS.md](HOST_ANALYTICS.md)

| API | Destination | For |
|-----|-------------|-----|
| `GameAnalytics` + `GameSessionTracker` | Host `[DEFAULT]` | Everything the kit and the host log |
| `GameKit.analytics` | Host `[DEFAULT]`, via `GameAnalytics` | Kit-owned UI (More Games sheet). Same pipe; exists so tests can swap it |

## Why this shape

Event **names** are shared across titles (`game_started`, `ad_grant`,
`promo_ad_shown`, ...) so titles are comparable. `game_name` must be a stable
snake_case id (`spy`, not a localized title).

There used to be a second pipe: More Games events went to a shared
`game-kit` property through the GA4 Measurement Protocol. It was removed
because:

- **It failed silently.** An app had to opt in with
  `GameKitConfig.firebase`; six of fifteen apps never did and dropped every
  More Games event with no warning.
- **The data was thin.** Measurement Protocol events from a phone carry no
  session, device or country.
- **It shipped a secret.** The API secret sat inside every app binary.

A shared property's only benefit was one cross-app dashboard. BigQuery export
gives that with full data, so there is nothing left to opt into: an app that
initializes its own Firebase gets every kit event.

The kit's shared Firebase project still exists, for **Remote Config only**
(fleet-wide ad tuning). See [FIREBASE.md](FIREBASE.md).

## Event catalog (logged by the kit)

Never rename after shipping. Names and keys live in `GameAnalyticsKeys`.

### Ads

| Event | Params |
|---|---|
| `ad_interstitial_shown` | `placement?` |
| `ad_rewarded_completed` | `placement`, `category_id?` |
| `ad_grant` | `placement`, `tier`, `category_id?`, `cooldown_group` |
| `ad_failed_to_load` | `ad_format`, `error_code` |

### House ads (promo campaigns) - see [PROMO_ADS.md](PROMO_ADS.md)

| Event | When | Params |
|---|---|---|
| `promo_ad_shown` | A campaign is on screen | `campaign_id`, `promo_slot`, `impression`, `max_dismissals`, `app_identifier` (promoted app), `placement` |
| `promo_ad_clicked` | CTA or image tapped | `campaign_id`, `promo_slot`, `impression`, `source` (`cta`/`image`), `store_opened` (1/0), `app_identifier`, `placement` |
| `promo_ad_dismissed` | Closed with X | `campaign_id`, `promo_slot`, `impression` (dismissals so far), `max_dismissals`, `placement` |
| `promo_ad_retired` | Will never show to this player again | `campaign_id`, `reason` (`converted`/`max_dismissals`), `impression` |
| `promo_ad_unavailable` | Due but could not show (once per session) | `campaign_id`, `reason` (`image_not_ready`/`no_screen`) |
| `promo_ad_fetch_failed` | Campaign API unreachable / errored | `reason` (`offline`, `timeout`, `http_<code>`, `server_error`, `bad_response`, `network_error`) |
| `promo_ad_catalog_changed` | The player received a different campaign list | `campaign_count`, `campaign_ids` |
| `promo_ad_image_failed` | A campaign image did not download | `campaign_id` |

`promo_slot` is `interstitial` (a cadence slot) or `rewarded_fallback` (the
grant chain, when no rewarded or interstitial could fill). `impression` is the
nth time this player sees the campaign. On promo events `app_identifier` is
the **promoted** app; the app the player was in is `app_info.id` in BigQuery.

### More Games (cross-promo sheet)

| Event | Params |
|---|---|
| `more_games_sheet_opened` | `app_identifier` (the app the sheet opened in) |
| `more_games_clicked` | `app_identifier`, `game_title` (the tile tapped), `promoted_package` (its package / bundle id; stable when the title is edited) |

### Installs from sister apps (Android)

House-ad and More Games taps open Play with an install referrer:
`utm_source` = the app the player was in, `utm_medium` = `house_ad` or
`more_games`, `utm_campaign` = the campaign id (`more_games` for the sheet).
The promoted app logs nothing extra: its Firebase SDK reads the referrer and
stamps `first_open`. In **that app's** GA4 property, Reports → Acquisition →
User acquisition, dimension *First user source / medium* and *First user
campaign*. A link that already has a `referrer` (set in the campaign admin)
is not changed. App Store links carry nothing Analytics can read, so iOS
installs are not attributed here.

### Rating, purchases, session, screens

See the inventory in [HOST_ANALYTICS.md](HOST_ANALYTICS.md#event-inventory-host-firebase).

## Custom dimensions to register (each GA4 property)

GA4 leaves event parameters out of its reports until they are registered.
Admin → Data display → **Custom definitions** → Create custom dimension,
scope **Event**, name = parameter:

`placement`, `tier`, `category_id`, `game_name`, `campaign_id`, `promo_slot`,
`source`, `reason`, `app_identifier`, `game_title`, `promoted_package`,
`product_id`, `ad_format`, `cooldown_group`

And as **custom metrics** (scope Event, unit Standard): `impression`,
`max_dismissals`, `store_opened`, `campaign_count`, `duration_seconds`.

BigQuery export does not need these: it has every parameter.

## Screen names

GA4's Screens report shows `MainActivity`, `FlutterViewController`, and
`AdActivity` while automatic screen reporting is on.
`GameAnalyticsNavigatorObserver` sends `screen_view` with readable names; each
host must also turn automatic reporting off. Flags and the observer:
[HOST_ANALYTICS.md](HOST_ANALYTICS.md#screen-names).

## Known limits

- First `GameAnalytics` call lazy-binds `FirebaseAnalytics.instance`. Host
  `Firebase.initializeApp()` must already have run; until then logs no-op.
- Screen names stay technical until the host sets the two native flags and
  registers `GameAnalyticsNavigatorObserver`.
