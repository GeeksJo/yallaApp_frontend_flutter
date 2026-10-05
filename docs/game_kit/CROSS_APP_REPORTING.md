# Cross-app reporting

Parent: [ANALYTICS.md](ANALYTICS.md).

Every app logs to its own GA4 property. To see all apps together - which app
sends players to which game through More Games, how a house-ad campaign does
in each app - export each property to BigQuery and query them as one.

One-time setup per app, then one shared dashboard. GA4's BigQuery export is
free for standard properties; at our event volumes storage and queries stay
within or close to BigQuery's free tier.

## 1. Per app: link BigQuery (Firebase console)

Needs **Owner** on the app's Firebase project.

1. Firebase console → the app's project → ⚙ **Project settings** →
   **Integrations** → **BigQuery** → **Link**.
2. Pick the **same Google Cloud project** for every app (e.g. `geeksjo-analytics`)
   so all datasets sit side by side. Firebase creates one dataset per app:
   `analytics_<property id>`.
3. Turn on **Analytics** export, **Daily**. (Streaming is optional and paid.)
4. Add a billing account to that Cloud project. Without one, BigQuery's
   sandbox deletes tables after 60 days.

Data starts the next day; there is no backfill.

## 2. Per app: register custom dimensions (GA4 console)

Only needed for GA4's own reports, not for BigQuery. List and steps:
[ANALYTICS.md § Custom dimensions](ANALYTICS.md#custom-dimensions-to-register-each-ga4-property).

## 3. Once: one view over every app (BigQuery)

Create a view that unions the daily tables of every app. `app_info.id` is the
package name, so every row knows its app without any custom parameter.

```sql
CREATE OR REPLACE VIEW `geeksjo-analytics.reporting.all_events` AS
SELECT * FROM `geeksjo-analytics.analytics_111111111.events_*`  -- barra
UNION ALL
SELECT * FROM `geeksjo-analytics.analytics_222222222.events_*`  -- charades
-- one line per app
;
```

Add a line when a new app's export is linked.

### House-ad campaign performance, per source app

```sql
SELECT
  app_info.id AS app,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign_id') AS campaign,
  COUNTIF(event_name = 'promo_ad_shown') AS shown,
  COUNTIF(event_name = 'promo_ad_clicked'
          AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'store_opened') = 1) AS store_opens,
  COUNTIF(event_name = 'promo_ad_dismissed') AS dismissed,
  SAFE_DIVIDE(
    COUNTIF(event_name = 'promo_ad_clicked'),
    COUNTIF(event_name = 'promo_ad_shown')) AS ctr
FROM `geeksjo-analytics.reporting.all_events`
WHERE event_name LIKE 'promo_ad_%'
  AND _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
                        AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
GROUP BY app, campaign
ORDER BY shown DESC;
```

`_TABLE_SUFFIX` works on the view only if the view selects `_TABLE_SUFFIX`
explicitly; otherwise filter on `event_date` instead.

### More Games: which app sends players to which game

```sql
SELECT
  app_info.id AS from_app,
  COALESCE(
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'promoted_package'),
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_title')
  ) AS to_game,
  COUNTIF(event_name = 'more_games_sheet_opened') AS sheet_opens,
  COUNTIF(event_name = 'more_games_clicked') AS clicks
FROM `geeksjo-analytics.reporting.all_events`
WHERE event_name IN ('more_games_sheet_opened', 'more_games_clicked')
GROUP BY from_app, to_game
ORDER BY clicks DESC;
```

`sheet_opens` is grouped per app (its `to_game` is null); clicks are per
destination game. `promoted_package` is stable; older events only have
`game_title`, hence the fallback.

### Installs: which app and campaign brought new players (Android)

Taps open Play with an install referrer (see ANALYTICS.md), so the
**promoted** app's `first_open` carries where the player came from:

```sql
SELECT
  app_info.id AS installed_app,
  traffic_source.source AS from_app,
  traffic_source.medium AS via,          -- house_ad / more_games
  traffic_source.name AS campaign,
  COUNT(DISTINCT user_pseudo_id) AS new_users
FROM `geeksjo-analytics.reporting.all_events`
WHERE event_name = 'first_open'
  AND traffic_source.medium IN ('house_ad', 'more_games')
GROUP BY installed_app, from_app, via, campaign
ORDER BY new_users DESC;
```

Set against `store_opened` clicks per campaign (above) this gives
click → install per campaign and per source app.

### Is the campaign API healthy?

```sql
SELECT
  event_date,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'reason') AS reason,
  COUNT(*) AS failures
FROM `geeksjo-analytics.reporting.all_events`
WHERE event_name IN ('promo_ad_fetch_failed', 'promo_ad_image_failed', 'promo_ad_unavailable')
GROUP BY event_date, reason
ORDER BY event_date DESC;
```

`offline` and `timeout` are players' networks; `http_5xx`, `server_error` and
`bad_response` point at the backend.

## 4. Once: dashboard (Looker Studio)

1. lookerstudio.google.com → **Create** → Data source → **BigQuery** →
   the `reporting` dataset → `all_events` view (or a saved query above via
   **Custom query**).
2. Add charts with `app_info.id` as a dimension for per-app breakdowns.

For one app at a time, Looker Studio's **Google Analytics** connector reads a
GA4 property directly, but it blends at most five sources, so BigQuery is the
way to see all apps.

## Checklist for an app joining

- [ ] App uses a `game_kit` version with the one-pipe analytics (no code
      change needed; update the lock file).
- [ ] BigQuery linked to the shared Cloud project (step 1).
- [ ] Custom dimensions registered in its GA4 property (step 2).
- [ ] Its dataset added to the `all_events` view (step 3).
- [ ] Screen names wired ([HOST_ANALYTICS.md § Screen names](HOST_ANALYTICS.md#screen-names)).
- [ ] Verified: open More Games on a debug build → `GameAnalytics: sent more_games_sheet_opened`
      in the console, and the event in Firebase **DebugView**
      (`adb shell setprop debug.firebase.analytics.app <package>`).
