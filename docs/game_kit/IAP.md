# IAP

Store purchases were forked per game: different restore paths, a “remove ads”
flag that banners never saw, and donation totals that only updated if the
settings sheet started the buy. `IapModule` is the single store client and the
single `adsRemoved` flag every ad surface already checks.

`lib/src/iap/` · `GameKit.iap` · `IapConfig`

## Why this shape

`removeAdsProductId` always grants `adsRemoved`. Extra Premium SKUs go in
`adsRemovedProductIds` so one purchase still clears banners **and** interstitials
without a second product. Restore uses the same grant path so reinstalls work.

Donation totals increment **inside** the module on any donation SKU success,
not only from settings UI. Read with `getTotalDonations()`. There is no public
`addDonation`.

## Economy vs host grants

When `GameKitConfig.economy` is set, shop catalog SKUs are credited by the
economy. Do **not** also list them in `consumableGrantsByProductId` (debug
assert). That map is only for non-shop consumables, or when the host keeps its
own wallet.

Cash prices always come from the store (`getFormattedPrice`). Never hardcode
`$2.99`.

## Host wiring

- Tests pass `GameKitConfig.storeApi` (`FakeInAppPurchaseApi`) so initialize
  does not talk to Play Billing / StoreKit.
- `purchaseStoreProduct` / `purchaseRemoveAds` / `restorePurchases` are the
  public entry points. UI helpers: `gameKitRunRemoveAdsPurchaseFlow`,
  `GameKitRemoveAdsIconButton`.
- Play Billing unavailable → product queries skip rather than throw.

## Known limits

- No server-side receipt validation. Grants are client-trusted.
- No subscriptions.
- Remove Ads is always **$2.99 USD** in product copy by product policy; the
  live string on screen is still the store’s formatted price.
