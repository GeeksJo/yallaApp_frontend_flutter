# Unlock / coins grant chain (`requestAdGrant`)

Parent: [ADS.md](ADS.md) · host setup [LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md)

**Why a chain:** airplane mode looks exactly like no ad fill. Hosts that granted on `showRewarded() == false` gave away categories and coins for free. This chain demands a **real network path** first, then works down from paid inventory to a capped free reward, so a player in a market with no demand is never stuck behind an ad that is never coming.

Use it for every **TAP** that trades attention for something: unlock a category, rent one, take coins, refill a heart / hint / revive. Do **not** use `showRewarded()` for these (`showRewarded` is for must-watch placements that should fail closed when the user skips).

The kit never grants host content. It returns an [AdGrantOutcome](../lib/src/ads/ad_grant_outcome.dart); the host maps `isGranted` onto unlocks or coins.

---

## The chain

```text
TAP
  ↓
adsRemoved (Premium / Remove Ads)?
  → grantedFree. No probe, no ad, no cooldown. A payer never waits.
  ↓
connectivity probe (2s, real reachability)
  → OFFLINE, or the probe threw / timed out
      → offline. STOP. No grant.
        This is the airplane-mode gate; never fall through here.
  ↓ ONLINE
ad SDK failed to start?
  → treat as no fill: go to the free-grant tier below.
  ↓
TIER 1 - rewarded
  not cached? → start a load, wait up to AdsConfig.rewardedWaitTimeout (4s)
  shown, reward earned    → grantedRewarded
  shown, closed early     → skipped. STOP. No grant, no lower tier.
  never rendered          → fall through (failed show, dead adapter, throw)
  ↓
TIER 2 - preloaded interstitial (unlock inventory, not cadence)
  shown and closed        → grantedInterstitial
  not ready / no show     → fall through
  ↓
TIER 3 - house ad (sister-app promo)
  shown, dismissed        → grantedHouseAd
  shown, converted        → grantedHouseAd
  disabled / no campaign
  / no overlay            → fall through
  ↓
TIER 4 - free grant, capped per AdGrantCooldownGroup
  window clear            → grantedFree, and the window is stamped
  window still running    → noneAvailable. STOP. No grant.
```

The tiers run in descending revenue order: paid rewarded, paid interstitial,
house ad (no revenue, but a real cross-install), then the give-away.

### Why a skip stops the chain

A rewarded ad that **displayed** and was closed before earning is the player's decision, and it costs them the reward. If it fell through to Tier 2, pressing X on a 30-second video and sitting through a 5-second interstitial would become the fastest way to get paid - so the kit would be training players to skip.

An ad that **never rendered** is a different event: invisible to the player and not their fault. That falls through exactly as if inventory had been empty. The two are distinguished by [RewardedShowResult](../lib/src/ads/ad_network_controller.dart); a controller that collapses them into a bool re-introduces the bug.

### Why the house ad sits here

Tier 3 exists because a market with no fill is the *most* valuable place to run
a sister-app promo, and the only alternative in that slot is handing the reward
over for nothing. The player still trades attention for the reward, so the
exchange stays honest, and a give-away becomes a cross-install.

It is **off unless `AdsConfig.showPromoInterstitial` is true**, so a host that
has not opted in behaves exactly as if the tier did not exist.

Two things it deliberately does not do:

- **It does not consume the cadence alternation flag.** `PromoInterstitialService`
  normally takes every *other* interstitial slot so paid inventory keeps half
  the cadence. The grant chain reaches Tier 3 only because there was no paid
  inventory to alternate with, so `tryShowForGrant` leaves the flag alone.
  Spending it here would promise the next between-round slot to a network that
  just proved it has no fill, wasting that slot too.
- **It does not bump the interstitial session cap.** A house ad costs no paid
  impression. It *does* stamp the 40s cooldown, so a boundary interstitial
  cannot stack straight on top of it.

The **dismissal budget is shared** with cadence slots: a campaign the player
has dismissed `maxDismissals` times is spent, and where they saw it does not
change that. Once every campaign is exhausted the tier falls through to Tier 4.

A payer (`adsRemoved`) never reaches it - they short-circuit to `grantedFree`
at the top of the chain.

Pass `context` to `requestAdGrant` so the promo has an overlay to present in.
Without one it falls back to the focused context, and skips the tier if there
is none.

### Why free grants are capped

Tier 4 exists so no-fill is never a dead end, but an ungated Tier 4 is an infinite faucet: tap, no fill, free coins, repeat. Each [AdGrantCooldownGroup](../lib/src/ads/ad_grant_cooldown_group.dart) therefore carries its own window (default 1h):

