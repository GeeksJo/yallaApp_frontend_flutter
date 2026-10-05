# Cross-promo (More Games)

A sister-app list goes stale the day a new title ships. The catalog base URL
comes from kit Remote Config (`website_url`, default
`https://majoonstudio.com`) with a fixed path (`/api/games`). Hosts do not pass
an endpoint. `crossPromoAppIdentifier` is this game’s package name so the API
and analytics know who opened the sheet.

`lib/src/cross_promo/` · `GameKit.crossPromo`

## Why this shape

Init hydrates **disk first** (offline-safe) and does not block home. Network
runs only when the cache is empty, then **soft-refreshes** if the last
successful fetch is older than **15 minutes** (stale-while-revalidate).
`softRefreshIfDue()` coalesces in-flight calls. Failed refresh keeps the
previous list; `catalogChanges` emits only when content actually changes.

`hasNewGame` / `hasNewGameChanges` compare a catalog hash to last viewed.
Call `markGamesViewed()` when the user closes the sheet so the NEW badge
clears.

UI: `showCrossPromotionBottomSheet` - tint from required
`GameKitConfig.crossPromoSheetSeedColor` only (usually match settings
`seedColor`). Do not pass a color into the function.

More Games analytics go to the **kit** Firebase app (`GameKit.analytics`),
not host `GameAnalytics`. See [FIREBASE.md](FIREBASE.md).

## Known limits

- Module logic does not import Flutter; the sheet is a separate widget.
- Tests must pass `FakeCrossPromoRepository` or Dio timers stay pending.
- The **promo interstitial** is not this catalog. That is
  [PROMO_ADS.md](PROMO_ADS.md).
