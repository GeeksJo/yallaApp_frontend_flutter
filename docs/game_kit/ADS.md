# Ads

Every GeeksJo game used to ship its own cadence, cooldown, and `adClosed`
bookkeeping. Missing `adClosed()` broke rating’s 60s gate and the remove-ads
confirm dialog. The kit owns **when** a fullscreen may show; the host only reports
level outcomes and handles the “show now” signal.

`lib/src/ads/` · `GameKit.ads` · `AdsConfig`

> **Serving no ads?** The network adapter Gradle lines, mediation groups and
> emulator GPU settings a host must get right live in
> [LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md). Start there.

## Why this shape

Cadence lives in `AdsStateMachine` (`levelCompleted`). Cooldown and session cap
live in `showInterstitial` because they need a real dismiss timestamp. Splitting
them keeps “should we even try?” separate from “did a fullscreen actually close”.
The same cooldown key is also stamped when a rewarded video is **earned**
(`showRewarded` / grant Tier 1) so players are not hit with an interstitial
immediately after watching an opt-in video.

The cooldown always starts when the player **closes** the ad. The interstitial
show waits for `onAdClosed`; its 60s timeout only gives up on an ad that never
**displayed**. A displayed ad is waited on however long it stays open (a long
video, an end card, a player who left the app), so it is never mistaken for a
no-show that starts no cooldown. See `waitForFullscreenClose`.

`runInterstitialCycle` is the safe path: load → show → **always** `adClosed()`
(rating). The remove-ads **confirm dialog** (same UI as Settings — not a
Material tooltip) only follows a **shown network** interstitial
at the end of a round / level. Manual `showInterstitial` still requires the
host to call `adClosed()`.

Which SDK serves is behind `AdNetworkController`. `AdsModule` holds every rule
- cadence, cooldown, session cap, the grant chain, promo rotation, analytics -
and names no network, so a second implementation is a new class rather than a
rewrite. `AdsLevelPlayController` is the one that ships.

Never call `levelCompleted` mid-puzzle. Failures (`failed: true`) do not bump
the counter and do not emit the interstitial signal.

## Surfaces

| Kind | Use |
|------|-----|
| Interstitial | Natural boundaries only. Default every **2nd** success, **40s** cooldown after close, max **8**/session. After a **shown network** interstitial at the end of a round / level (never a house-ad / Sawaleef slot, never a no-fill), the kit may show the same remove-ads **confirm dialog** as settings (`no_ads` icon, title, price, Confirm / Cancel) — from the **2nd app session** onward, on the **3rd network interstitial close** in that session, at most **once per session**, max **3** times ever, **4** local days apart. |
| Banner | `GameKitBannerSlot` - loads, hides when `adsRemoved`, disposes itself. Stays collapsed to zero height until the network reports fill, so a no-fill market shows nothing instead of a blank strip. |
| Rewarded (`showRewarded`) | Must-watch hints that **fail closed** if skipped. Remove-ads does **not** disable this. On earn, stamps the same **40s** interstitial cooldown so a boundary interstitial cannot stack right after the video. |
| Unlock / coins / refills | `requestAdGrant` - never `showRewarded`. See [AD_GRANT.md](AD_GRANT.md). Tier 1 (earned rewarded) and Tier 2 (fallback interstitial) both stamp that cooldown. A displayed-then-closed rewarded **stops** the chain; free grants are capped per `AdGrantCooldownGroup`. |
| Promo interstitial | Optional. Replaces the network on every other interstitial slot (promo, network, promo…), **and** serves as the grant chain's Tier 3 when neither paid tier fills. See [PROMO_ADS.md](PROMO_ADS.md). |

**Network adapters are the host's job.** `game_kit` is a pure Dart package with
no `android/` or `ios/`, and `unity_levelplay_mediation` ships only the
mediation core, so each host app declares the adapters and network SDKs it
needs in its own Gradle / Podfile. Getting this wrong fails **silently** - the
SDK initialises and no ad ever loads. Full instructions and the logcat lines to
grep for are in [LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md).

COPPA (`AdsConfig.childDirected`) is declared via `LevelPlayPrivacySettings`
**before** `LevelPlay.init`, so it reaches every adapter. GDPR / UK / CH
consent is gathered by Google UMP (`AdConsentService`), which is a certified
CMP only and independent of which network serves. LevelPlay mediation groups,
account-level network connections, and iOS `SKAdNetworkItems` stay host /
dashboard work.

Ad SDK init and `preloadAds()` start in the background from `GameKit.initialize`
and do not block first frame.

## Kill switch (`AdsConfig.adsEnabled`)

Pass the host's Remote Config flag as a **closure**, not a value:

```dart
ads: AdsConfig(
  // Read on every call, so publishing `ads_enabled: false` in the console
  // takes effect without a release.
  adsEnabled: () => remoteConfig.adsEnabled.value,
  ...
)
```

What it covers is a deliberate asymmetry:

| Surface | Switched off |
| --- | --- |
| Boundary interstitials (`runInterstitialCycle`, `showInterstitial`, `showInterstitialIfReady`) | **Suppressed.** No show, and `loadInterstitial` stops warming inventory. |
| Banners (`bannersEnabled`, `loadBanner`) | **Suppressed.** The slot collapses to zero height and no request is made. |
| A rewarded the **player asked for** (`requestAdGrant`) | **Still plays.** The chain runs as normal, minus the Tier 2 fallback interstitial. With no rewarded fill it falls to the house ad, then the *capped* free grant. |

The rewarded carve-out is the point of the whole design. The switch turns off
the same ads a Remove Ads purchase does - the ones we push at people - and
leaves alone an ad the player chose to watch. A tap on "watch an ad for coins"
must not dead-end, and it must not become an uncapped faucet either: without
fill it still lands on the free grant, which has its own cooldown. Rewarded
inventory keeps loading while switched off; only interstitial loads and retries
stop.

To stop rewarded ads as well, set `AdsConfig.rewardedAdsEnabled: false`.

Leave it unset (`null`) and ads are enabled. A host closure that **throws**
also fails open, matching that default: a broken probe must not silently cost
every impression in the app.

### After a Remote Config activation

Interstitials consult the switch at show time, so they need nothing. Banners
are a `ValueNotifier` and a closure cannot be listened to, so call:

```dart
GameKit.ads.refreshAdsEnabled();
```

That recomputes `bannersEnabled` and cancels the interstitial reload backoff
ladder. Without
it, banners keep whatever the switch said when the kit started.

**Do not re-branch on the flag at the call site.** Every host used to, and the
ones that got it wrong either blocked free players or handed out unlimited
currency. The kit owns the rule now; a host-side `if (adsEnabled)` around
`levelCompleted` only stalls the interstitial cadence counter.

## Known limits

- `adsRemoved` skips banners, interstitials, and the grant-chain offer. It does
  not skip must-watch rewarded.
- An unconfigured **prod** unit id stays **empty** and the controller skips the
  load. It does **not** fall back to a demo id: LevelPlay's demo inventory is
  real test fill that would serve to real users and earn nothing. (The AdMob
  path used to fall back; that behaviour is gone.)
- `AdUnitEnvironment.test` uses Unity's demo app keys and units. These are not
  tied to an account's serving status, so they work before a dashboard entry
  exists - but they are not a substitute for dashboard **test mode**, which is
  what serves test creatives on your own app key.
- The ads tunables (`interstitial_cooldown_seconds`,
  `interstitial_startup_grace_seconds`, `free_grant_cooldown_minutes`,
  `rewarded_wait_timeout_seconds`, `levelplay_app_key_android` / `_ios`) are
  read **host console first, then kit project, then compiled `AdsConfig`**.
  With `firebase:` set and a `remoteConfig:` adapter passed, the two are
  layered (`LayeredGameKitRemoteConfig`): a key the host console has a value
  for wins; an unset host key falls to the kit project; an unset kit key
  falls to the compiled default. Tune fleet-wide in the kit project once and
  override per app in the app's own console. The host layer is read through
  the adapter's `getString`, so an adapter that returns `''` for an unset
  key is all that is required - no `setDefaults` entry is needed for a key
  the host does not override, and adding one *is* an override.
- Remove-ads **dialog** is not every interstitial: after a shown end-of-round
  network ad only (skip promo / no-fill), from the **2nd app session** onward,
  on the **3rd shown network interstitial close** in that session (not the 1st
  or 2nd), once per session, max **3** lifetime, **4** local days between.
  `GameKitRemoveAdsTooltip.present()` opens the dialog (~450ms after the ad
  dismisses). `AdsModule.registerSessionLaunch()` runs from `GameKit.initialize`.
  Tune via `AdsConfig.removeAdsTooltipMinSession` and
  `removeAdsTooltipAfterInterstitialIndex`. API names still say “Tooltip” for
  compatibility; set `AdsConfig.presentRemoveAdsTooltip: false` only if the host
  shows its own dialog from `onShouldShowRemoveAdsTooltip`.
- House ads (`PromoInterstitialService`) serve both **cadence** slots (every
  other one, alternating with the network) and the grant chain's **Tier 3**
  (which does not alternate, since it is only reached when the network had
  nothing). Both draw on the same per-campaign dismissal budget, so grant-chain
  volume retires a campaign from cadence slots too.
