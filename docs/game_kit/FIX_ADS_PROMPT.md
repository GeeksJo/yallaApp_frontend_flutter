# Fix ads in a Flutter game (game_kit)

Copy this entire file into your agent when fixing ads in any host app that uses `game_kit`. It reflects the Sawalif / party-games migration and the current package ads behaviour.

> **The kit serves ads through Unity LevelPlay, not AdMob.** If you are reading
> an older copy of this file that says `AdMobUnitEnvironment`,
> `prodAdMobUnitIds`, `ensureMobileAdsInitialized`, or tells you to keep
> `google_mobile_ads` load/show wiring, it is out of date - those APIs no
> longer exist. The one AdMob piece that remains is Google **UMP**, used purely
> as a consent CMP. **Before anything else, read
> [LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md)**: the host-side Gradle adapters,
> mediation groups, and test-mode rules are where nearly every "configured
> correctly but serves nothing" case actually lives.

---

## Agent prompt (copy from here)

You are fixing ads in a Flutter game that uses the `game_kit` package. Ads must work through **`GameKit.ads`** only - not a custom host `AdsService`, not direct ad-SDK wiring in the host.

Read first:

- `game_kit` package: `README.md` (Ads section), **[LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md)** (host-side native setup - start here when no ads serve), **[AD_GRANT.md](AD_GRANT.md)** (unlock / get-coins / refill chain - copy this into every host), [ADS.md](ADS.md), this file
- Host app: `pubspec.yaml`, `main.dart` / bootstrap, any `AdsService` / `ads` / `banner` files, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `ios/Podfile`, `ios/Runner/Info.plist`, `.env` if present

### Required `game_kit` version

Use a `game_kit` build with the LevelPlay ads stack (local `path:` or git `development` after merge):

1. **`LevelPlay.init`** runs inside `GameKit.initialize` (`AdsModule.ensureNetworkInitialized`)
2. **`preloadAds()`** warms interstitial + rewarded after init (non-blocking)
3. `AdsConfig` takes **`adEnvironment`** + **`prodLevelPlayUnitIds`** (app key per platform, plus banner / interstitial / rewarded unit ids)
4. An unconfigured **prod** unit id stays **empty** and the load is skipped - it does **not** fall back to a demo id
5. All `GameKit.ads` load/show paths gate on successful SDK init and on `AdConsentService.canRequestAds`
6. `requestAdGrant` returns six outcomes (three granting, three not) and caps free grants per `AdGrantCooldownGroup`

If the resolved package lacks these, update `game_kit` first before changing the host app.

---

### Phase 0 - Audit (read-only)

Search `lib/` for host-owned ad wiring that must go:

- `MobileAds.instance`, `BannerAd`, `InterstitialAd`, `RewardedAd`, `AdWidget`
- `IronSource`, `LevelPlay*` used directly (the kit owns the SDK; hosts only supply ids)
- `AdsService`, custom banner widgets, `loadInterstitial`, `showInterstitial`, `levelCompleted`
- `ca-app-pub-` literals, and any Remote Config keys that served ad unit ids

And for the wiring that should be there:

- `GameKit.ads`, `GameKitBannerSlot`, `onShouldShowInterstitial`, `runInterstitialCycle`
- `requestAdGrant`, and whether the host handles **all six** `AdGrantOutcome` values
- `kAdsDisabledInRelease`, `shouldRunAds`, screenshot mode flags

List every file that touches ads. Note whether the app uses **custom host ads** vs **`GameKit.ads`**.

Verify native config:

- **Android** `android/app/build.gradle.kts`: a `<network>-adapter` **and** that
  network's own SDK for every network in the waterfall. This is the single most
  common cause of "no ads serve" - see [LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md).
- **iOS** `ios/Podfile`: the matching adapter pods.
- **Android** `AndroidManifest.xml` / **iOS** `Info.plist`: the AdMob **app** id
  (`com.google.android.gms.ads.APPLICATION_ID` / `GADApplicationIdentifier`) is
  still required while `google_mobile_ads` is linked for UMP consent. Never ad
  unit ids.
- **LevelPlay dashboard:** app active, ad units created, networks connected at
  account level (`networkReportingApi` verified), instances live, **and a
  mediation group per ad unit**.

---

### Phase 1 - Host app fixes (use `GameKit.ads`, remove duplicates)

#### 1. Bootstrap / `GameKitConfig`

In `GameKit.initialize` config, wire a real **`AdsConfig`**:

```dart
ads: AdsConfig(
  // Always prod. LevelPlay has no always-fill demo units the way AdMob did,
  // so a "test" environment on a real app key means no ads at all. Safe
  // testing comes from dashboard test mode + registered test devices.
  adEnvironment: AdUnitEnvironment.prod,
  prodLevelPlayUnitIds: LevelPlayProdUnitIds(
    appKeyAndroid: /* dashboard app key */,
    appKeyIos: /* dashboard app key */,
    interstitialAndroid: /* … */, interstitialIos: /* … */,
    bannerAndroid: /* … */,       bannerIos: /* … */,
    rewardedAndroid: /* … */,     rewardedIos: /* … */,
  ),
  childDirected: false,          // COPPA; declared before init, reaches adapters
  gatherUmpConsent: true,        // Google UMP as the consent CMP
  // showPromoInterstitial: true, // house ad on every other interstitial; off on the promoted app
),
```