| Group | Placements | Why |
| --- | --- | --- |
| `currency` | coins, category unlock, rental | Fungible - spendable on anything, so it needs the tighter leash. |
| `functional` | heart, hint, revive | 0-state gated - the player is already stuck and the reward buys nothing else. |

Pick the group by **what the reward is**, not which screen asked. A new coin faucet is `currency`; a new "you are out of X" refill is `functional`.

The expiry is persisted as epoch milliseconds, which is absolute UTC - moving the device to another timezone cannot shorten it. Only a **consumed** free grant stamps the window. An ad loading later does **not** clear it: the window gates the free reward, never the player's ability to watch an ad. So with the window spent and inventory back, the player gets the ad.

---

## Hard rules (every host)

1. **Grant fires exactly once per attempt.** One `requestAdGrant` → one outcome. Overlapping calls are queued so two fullscreens cannot run at once. Hosts must still disable the tile / button while a grant is in flight, and applying the same rent twice must be safe.
2. **Never hang.** Probe 2s. Rewarded load wait 4s. Interstitial show 60s. Rewarded show 3 min. Every stall falls onward; a probe throw or timeout means `offline`, never a free grant.
3. **Rewarded success = reward actually earned**, from the reward callback only. Close can arrive *before* it, so the controller resolves close after a 500ms grace and counts a reward landing inside it.
4. **Offline = polite message, no grant.** Free content and banked coins still work.
5. **Each non-granting outcome needs its own message.** Three different failures; one message for all three tells the player something untrue. See the table below.
6. **Dispose ads on consume and teardown.** The kit disposes the shown ad on dismiss, failed show, `adsRemoved`, and `AdsModule.dispose`. Hosts must not hold native ad objects, and must not call `GameKit.ads.dispose()` on a screen pop - the module is process-scoped.
7. **Check purchases before any popup.** Already unlocked (Premium / rental / forever IAP) → open content, no dialog. `GameKit.ads.shouldSkipAdGrantOffer` → skip the watch-ad dialog entirely.
8. **The ads kill switch does not stop this chain.** `AdsConfig.adsEnabled: () => false` suppresses banners and boundary interstitials, but a player who tapped "watch an ad" still gets the rewarded ad. Only Tier 2 (the fallback interstitial) is skipped, so with no rewarded fill the chain goes to the house ad, then the **capped** free grant (`grantedFree`). Do not add a host-side `if (adsEnabled)` in front of `requestAdGrant` - that is the branch that produced both an uncapped faucet and a dead button in different apps. See [ADS.md](ADS.md#kill-switch-adsconfigadsenabled).

---

## Outcomes and host messages

| Outcome | `isGranted` | Host behaviour |
| --- | --- | --- |
| `grantedRewarded` | yes | Apply the grant. Neutral success copy. |
| `grantedInterstitial` | yes | Apply the grant. Neutral success copy. |
| `grantedHouseAd` | yes | Apply the grant. Neutral success copy - they watched a fullscreen, so no "here is your reward anyway". |
| `grantedFree` | yes | Apply the grant. Honest copy is fine: "No ad available, here's your reward anyway!" |
| `offline` | no | "Connect to the internet to continue." No grant. |
| `skipped` | no | "The ad didn't finish, so there's no reward this time." No grant. |
| `noneAvailable` | no | "No ads available right now. Try again later." No grant. |

`isGranted` is enumerated positively, so an outcome added later defaults to **not** granting - the cheap direction to get wrong.

Use `GameKit.ads.freeGrantAvailableAt(group)` for a "back in 14h" countdown on a `noneAvailable` screen.

> **Copy note.** Earlier versions of this doc banned the phrase "no ad available" on a free grant. That is reversed: naming it is honest, and the 1h cap is what stops the phrase from teaching players to farm it. Never imply the *player* failed on a `grantedFree`.

---

## Host wiring

Warm inventory on the screen that shows the locked tile or the coins button (`GameKit.initialize` preloads once; call again when that screen opens):

```dart
unawaited(GameKit.ads.preloadAds());
```

On confirm of the tap:

```dart
if (isAlreadyUnlocked) {          // Premium / active rental
  openContent();
  return;
}

unawaited(GameKit.ads.preloadAds());

if (!GameKit.ads.shouldSkipAdGrantOffer) {
  final bool confirmed = await showWatchAdDialog();   // host UI
  if (!confirmed) return;
}

setState(() => _busy = true);     // the double-tap guard is the host's job
try {
  final AdGrantOutcome outcome = await GameKit.ads.requestAdGrant(
    placement: 'spy_category_unlock',
    categoryId: category.id,
    cooldownGroup: AdGrantCooldownGroup.currency,
  );

  switch (outcome) {
    case AdGrantOutcome.grantedRewarded:
    case AdGrantOutcome.grantedInterstitial:
      grantHostContent();
      showSuccess();
    case AdGrantOutcome.grantedFree:
      grantHostContent();
      showFreeGrantToast();       // 2-3s, celebratory
    case AdGrantOutcome.offline:
      showOfflineDialog();
    case AdGrantOutcome.skipped:
      showAdNotFinishedDialog();
    case AdGrantOutcome.noneAvailable:
      showTryAgainLaterDialog();  // optionally with freeGrantAvailableAt
  }
} finally {
  if (mounted) setState(() => _busy = false);
}
```

Show a spinner (`Loading ad…`) on the button for the whole call, not just the 4s load window - the rewarded show sits inside the same await.

Offer dialogs still log `ad_rewarded_offered` / `ad_rewarded_declined` in the **host**; pass the same `placement` into `requestAdGrant`.

---

## Kit behaviour (do not reimplement)

- **Probe:** 2s `GET https://www.gstatic.com/generate_204`. Timeout, error or throw → `offline`.
- **Tier 1 wait:** only when nothing is cached. The load is left running on timeout, so the next tap usually finds inventory. `AdsConfig.rewardedWaitTimeout` of `Duration.zero` restores the old preloaded-only behaviour.
- **Tier 1 earn** stamps the shared interstitial cooldown (no session-cap bump) so a boundary interstitial cannot fire straight after the video.
- **Tier 2** ignores the session cap and the cooldown **gate**, then **stamps** the cooldown. Shown silently - the kit adds no "watch this ad" UI.
- **Reload backoff:** after any show or failed load, inventory is reloaded 1s, 2s, 4s … doubling to `AdsConfig.adReloadBackoffMax` (60s), then holding. A success resets the ladder. Cancelled on `dispose` and when `adsRemoved` turns on. `Duration.zero` disables the timer and does a single immediate reload - what tests want.
- **`adsRemoved`** makes `shouldSkipAdGrantOffer` true, and `requestAdGrant` returns `grantedFree` with no probe, no ad and **no cooldown consumed**.
- Overlapping taps are queued. An SDK throw falls to the next tier instead of aborting the tap.
- After a rewarded or Tier 2 interstitial actually showed: emit `AdClosedEvent` (rating's 60s gap). Does **not** run `adClosed()` - the remove-ads tooltip stays on natural-boundary ads.

### Analytics

`ad_grant` fires for **every** outcome with `placement`, `tier`, `country`, `cooldown_group` and optional `category_id`. It is the funnel denominator; `tier` is one of `rewarded`, `interstitial`, `house_ad`, `free`, `offline`, `skipped`, `none_available`.

Four per-tier events carry the same dimensions and are sliceable without a tier filter:

| Event | Fires when | Read it as |
| --- | --- | --- |
| `ad_rewarded` | Tier 1 earned | paid inventory worked |
| `interstitial_fallback` | Tier 2 paid | rewarded demand is thin here |
| `house_ad_fallback` | Tier 3 paid | no network demand at all, but we got a cross-install |
| `free_grant` | Tier 4 paid | **revenue given away** |

Plus `ad_rewarded_completed` on a Tier 1 earn. The premium short-circuit logs `ad_grant` only - counting a payer as a `free_grant` would inflate the no-fill metric.

`country` is the device region (ISO 3166-1 alpha-2), or `unknown`. It is logged explicitly rather than left to Firebase's IP geo, which a VPN moves. Watch `free_grant` over `ad_grant` per country: sustained volume is the signal to add bidders (Mintegral, Pangle, Meta) or tighten the cap. `house_ad_fallback` rising while `free_grant` falls is the house-ad tier doing its job.

---

## What not to do

- Do not call `showRewarded()` for unlocks or coins.
- Do not grant when `showRewarded()` returns false.
- Do not refuse the tap because `canShowRewarded` / `isRewardedReady` is false - the chain handles that.
- Do not cold-load an interstitial for this flow.
- Do not treat a skipped rewarded as no fill, or a failed show as a skip.
- Do not clear a free-grant window because an ad finally loaded.
- Do not show one message for `offline`, `skipped` and `noneAvailable`.
- Do not treat `grantedHouseAd` as a no-fill give-away in host copy - the player watched a fullscreen for it.
- Do not route the grant chain through `tryShowReplacingInterstitial`; it consumes the cadence alternation flag. Use `tryShowForGrant`.
