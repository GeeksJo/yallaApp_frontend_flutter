# Puzzle game SDK - behavioral spec

Authoritative rules for `game_kit` modules. No app-specific wording.

## Ads

- Remove Ads disables banners and interstitials only; rewarded stays allowed.
- Interstitial: every N successful level completions (default N=2), max per session, cooldown from last `adClosed()`.
- `levelCompleted(failed: true)` never emits interstitial; may set session fail flag.
- After a shown end-of-round AdMob interstitial (not after a house ad, not a no-fill), may show the remove-ads **popup** - once per session, max 3 lifetime, 4 local days between.
- Rewarded: `canShowRewarded` is always `true` today (quota extension point only).
- Unlock / coin grants: TAP chain in `docs/AD_GRANT.md`. `requestAdGrant` probes reachability then rewarded → interstitial → free. `shouldSkipAdGrantOffer` when `adsRemoved` - hosts skip the watch-ad popup.
- Unlock / coin **hard rules**: grant once per attempt; never hang (stall → next tier); rewarded = earned, not opened; offline = polite message, no grant; online no-fill = silent free grant; dispose ads on consume / teardown (do not `GameKit.ads.dispose()` on screen pop); IAP checked before any popup.

## IAP

- Remove Ads: non-consumable; restore on launch; persist `adsRemoved` + transaction id when present; `completePurchase` after handled update.
- Donations: consumable small/medium/large by product id.
- Generic `loadProducts` / `purchaseProduct` for app shops.

## Notifications

- Weekly local reminders on configured weekdays at configured local hour.
- Install delay: no schedules before install + delay hours.
- Skip scheduling when `lastPlayedDate` is today.
- Consecutive ignored scheduled days increment counter; at threshold stop and cancel until next app open (then reset stop flag and counter per init rules).
- Permission only from `onFirstDailyCompletion()`, never on cold start.

## Rating

- Trigger only via `levelSucceeded(level)` after success path in app.
- Guards: not permanent stop, level ≥ min, session ≥ min, lifetime prompts < max, min days since last prompt, min seconds since last ad close (from `AdClosedEvent`).
- On prompt: increment lifetime count and set last prompt time.
- Positive: request review + permanent stop.
- Negative: emit feedback form event only.
- Dismissed: increment dismissals; at 3 → permanent stop.

## Cross-promo

- Sync `getGames()` from disk cache; block on network only when empty.
- Soft-refresh via `softRefreshIfDue()` when last fetch ≥ 15 minutes old (stale-while-revalidate); coalesce in-flight refreshes; notify `catalogChanges` only when content changes.
- `hasNewGame` (bool) when list hash ≠ `lastViewedHash`; `hasNewGameChanges` stream emits when that bool changes. No UI in the SDK.
- Offline: keep stale cache; empty only when no cache and fetch fails.

## Haptics

- `validAction` → selection click; `invalidAction` → heavy impact; `milestoneSuccess` → medium impact; `lightTap` → light impact.
- Direct strength: `lightImpact`, `mediumImpact`, `heavyImpact` (same Flutter effects).
- Deprecated aliases (one release): `correctMove` → `validAction`; `levelComplete` → `milestoneSuccess`.

## Sounds

- Same semantic events as haptics (`validAction` / `invalidAction` / `milestoneSuccess` / `lightTap`); each maps to a configurable cue, defaulting to a bundled asset (`valid` / `invalid` / `milestone` / `tap`).
- Gating: `enabled` master switch + optional `isEnabled()` runtime gate; per-event `overrides` (bundled asset, host asset, or silence via `none`); `volume` and `respectSilentMode`.
- Pre-loaded on `initialize`; playback never throws - missing/failed cues are skipped (debug log only). Scope is short SFX only; background music stays host-owned.