- Unit ids and app keys are **public identifiers, not secrets** - a generated
  constants file is fine, `.env` is not required.
- `AdUnitEnvironment.test` exists for apps with no dashboard entry yet; it uses
  Unity's demo keys. Never ship it, and do not mistake it for dashboard test
  mode.
- Ensure `dotenv.load()` runs **before** `GameKit.initialize` if the host still
  reads flags from `.env`.

**Add to the host (the kit cannot do this for you):**

- **Network adapters + network SDKs in `android/app/build.gradle.kts`.**
  `game_kit` is pure Dart with no `android/`, and the mediation plugin ships
  only the core, so every adapter is the host's dependency. Missing adapters
  fail **silently**. See [LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md).
- A **mediation group per ad unit** on the dashboard. A live instance in no
  group never enters an auction and `onInitSuccess` never fires.

**Remove from host:**

- Any direct ad-SDK init in `main` / bootstrap (the kit does this)
- `google_mobile_ads` / `gma_mediation_unity` dependencies and any
  `UnityMediation.applyPrivacy()` bootstrap
- AdMob ad **unit** id constants, and the Remote Config keys that fed them
- Redundant `unawaited(GameKit.ads.loadInterstitial())` right after init
- Any dormant/empty `AdsConfig` left to disable the package ads module
- Any app-owned `AdsService` / `core/ads/` layer that duplicates `GameKit.ads`

**Keep:**

- `shouldRunAds` gate before calling `GameKit.ads` if the app uses that pattern
- The AdMob **app** id in `AndroidManifest.xml` / `Info.plist` **only while
  `google_mobile_ads` is still linked for UMP** - it is the consent SDK's
  requirement, not a serving one. Never ad unit ids.
- iOS `SKAdNetworkItems` (now driven by the LevelPlay network list)

#### 2. Interstitial listener (required)

Register once after `GameKit.initialize` (e.g. `GameKitListenersService`):

```dart
GameKit.ads.onShouldShowInterstitial.listen((_) {
  unawaited(GameKit.ads.runInterstitialCycle());
});
```

Do **not** call `showInterstitial()` without `adClosed()` unless you own the full manual flow. `runInterstitialCycle()` handles load → show → `adClosed()`.

#### 3. Level cadence call sites

Replace any custom interstitial triggers with:

```dart
if (shouldRunAds) {
  await GameKit.ads.levelCompleted(failed: false); // on win / round complete
}
// on fail / abandon:
await GameKit.ads.levelCompleted(failed: true);
```

Warm interstitial when entering game flow if the app already did that:

```dart
if (shouldRunAds) {
  GameKit.ads.loadInterstitial();
}
```

Defaults: every **2** completed levels, **40s** cooldown after close, **8** per session (package defaults - override in `AdsConfig` only if product requires).

#### 4. Banners

Use **`GameKitBannerSlot`** (directly or via a thin `HomeBannerAd` wrapper):

- Wait for `GameKit.initialize` before showing the slot
- Hide when route is not current (avoid duplicate iOS platform views)
- Respect `kScreenshotMode` and `shouldRunAds`

**Delete** custom `BannerAd.load` / `AppBannerAd` if they duplicate the package.

#### 5. Rewarded / unlock grants

**Unlocks, coins, “watch an ad to get X”** - copy **`docs/AD_GRANT.md`**. Do not use `showRewarded`. Host grants only when `isGranted`. Check **`shouldSkipAdGrantOffer`** before any watch-ad popup.

Hard rules (every host):

- Grant fires exactly once per attempt (idempotent; guard double-taps).
- Never hang - any stall/timeout falls through to the next tier.
- Rewarded success = reward actually earned, not just opened.
- Offline = polite message, no grant. Online no-fill = silent free grant.
- Dispose ads on consume and screen teardown.
- Purchased IAP state is checked before showing any popup (owners go straight to content).

```dart
unawaited(GameKit.ads.preloadAds());
final AdGrantOutcome outcome = await GameKit.ads.requestAdGrant(
  placement: 'category_unlock',
);
if (!outcome.isGranted) {
  // "Connect to the internet to unlock premium categories / earn coins"
  // STOP. No grant. Free categories / banked coins still work.
} else {
  grantHostContent();
  // "Category unlocked!" / "+50 coins!" - never "no ad available"
}
```

**Must-watch hints / extra moves** (fail closed if the user skips):

```dart
if (GameKit.ads.canShowRewarded(RewardedReason.skip)) {
  final earned = await GameKit.ads.showRewarded();
}
```

Leave `ADMOB_PROD_REWARDED_*` empty in `.env` until real rewarded units exist.

#### 6. Remove-ads gating

Banner/interstitial gating is automatic via **`GameKit.iap.adsRemoved`**. Do not reimplement ad-free logic in a separate ads service.

---

### Phase 2 - Delete obsolete host code

After all call sites use `GameKit.ads`, remove:

- `lib/core/ads/ads_service.dart`, `app_banner_ad.dart`, `ad_unit_ids.dart` (or equivalent)
- Host ad-SDK init
- Commented-out `onShouldShowInterstitial` listeners
- Duplicate load/show helpers wrapping any ad SDK directly
- AdMob unit-id constants and the Remote Config keys / `.env` entries that fed them

Run `flutter analyze` and fix imports.

---

### Phase 3 - Verify

1. **logcat shows the whole path:** `onInitSuccess`, then
   `Successfully loaded ad for placement …`. If instead you see
   `adapter was not loaded`, the Gradle adapter is missing - stop and fix that
   first.
2. Banners appear on home / game screens, and where nothing fills the slot
   takes **zero height** rather than leaving a blank strip.
3. Interstitials show only **between rounds**, never mid-gameplay.
4. **Grant chain**, on a locked category and on the coins button:
   - airplane mode → "connect to the internet", **no** grant
   - close the rewarded video early → no grant, and a message saying the ad
     did not finish
   - watch it fully → grant
   - no fill → free grant once, then "try again later" for an hour
5. **Remove Ads** purchase hides banners, blocks interstitials, keeps
   rewarded placements working, and never shows "try again later".
6. `GameKit.ads` is never used before `GameKit.initialize` completes.

On an emulator, enable GPU (`-gpu host`) or video creatives render black and
time out. Register the test device **and** turn on dashboard test mode - those
are two different settings ([LEVELPLAY_SETUP.md](LEVELPLAY_SETUP.md)).

---

### Common mistakes (do not repeat)

| Mistake | Fix |
|--------|-----|
| **Network adapter missing from host Gradle** | Add `<network>-adapter` + that network's SDK. Fails silently - check logcat for `adapter was not loaded`. |
| Instance live but in **no mediation group** | Create a group per ad unit; otherwise `onInitSuccess` never fires |
| Host initialises an ad SDK itself | Remove - `GameKit.initialize` does it |
| Empty prod unit ids in release | Set real ids on `LevelPlayProdUnitIds`; empty ids skip the load and never fall back |
| Shipping `AdUnitEnvironment.test` | Use `prod`; test mode belongs on the dashboard |
| Interstitial listener commented out | Enable `onShouldShowInterstitial` → `runInterstitialCycle()` |
| Custom `AdsService` + `GameKit.ads` both active | Pick **one** - use `GameKit.ads` only |
| `kAdsDisabledInRelease: true` | Set `false` when shipping ads |
| One "you are offline" message for every `!isGranted` | Handle `offline`, `skipped` and `noneAvailable` separately |
| Granting on a skipped rewarded | Only `isGranted` grants; `skipped` must not |

---

### Output expected from the agent

1. Short audit summary (what was wrong)
2. Files changed
3. Confirm no remaining host-side ad-SDK init or custom `AdsService`
4. Confirm the host handles all six `AdGrantOutcome` values
5. Test plan covering the Phase 3 list

---

## Using this with an agent

1. Open the **host game** workspace (and `game_kit` if using a local path dependency).
2. Paste the **Agent prompt** section above, or reference this file: `@gameKit_package_flutter/docs/FIX_ADS_PROMPT.md`
3. Have the LevelPlay app key and ad unit ids to hand (`levelplay_tools_node` can generate the constants file).
4. For local development before git merge:

   ```yaml
   dependency_overrides:
     game_kit:
       path: ../gameKit_package_flutter
   ```

   Then run `flutter pub get`. **Remove the override before committing** - CI
   resolves the git ref, so a host that compiles only against a local checkout
   will fail the build.

## Reference implementation

After migration, the host app should resemble:

- `lib/core/config/level_play_ids.dart` - app keys + unit ids (generated; public identifiers, not secrets)
- `lib/core/config/ad_config.dart` - host runtime flags only (`shouldRunAds`, cadence), no unit ids
- `lib/core/game_kit/bootstrap_game_kit.dart` - real `AdsConfig` with `prodLevelPlayUnitIds`, no host SDK init
- `lib/core/game_kit/game_kit_ads_helper.dart` - thin wrappers over `GameKit.ads`, outcome → message mapping
- `lib/core/game_kit/game_kit_listeners_service.dart` - `onShouldShowInterstitial` → `runInterstitialCycle()`
- `lib/core/common_widgets/home_banner_ad.dart` - thin wrapper around `GameKitBannerSlot`
- `android/app/build.gradle.kts` - network adapters + network SDKs
