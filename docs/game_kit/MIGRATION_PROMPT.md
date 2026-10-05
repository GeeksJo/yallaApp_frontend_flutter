# game_kit - migration prompt (self-contained)

This file is **complete by itself**. Do not rely on other markdown files in this repository, external README links, or in-repo source URLs. Everything below is enough to migrate a host app onto `game_kit` and remove legacy code. If a symbol’s exact signature is unclear, inspect the resolved **`game_kit`** package in your project’s pub cache or path dependency **after** `flutter pub get` - do not invent APIs.

For a **focused ads-only fix** (no full migration), use **`docs/FIX_ADS_PROMPT.md`** - copy it into Cursor or `@`-reference it from the host app workspace.

---

You are migrating an existing Flutter game to the `game_kit` package and cleaning up the now-obsolete code. Treat this as a **careful refactor**, not a greenfield integration. Follow the phases in order. Do **not** skip ahead, and do **not** delete anything until the replacement is wired and the project compiles.

### Success criteria (definition of done)

- **`GameKit.initialize` runs once** per cold start, after `WidgetsFlutterBinding.ensureInitialized()` and (if needed) Hive box open; no use of `GameKit.*` before that completes.
- **Ads:** Every level end calls **`levelCompleted`**. The app shows interstitials only in response to **`onShouldShowInterstitial`** (or uses **`showInterstitial`** and still follows the **`adClosed`** contract below). **`adClosed`** runs after **every** interstitial attempt ends (shown, failed, or dismissed) - not only when an ad was shown. The package brings the ad SDK up (**`LevelPlay.init`**) during **`GameKit.initialize`** and preloads interstitial/rewarded - **do not** initialise an ad SDK again in the host app.
- **IAP:** Remove-ads and donations use **`IapConfig`** SKUs identical to the live store. **`onPurchaseComplete`** grants consumables the host still owns (coins, etc.). **`adsRemoved`** drives banner/interstitial gating.
- **Rating:** **`levelSucceeded`** uses the same **1-based** level numbering the product already uses. **`levelFailed`** runs on loss/abandon. Soft-prompt and feedback streams are subscribed **once**; user responses call **`respond`**.
- **Notifications:** **`onFirstDailyCompletion`** and **`markPlayedToday`** are called from the same semantic milestones the host used before (or you document intentional changes with the user). If the host already has `[DEFAULT]` Firebase, register **`gameKitFirebaseMessagingBackgroundHandler`** in `main()` (after **`Firebase.initializeApp()`**, before **`runApp`**) and keep **`NotificationsConfig.enableFcm`** true (default) so topic **`all_users`** is joined after permission. Campaigns send notification **title + body** only.
- **Cleanup:** Legacy services/files/deps that only existed for the above are removed; **`flutter analyze`** and **`flutter test`** are clean; a debug **device** smoke test passes (see Phase 5).
- **Sound + vibration mute (when using kit settings):** **`GameKitSettingsBody`** **Sound effects** and **Vibration** toggles persist across restart and gate **`GameKit.sounds`** / **`GameKit.haptics`**; remove duplicate host sound/vibration prefs/UI.
- **Android + kit Contact email:** If **`GameKitSettingsBody`** shows the Contact email row (or any **`mailto:`** link), **`AndroidManifest.xml`** includes **`SENDTO`/`mailto`** **`<queries>`** per **Platform checklist** so Android 11+ resolves handlers.
- **Force update:** **`ForceUpdateGate`** wraps the app root (or `MaterialApp` child); the blocking update screen appears when Remote Config's `min_required_version` exceeds the installed build; the host supplies a `ForceUpdateRemoteConfig` bridge to their Remote Config SDK.
- **Economy + shop (when adopted):** Coin balance and inventory migrate without loss via **`migrateLegacyEconomyForGameKit`** **before** init. Gameplay spends through **`GameKit.economy.useAction`**. The host’s own wallet is **deleted**, not kept in parallel. The shop is **`GameKitShopBody`** themed with **`GameKitShopUiConfig`**.
- **Puzzle product bar:** After migration, run through **Puzzle game developer cheat sheet and acceptance criteria** below and confirm each item is met or explicitly waived with the product owner.

### Puzzle game developer cheat sheet and acceptance criteria

Use this as a **product + engineering checklist** when integrating or QA’ing a puzzle-style game on `game_kit`. **`[host]`** means the host app (or store / ad mediation setup) must implement it - `game_kit` does not replace it. **`[kit]`** means wire the stated `game_kit` APIs/config; behavior matches when defaults or noted overrides are used.

1. **Haptics, vibration, and audio**
   - **Acceptance:** Haptic feedback, motor vibration, and satisfying **sound effects** on correct moves and level completion. **Sound effects** and **Vibration** toggles in settings **persist after restart** (mute/unmute).
   - **`[kit]`** Call **`GameKit.haptics`** AND **`GameKit.sounds`** (same methods: `validAction`, `invalidAction`, `milestoneSuccess`, `lightTap`) from gameplay/domain code.
   - **`[kit]`** **`GameKitSettingsBody`** includes an **Audio** section with **Sound effects** and **Vibration** switches (default **on**). Preferences are stored by **`GameKit.preferences`** (`soundsEnabled`, `vibrationsEnabled`, persisted under `game_kit.preferences.*`) and gate **`GameKit.sounds`** / **`GameKit.haptics`** automatically after **`GameKit.initialize`**. Hide the section with **`GameKitSettingsUiConfig(hasAudio: false)`** if the host keeps its own toggles.
   - **`[kit]`** Optional extra gating: **`HapticsConfig.isEnabled`** / **`SoundConfig.isEnabled`** on **`GameKitConfig`** - both must allow playback (kit preference **AND** host gate when set).
   - **`[kit]`** The package ships default sound cues and pre-loads them; override per event via **`SoundConfig.overrides`** (`GameKitSound.asset(...)`), silence one with **`GameKitSound.none()`**, opt out entirely with **`SoundConfig(enabled: false)`**, or swap the engine via **`soundClient`**.
   - **`[host]`** Provide your own cue files only if you want different audio than the bundled defaults. Remove legacy host sound/vibration prefs and settings rows once **`GameKitSettingsBody`** is adopted (or wire config **`isEnabled`** only if you keep custom toggles). Replace host **`VibrationService`** / direct **`HapticFeedback`** calls with **`GameKit.haptics`**.

2. **Rewarded video ads / unlock-or-coin grants**
   - **Acceptance:** Rewarded video for **hints**, **extra moves**, or **level skips** that should fail closed if the user skips. **Unlocks, coins, and “watch an ad to get X”** use the grant chain so airplane mode cannot farm free rewards.
   - **`[kit]` Unlocks / coins:** copy **`docs/AD_GRANT.md`** (TAP flow + **hard rules**). **`await GameKit.ads.requestAdGrant(placement: …)`**. Check **`shouldSkipAdGrantOffer`** before any watch-ad popup. Offline / timeout → **STOP**, no grant; free packs and banked coins still work. Grant only when **`outcome.isGranted`**. There are now **three** non-granting outcomes and each needs its own message: **`offline`** ("Connect to the internet to continue", no grant), **`skipped`** (the player closed the rewarded video early - no grant, say the ad did not finish), and **`noneAvailable`** (no fill *and* the free grant is on cooldown - "try again later", optionally with `GameKit.ads.freeGrantAvailableAt(group)`). A single "you are offline" message for all three tells the player something untrue. On **`grantedFree`** it is fine to name it ("No ad available, here is your reward anyway") - the per-group 1h cap is what stops that copy from teaching players to farm it. Pass a **`cooldownGroup`**: `currency` for coins / unlocks / rentals, `functional` for heart / hint / revive.
     - Grant fires exactly once per attempt (idempotent; guard double-taps).
     - Never hang - any stall/timeout falls through to the next tier.
     - Rewarded success = reward actually earned, not just opened.
     - Offline = polite message, no grant. Online no-fill = silent free grant.
     - Dispose ads on consume and screen teardown.
     - Purchased IAP state is checked before showing any popup (owners go straight to content).
   - **`[kit]` Must-watch hints/skips:** Gate with **`GameKit.ads.canShowRewarded(RewardedReason.hint)`**, **`extraMoves`**, or **`skip`**, then **`await GameKit.ads.showRewarded()`** - returns true only when the reward was earned. Remove-ads IAP does **not** block this path.
   - **`[host]`** Preload on the locked-content screen: **`unawaited(GameKit.ads.preloadAds())`**. Do **not** grant when `showRewarded()` is false.

3. **Interstitial ads (cadence and placement)**
   - **Acceptance:** Interstitials **only between levels**, never mid-puzzle. **Every 2nd completed level**, **40-second cooldown** starting **after** the ad **closes**, **max 8** interstitials **per session**.
   - **`[kit]`** Set **`AdsConfig.interstitialEveryNLevels`** to `2`, **`interstitialCooldownSeconds`** to `40`, **`interstitialMaxPerSession`** to `8` (these are the package **defaults** - keep them unless the product owner approves a change). Call **`levelCompleted(failed: false)`** only when a level is **finished** from a between-level flow; call **`levelCompleted(failed: true)`** on fail/abandon so cadence does not treat it as a completed level.
   - **`[kit]`** Handle **`onShouldShowInterstitial`** with **`GameKit.ads.runInterstitialCycle()`** so cooldown/session caps and **`adClosed()`** are enforced automatically.
   - **`[host]`** Never subscribe to **`onShouldShowInterstitial`** in a way that shows an ad **during** active puzzle input. Show only in **between-level** UI (lobby, map, “next level” transition).

4. **Remove Ads IAP ($2.99)**
   - **Acceptance:** One-time **Remove Ads** IAP at **$2.99** (price is set in **Play Console / App Store Connect**, not in Dart).
   - **`[kit]`** **`IapConfig.removeAdsProductId`** must be the live non-consumable SKU.
   - **`[host]`** Small **persistent** “no ads” affordance on the **main gameplay** screen opens the **same** remove-ads confirmation as settings - use **`GameKitRemoveAdsIconButton`** and/or **`gameKitRunRemoveAdsPurchaseFlow`** from **`package:game_kit/game_kit.dart`** (not a one-off custom dialog). Settings can also expose remove ads; this item still requires the **in-game** entry point.

5. **No interstitial after a failed attempt**
   - **Acceptance:** Never show an interstitial after the player **fails** a level - they’re already frustrated.
   - **`[kit]`** **`await GameKit.ads.levelCompleted(failed: true)`** on fail/abandon does **not** bump completed-level count and does **not** emit **`onShouldShowInterstitial`** for that outcome.

6. **Ad quality (no deceptive close controls)**
   - **Acceptance:** No **fake X** buttons on ads - use **mediation** and filter **bad ad networks**.
   - **`[host]`** AdMob / mediation configuration, blocking rules, and creative policies are **outside** `game_kit`. Document provider choices in the Phase 5 report if relevant.

7. **Remove-ads tooltip after “skip” on an ad**
   - **Acceptance:** When the player taps **skip** (or dismisses without full engagement, per your UX), show a **one-time** tooltip: _“Tired of ads? Remove them forever - $2.99”_ (or equivalent).
   - **`[kit]`** The package emits **`GameKit.ads.onShouldShowRemoveAdsTooltip`** after a **shown AdMob** interstitial (not a house-ad slot), capped (once per session, max 3 lifetime, 4 local days). If you set **`presentRemoveAdsTooltip: false`**, **`[host]`** show the same copy from that stream - match the **$2.99** pitch to the live store listing.

8. **Offline play**
   - **Acceptance:** **Offline** play works **fully** for core puzzle gameplay.
   - **`[host]`** Puzzle content, saves, and logic must not **hard-depend** on network. `game_kit` cross-promo catalog and ads may be unavailable offline; the game should **degrade gracefully** (no crash; optional “more games” disabled).

9. **More puzzles / cross-promo**
   - **Acceptance:** **“More Puzzles”** (or similar) on the **main menu** with a **NEW** badge when a **new game** appears in the catalog.
   - **`[kit]`** **`GameKit.crossPromo.hasNewGame`** / **`hasNewGameChanges`**, **`markGamesViewed()`** after the user opens the list, **`showCrossPromotionBottomSheet`** or custom grid from **`getGames()`**.

10. **Push notifications (local, weekly pattern)**
    - **Acceptance:** **3 times per week**, **not** daily. **Three fixed weekdays** (example: **Saturday, Monday, Wednesday**) at **6pm local**. Message like _“Your daily puzzle is ready”_ (or appropriate). **No** notification in the **first 48 hours** after install. **If the player already played today**, **don’t send**. If the player **ignores 3** notifications **in a row**, **stop** until they **open the app** again. **iOS:** ask for notification permission **after the first daily puzzle completion**, **not** on first launch.
    - **`[kit]`** In **`NotificationsConfig`**, set **`days:`** to **`[DateTime.saturday, DateTime.monday, DateTime.wednesday]`** (or the three days product chooses), **`hour:`** to **`18`**, **`installDelayHours:`** to **`48`**, **`stopAfterIgnoredCount:`** to **`3`**, and **`notificationTitle` / `notificationBody`** to the approved copy. Call **`GameKit.notifications.onFirstDailyCompletion()`** when the “first daily completion” milestone is hit (permission gate - not cold launch). Call **`GameKit.notifications.markPlayedToday()`** when the player has **played today** (your definition) so the scheduler does not treat the day as “needs nag.”
    - **`[kit]` FCM:** Leave **`enableFcm`** at default **true**. After permission, the kit subscribes to topic **`all_users`**. Campaigns send **notification title + body** from the **host** Firebase Console (not the named `game_kit` app). Host `main()` must call **`Firebase.initializeApp()`** then **`FirebaseMessaging.onBackgroundMessage(gameKitFirebaseMessagingBackgroundHandler)`** before **`runApp`**. FCM is skipped automatically when `[DEFAULT]` Firebase is not initialized; opt out with **`enableFcm: false`**.
    - **`[host]`** Confirm **`androidChannelId`** matches the shipped app if updating an existing title. iOS: Push Notifications capability + Background Modes → Remote notifications; APNs on the host Firebase project.

11. **Rating prompt (two-step, sentiment-based)**
    - **Acceptance:**
      - Trigger after a **successful** level completion.
      - Only if **level ≥ 4** and **session ≥ 2**.
      - **Not** after a **failed** level (suppress on the **next** win only - call **`levelFailed`** on fail).
      - **Not** within **60 seconds** after an ad closes (call **`adClosed`** so the kit tracks this).
      - **Soft prompt first:** _“Enjoying the game?”_
      - **Positive** → **store rating** (in-app review / store flow).
      - **Negative** → **feedback** (do **not** push store rating).
      - **Maximum 3** total prompts per user (lifetime soft prompts).
      - **Wait at least Calendar 4 days** between prompts; **never** more than **once per calendar day**.
      - If the user **rates** (positive path completed) → **never** show again.
      - If **dismissed 3 times** → **never** show again.
    - **`[kit]`** Use **`RatingConfig`** with **`minLevel: 4`**, **`minSession: 2`**, **`maxLifetime: 3`**, **`minDaysBetween: 4`**, **`minSecondsAfterAd: 60`**, **`maxDismissals: 3`** (these match the **package defaults**). Subscribe to **`onShouldShowSoftPrompt`** / **`onShouldShowFeedbackForm`**; implement the two-step UI; call **`GameKit.rating.respond(RatingResponse.positive | negative | dismissed)`**. After every interstitial flow end, call **`GameKit.ads.adClosed()`**. On level fail: **`GameKit.rating.levelFailed()`**; on win: **`GameKit.rating.levelSucceeded(level: <1-based>)`**.

12. **Force update gate**
    - **Acceptance:** When the server sets `min_required_version` in Remote Config to a value higher than the installed build, the app shows a blocking update screen (bundled rocket illustration, title, description, outlined **Update Now** button) with a direct store link. Back navigation is impossible; the only action is opening the store.
    - **`[kit]`** Wrap the `MaterialApp`'s `home` (or the router widget) with **`ForceUpdateGate`**. Pass a **`ForceUpdateService`** built from your **`ForceUpdateConfig`** and a host-owned **`ForceUpdateRemoteConfig`** adapter. Supply **`ForceUpdateStrings`** via the `strings` resolver - use `ForceUpdateStrings.english()` / `.arabic()` factories or a custom builder keyed on `GameKit.locale.languageCode`. Set screen colors on **`ForceUpdateConfig`** (`backgroundColor`, `textColor`, `buttonColor`, `buttonTextColor`). Optionally pass an **`illustration`** widget to override the default bundled rocket (`assets/images/startup.png`).
    - **`[host]`** Implement **`ForceUpdateRemoteConfig`** by wrapping your Firebase Remote Config (or equivalent) instance. Set `isReady` to `true` only after your Remote Config has been fetched and activated. In Remote Config, publish **`min_required_version`** (e.g. `1.3.0`) to trigger the gate; leave it empty or at/below the current version to let users through.
    - **`[host]`** Fetch + activate Remote Config _before_ mounting **`ForceUpdateGate`** when possible. If RC is not ready (`isReady == false`), the gate always passes and shows the child - the re-check on next app resume will catch it.

13. **App moved gate** (only if this binary is a last update on an old package / bundle id)
    - **Acceptance:** When the server sets `show_app_moved` to `true`, the app shows a blocking “we moved” screen with a download button to the **new** store listing. Back navigation is impossible.
    - **`[kit]`** Wrap the app root (outside the splash / `GameKitReadyGate` if the host has one) with **`AppMovedGate`**. Pass **`AppMovedConfig`** (same four emergency colors as force-update). Copy is kit EN/AR. Pass the host logo as **`illustration`**. Optional **`recheck`** listenable so a console publish swaps the tree live.
    - **`[host]`** Reuse the same **`ForceUpdateRemoteConfig`** adapter. Publish Boolean **`show_app_moved`** (default false) and **`new_android_store_url`** / **`new_ios_store_url`** before flipping the flag. Do **not** reuse force-update `android_store_url` / `ios_store_url` - those stay the current listing.

14. **Store and coin economy**
    - **Acceptance:** One coin currency. Starting grant once on install (spec default **100** coins + free stock for declared spend actions). Hint/solve (or host-declared actions) consume **free stock before coins**. Shop shows live store prices, a **pinned Remove Ads** row, and a rewarded free-coins card with **daily cap** and **cooldown** (“X/5 left today”, greyed when not ready). Daily login pays the streak ladder on the first open of a new local day after install day. Offline play still spends banked coins; a missing ad never grants and never blocks the shop.
    - **`[kit]`** Pass **`GameKitConfig.economy`** (`EconomyConfig`, defaults = word-game spec) and **`shopUi`** (`GameKitShopUiConfig`). Persist under `game_kit.economy.*`. Call **`migrateLegacyEconomyForGameKit`** before init with the host’s live coin/inventory keys. Gameplay calls **`GameKit.economy.useAction(actionId)`**. Shop: compose **`GameKitShopBody`** (or **`GameKitShopScreen`**). Catalog SKUs are credited by the kit - do **not** also grant in a host **`onPurchaseComplete`** listener, and do **not** list those SKUs in **`IapConfig.consumableGrantsByProductId`**.
    - **`[host]`** Replace the old wallet / hint inventory. Wire **`claimDailyLoginIfDue()`** when the host is ready to show a celebration. Map live SKUs, costs, and starting balances into **`EconomyConfig`** if they differ from the spec. Delete the host shop screen after cutover.

**Phase 5** manual verification must explicitly tick through **§ Puzzle game developer cheat sheet** where the shipped product claims puzzle-spec compliance.

### Information to confirm with the user before Phase 2

Ask if anything is unknown from the repo:

- **Store IDs:** `removeAdsProductId`, three **donation** SKUs ( **`IapConfig` requires all three** even if the UI hides some - IDs must exist in Play Console / App Store Connect or the build must tolerate missing products), any **consumable** shop SKUs for `consumableGrantsByProductId`.
- **Ads:** A LevelPlay **app key** per platform plus six **production** unit ids (interstitial/banner/rewarded × Android/iOS). Ship **`AdUnitEnvironment.prod`**; `test` uses Unity demo keys and is only for an app with no dashboard entry yet.
- **Notifications:** Live **Android channel id** (changing it strands old channels), title/body copy. If the product follows **§ Puzzle game developer cheat sheet**, override **`NotificationsConfig.days`** (e.g. Sat/Mon/Wed), **`hour: 18`**, **`installDelayHours: 48`**, **`stopAfterIgnoredCount: 3`** - do not rely on package defaults (Mon/Wed/Fri at 19:00) for that spec. Confirm host `[DEFAULT]` Firebase is initialized in `main` and APNs / `google-services.json` exist if FCM should run.
- **Targets:** Confirm **Android + iOS** (and not web/desktop as primary) if integrating **Google Mobile Ads** - otherwise stop and agree a reduced scope with the user.
- **Storage:** SharedPreferences only vs Hive vs **dual**; open Hive before init if the host uses Hive/dual storage.
- **Settings / Contact:** If integrating **`GameKitSettingsBody`** with the Contact email row on **Android**, confirm **`AndroidManifest.xml`** will include **`SENDTO` + `mailto`** **`<queries>`** (see **Platform checklist**) - required on Android 11+ for **`mailto:`** to resolve.
- **Force update:** Confirm whether the host uses Firebase Remote Config (or another service) and whether it is already integrated. The `ForceUpdateRemoteConfig` bridge must be implemented by the host. Confirm that the Remote Config keys **`min_required_version`**, **`android_store_url`**, and **`ios_store_url`** (from `ForceUpdateRemoteConfigKeys`) match the live RC parameter names - rename if needed on the server side.
- **Economy / shop:** Confirm consumable coin SKUs, coin costs (hint/solve or host actions), starting coins + free stock, rewarded coins per view / daily cap / cooldown, and the **exact SharedPreferences (or Hive) keys** holding live balances. Confirm whether the host will adopt **`EconomyModule`** now or keep coins host-owned.

### Operating rules (apply to every phase)

- **Read first, edit second.** Read **this entire document** before editing the host app. Do not guess at method names, parameters, stream names, or storage keys.
- **Do not invent APIs.** If a symbol is not exported from `package:game_kit/game_kit.dart`, it does not exist. Stop and ask the user.
- **Minimal, scoped diffs.** Touch only files that are part of the migration. Do not reformat, rename, or refactor unrelated code.
- **Preserve product behavior.** The user-visible flows (when an interstitial fires, when a rating prompt appears, what notification copy says, what the settings screen looks like) must remain equivalent unless the user explicitly approves a change.
- **One module at a time.** Migrate ads, IAP, rating, notifications, cross-promo, share, haptics, and sounds in separate commits / steps. Verify each compiles before moving on.
- **Never delete legacy code in the same step that introduces the new code.** Delete only after the new wiring is in place and call sites have moved.
- **Stop and report** if you find: a feature in the host app that the package does not cover, a storage key that holds production data and would be orphaned, ambiguity about which call site replaces which API, or **primary shipping targets that cannot run AdMob** without a product decision.

### `pubspec.yaml` - `game_kit` Git dependency

Under `dependencies:`, add:

```yaml
game_kit:
  git:
    url: https://github.com/GeeksJo/gameKit_package_flutter.git
    ref: development
```

Indent the `game_kit` block with **two spaces** under `dependencies:` so it matches your other packages (Pub uses two spaces per nesting level). For a **local** checkout (monorepo or offline), you may use `path: <PATH_TO_game_kit_DIRECTORY>` instead of `git:`.

Ensure the app’s **Dart SDK** constraint matches what `game_kit` requires (check the `environment.sdk` in the package you resolved). Run `flutter pub get`.

---

## `game_kit` package reference (embed in every migration)

Use this section when building `GameKitConfig`, wiring `main()`, and adjusting UI. No other document is required.

### Role of the package

`game_kit` provides **rules and persistence** for: **IAP** (remove ads + donations + consumables; donation totals automatic), **optional economy** (coin wallet, generic spend actions, daily-login streak, rewarded-ad faucet; credits shop catalog IAP itself), **optional shop UI** (`GameKitShopBody`, themed like settings), **AdMob** (interstitial / rewarded / banner - includes a working **`google_mobile_ads`** load/show integration **plus** cadence/cooldown/session gating), **in-app rating prompts**, **local notifications** (weekly reminders) **and FCM** (host `[DEFAULT]` Firebase, topic `all_users`, title + body), **cross-promo** catalog fetch/cache, **haptics** (`vibration` package via `DefaultHapticsClient` + persisted settings toggle + injectable client), **sounds** (bundled default cues + optional gating, per-event overrides, injectable audio client), **user preferences** (sound + vibration toggles persisted for settings), **force-update gate** (blocks outdated builds via Remote Config, branded blocking screen with direct store link), and **optional** reusable settings UI (`GameKitSettingsBody`) with **package-owned EN/AR** strings. The host app owns **navigation** and **game logic**; the package emits **signals** (streams, notifiers), persists **state**, loads/shows ads (or lets you drive your own GMA flow), and can render settings/dialogs, a shop, and a banner widget when you opt in. Helpers **`GameKitSignals`** and **`GameKitBannerSlot`** cut integration boilerplate.

### Initialization constraints

- Call **`GameKit.initialize(GameKitConfig)` exactly once** per process, after `WidgetsFlutterBinding.ensureInitialized()`, and **before** using any `GameKit.*` static modules. Calling **`initialize` again** without **`dispose`** in between is undefined - fix the host app if hot-restart or tests re-enter `main`.
- **`GameKitConfig.locale` is required** - it drives package-owned UI. **`GameKit.updateLocale`** normalizes to **`en`** or **`ar`**; other language codes fall back to **`en`**. Keep **`GameKit.updateLocale`** in sync when the user switches language.
- **`GameKitConfig.crossPromoSheetSeedColor` is required** - brand tint for **`showCrossPromotionBottomSheet`**; after init, **`GameKit.crossPromoSheetSeedColor`** holds the same value (usually match **`settingsUi.seedColor`** when you use **`GameKitSettingsUiConfig`**).
- If **`StorageConfig`** uses **Hive** or **dual SharedPreferences + Hive**, run **`Hive.initFlutter()`** and **open the Hive box** _before_ `GameKit.initialize`.
- After init: **`GameKit.ads`**, **`GameKit.iap`**, **`GameKit.rating`**, **`GameKit.notifications`**, **`GameKit.crossPromo`**, **`GameKit.share`**, **`GameKit.haptics`**, **`GameKit.sounds`**, **`GameKit.preferences`**. Optional **`GameKit.settingsUi`** is set when you pass **`settingsUi`** on the config.
- On teardown (tests, special shells), call **`await GameKit.dispose()`**; production apps often never dispose.
- Call **`GameKit.haptics`** and **`GameKit.sounds`** from domain code (same semantic methods). **`GameKit.preferences.soundsEnabled`** / **`vibrationsEnabled`** gate **`GameKit.sounds`** / **`GameKit.haptics`** automatically; optional **`HapticsConfig.isEnabled`** / **`SoundConfig.isEnabled`** on **`GameKitConfig`** add further AND gates when you need host-level control.

### Import

```dart
import 'package:game_kit/game_kit.dart';
```

This single import exposes config types, **`GameKit`**, modules, **`GameKitSignals`** / **`GameKitSignalsMixin`**, **`GameKitBannerSlot`**, **`GameKitSettingsBody`**, **`GameKitSettingsDialogs`**, **`GameKitLocalizations`**, **`GameKitSettingSection`**, **`GameKitSettingSectionWidget`**, **`GameKitSettingItem`**, palettes/dialog colors, cross-promo sheet, optional SharedPreferences premium migration helper, storage types, and related APIs.

### `GameKitConfig` - required and optional fields

| Field                          | Purpose                                                                                                                                                                                                              |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`locale`**                   | **`Locale`** for package-owned UI. Call **`GameKit.updateLocale`** when it changes.                                                                                                                                  |
| **`crossPromoSheetSeedColor`** | **`Color`** - tint for **`showCrossPromotionBottomSheet`**.                                                                                                                                                          |
| **`crossPromoAppIdentifier`**  | Optional string sent to the cross-promo API as `app_identifier`; omit if unused.                                                                                                                                     |
| **`settingsUi`**               | Optional **`GameKitSettingsUiConfig`** - styling for settings/dialogs (see below). Includes **Audio** section with sound-effects + vibration toggles unless **`hasAudio: false`**. Stored as **`GameKit.settingsUi`** after init. |
| **`shopUi`**                   | Optional **`GameKitShopUiConfig`** - shop colors, pack tones, section flags. Requires **`economy`**. Stored as **`GameKit.shopUi`**.                                                                                 |
| **`economy`**                  | Optional **`EconomyConfig`** - kit-owned coins, spend actions, daily login, rewarded faucet, shop catalog. Omit to keep coins host-owned.                                                                          |
| **`iap`**                      | **`IapConfig`** - remove-ads SKU, **three** donation SKUs (all required), optional `consumableGrantsByProductId` / `donationAmountsByProductId`.                                                                     |
| **`ads`**                      | **`AdsConfig`** - test vs prod AdMob units, cadence, cooldown, max per session.                                                                                                                                      |
| **`rating`**                   | **`RatingConfig`** - optional; defaults are documented under **Default rating policy** below.                                                                                                                        |
| **`notifications`**            | **`NotificationsConfig`** - Android channel + title/body; optional schedule overrides. FCM on by default (`enableFcm`, topic `all_users`); skipped if host `[DEFAULT]` Firebase is not initialized. |
| **`share`**                    | **`ShareConfig`** - `appName`, `androidPackageName`, optional `iosAppId`.                                                                                                                                            |
| **`storage`**                  | **`StorageConfig`** - `sharedPreferences`, `hive`, or `dualSharedPreferencesAndHive` + `hiveBox` when needed.                                                                                                        |
| **`clock`**                    | Optional **`DateTime Function()`** for tests.                                                                                                                                                                        |
| **`haptics`**                  | Optional **`HapticsConfig`** - default **`const HapticsConfig()`**; optional **`isEnabled`**.                                                                                                                        |
| **`hapticsClient`**            | Optional **`HapticsClient`** for tests or custom patterns; default **`DefaultHapticsClient`** (`vibration` package).                                                                                  |
| **`sound`**                    | Optional **`SoundConfig`** - default **`const SoundConfig()`** (bundled cues); `enabled`, `isEnabled`, `volume`, `respectSilentMode`, per-event **`overrides`**.                                                     |
| **`soundClient`**              | Optional **`SoundClient`** to swap the audio engine or no-op in tests; default **`DefaultSoundClient`** (`audioplayers`).                                                                                            |

Replace every placeholder ID, package name, and copy with the **host app’s** real values.

### Config skeletons (replace HOST\_\* with audited values)

**`IapConfig`** - all four SKU strings are **required**.

```dart
const iapConfig = IapConfig(
  removeAdsProductId: 'HOST_REMOVE_ADS_SKU',
  donationSmallProductId: 'HOST_DONATION_SMALL_SKU',
  donationMediumProductId: 'HOST_DONATION_MEDIUM_SKU',
  donationLargeProductId: 'HOST_DONATION_LARGE_SKU',
  consumableGrantsByProductId: {
    // Only SKUs the HOST still grants. Do not list shop catalog SKUs when EconomyConfig is set.
  },
  donationAmountsByProductId: {
    // 'HOST_DONATION_SMALL_SKU': 0.99,
  },
);
```

**`EconomyConfig` + shop catalog + shop UI** - omit `economy` entirely to keep coins host-owned. `const EconomyConfig()` is the word-game spec preset (100 coins, hint @ 20, solve @ 100, packs 500-50k, rewarded +40 / 5/day / 20 min).

```dart
const economyConfig = EconomyConfig(
  startingCoins: 100,
  spendActions: [
    EconomySpendAction(id: 'hint', coinCost: 20, startingFreeGrant: 2),
    EconomySpendAction(id: 'solve', coinCost: 100, startingFreeGrant: 1),
  ],
  catalog: ShopCatalogConfig(
    coinPacks: [
      ShopCoinPack(productId: 'HOST_COINS_HANDFUL', coins: 500, nameKey: 'handful'),
      ShopCoinPack(productId: 'HOST_COINS_PILE', coins: 1800, bonusPercent: 19, nameKey: 'pile'),
      ShopCoinPack(productId: 'HOST_COINS_SACK', coins: 3500, bonusPercent: 39, nameKey: 'sack', tagKey: 'bestValue'),
      ShopCoinPack(productId: 'HOST_COINS_BUCKET', coins: 8000, bonusPercent: 58, nameKey: 'bucket'),
      ShopCoinPack(productId: 'HOST_COINS_CHEST', coins: 18000, bonusPercent: 78, nameKey: 'chest'),
      ShopCoinPack(productId: 'HOST_COINS_VAULT', coins: 50000, bonusPercent: 98, nameKey: 'vault'),
    ],
  ),
);

const shopUi = GameKitShopUiConfig(
  seedColor: Color(0xFF7C5CFC), // map to host brand
  surfaceColor: Color(0xFFF6EFE4),
  titleColor: Color(0xFF1A2D42),
  subtitleColor: Color(0xFF64748B),
  sectionCardAppearance: GameKitSectionCardAppearance.opaqueLight,
  hasFreeCoins: true,
  hasRemoveAds: true,
  hasCoinPacks: true,
  hasBundles: false,
  hasInventoryPacks: false,
  // Omit art to use bundled PNGs (GameKitShopAssets). Override per game:
  // coinArt: ShopArt.asset('assets/icons/coin.png'),
  // actionArt: {'hint': ShopArt.asset('assets/icons/hint_bulb.png')},
);
```

Call **`migrateLegacyEconomyForGameKit(prefs: prefs, coinsKey: 'HOST_COINS_KEY', inventoryKeys: {'hint': 'HOST_HINT_KEY'})`** **before** **`GameKit.initialize`**.

**`AdsConfig`** - use **`AdUnitEnvironment.test`** in debug / CI and **`prod`** in release when ready; **`prodLevelPlayUnitIds`** is still required in code but **ignored** when environment is **`test`**. In **`prod`**, An unconfigured **prod** unit id stays **empty** and the controller skips the load; it does **not** fall back to a demo id, because LevelPlay demo inventory would serve real users and earn nothing. **`requestNonPersonalizedAds`** defaults to **`false`** (better fill); set **`true`** only when your consent flow requires non-personalized ads. **`showPromoInterstitial: true`** makes `runInterstitialCycle` show a remote house-ad fullscreen on every other interstitial slot (off by default; leave off on the promoted app). See **`docs/PROMO_ADS.md`**.

```dart
import 'package:flutter/foundation.dart';

final adsConfig = AdsConfig(
  adEnvironment:
      kReleaseMode ? AdUnitEnvironment.prod : AdUnitEnvironment.test,
  prodLevelPlayUnitIds: const LevelPlayProdUnitIds(
    interstitialAndroid: 'HOST_…',
    interstitialIos: 'HOST_…',
    bannerAndroid: 'HOST_…',
    bannerIos: 'HOST_…',
    rewardedAndroid: 'HOST_…', // leave '' until live rewarded units exist
    rewardedIos: 'HOST_…',
  ),
  interstitialEveryNLevels: 2, // override from host if different
  interstitialCooldownSeconds: 40,
  interstitialMaxPerSession: 8, // or null for unlimited
  // requestNonPersonalizedAds: false, // default; opt in only for NPA/consent
);
```

**`RatingConfig`** - all fields are optional; constructor defaults match the package policy.

```dart
const ratingConfig = RatingConfig(
  minLevel: 4,
  minSession: 2,
  maxLifetime: 3,
  minDaysBetween: 4,
  minSecondsAfterAd: 60,
  maxDismissals: 3,
);
```

**`NotificationsConfig`** - **`days`** are **Dart weekday integers** (`DateTime.monday`, …). Package defaults: Mon/Wed/Fri, hour **19**, install delay **48** h, stop after **3** ignores.

```dart
const notificationsConfig = NotificationsConfig(
  androidChannelId: 'HOST_CHANNEL_ID',
  androidChannelName: 'HOST_CHANNEL_NAME',
  androidChannelDescription: 'HOST_CHANNEL_DESC',
  notificationTitle: 'HOST_TITLE',
  notificationBody: 'HOST_BODY',
  // days: [DateTime.monday, DateTime.wednesday, DateTime.friday],
  // hour: 19,
  // installDelayHours: 48,
  // stopAfterIgnoredCount: 3,
  // enableFcm: true, // default; set false to opt out
  // fcmTopics: ['all_users'],
);
```

**`ShareConfig`**

```dart
const shareConfig = ShareConfig(
  appName: 'HOST_APP_NAME',
  androidPackageName: 'HOST_ANDROID_PACKAGE',
  iosAppId: 'HOST_APP_STORE_NUMERIC_ID', // optional but needed for iOS store URL in share
);
```

**`StorageConfig`**

```dart
// Prefs-only (default backend)
const storageConfig = StorageConfig();

// Hive - open box before GameKit.initialize
final storageConfig = StorageConfig(
  backend: GameKitStoreBackend.hive,
  hiveBox: hostHiveBox,
);

// Dual - reads try prefs first, writes go to both
final storageConfig = StorageConfig(
  backend: GameKitStoreBackend.dualSharedPreferencesAndHive,
  hiveBox: hostHiveBox,
);
```

**`ForceUpdateConfig`** - branding for the blocking update screen. **Not** part of `GameKitConfig`; used separately with `ForceUpdateGate`. The default illustration is the bundled rocket at **`kGameKitForceUpdateIllustrationAssetPath`** (`assets/images/startup.png`).

```dart
const forceUpdateConfig = ForceUpdateConfig(
  iosAppId: 'HOST_APP_STORE_NUMERIC_ID',
  androidPackageName: 'HOST_ANDROID_PACKAGE',
  currentVersion: '1.2.0', // installed build; compared to RC min_required_version
  backgroundColor: Color(0xFF151F23),
  textColor: Colors.white,
  buttonColor: Color(0xFF00BFA6),      // outlined button border
  buttonTextColor: Colors.white,
  // illustrationAsset: 'assets/images/custom_rocket.png', // optional host override
);
```

**`ForceUpdateStrings`** - built-in factories for EN and AR (title, message, button label); or supply a custom builder.

```dart
// Locale-aware resolver (pass as the `strings` argument to ForceUpdateGate):
ForceUpdateStrings forceUpdateStrings(BuildContext context) {
  return GameKit.locale.languageCode == 'ar'
      ? ForceUpdateStrings.arabic()
      : ForceUpdateStrings.english();
}
```

### Persistence and key namespaces

- Each module persists under a **logical scope** (e.g. `iap`, `ads`, `rating`, `preferences`). Implementations prefix keys (e.g. `game_kit.iap.*`, `game_kit.preferences.soundsEnabled`) - you normally **do not** read these raw keys from the host app; use **`GameKit.iap`**, **`GameKit.preferences`**, stores API in tests, or documented migration helpers.
- **Dual backend:** reads prefer **SharedPreferences**, then **Hive**; writes and deletes go to **both**. Do not assume a key exists in only one side after dual is enabled.
- Avoid **duplicating** the same business flag in host prefs **and** trusting it alongside `GameKit.iap.adsRemoved` - pick one source of truth after migration (the module).

### Styling `settingsUi` (optional but recommended for a native look)

Map **`GameKitSettingsUiConfig`** and **`GameKitSettingsDialogUiConfig`** from the **same** theme/tokens as the rest of the app:

| Kit field                              | Typical project source                                                                                                                                                                                                                             |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`seedColor`**                        | Primary / brand accent (`ThemeData.colorScheme.primary` or your primary token).                                                                                                                                                                    |
| **`iconColor`**                        | Optional; often same as or a variant of **`seedColor`**.                                                                                                                                                                                           |
| **`titleColor`** / **`subtitleColor`** | e.g. `onSurface` / `onSurfaceVariant`. With **`sectionCardAppearance: frosted`** (default), cards are translucent and default row text is **light** unless overridden; **`opaqueLight`** suits solid white cards + darker text.                    |
| **`sectionCardAppearance`**            | **`frosted`** (default): translucent cards. **`opaqueLight`**: solid white cards + dividers. On frosted cards, cross-promo **Open** uses a high-contrast chip; opaque keeps a seed-tinted chip (`GameKitSettingsPalette.usesFrostedSectionCards`). |
| **`fontFamily`**                       | Match **`ThemeData`** / app font.                                                                                                                                                                                                                  |
| **`backgroundDecoration`**             | Optional; use **`null`** if the host **`Scaffold`** already provides the backdrop.                                                                                                                                                                 |
| **`dialog`**                           | Map dark sheets and **`AlertDialog`** colors to your modal surfaces (`darkSurfaceColor`, `darkBorderColor`, `darkTitleColor`, `darkBodyColor`, `alertSurfaceColor`, etc.), plus **`confirmButtonOnRightInRtl`** (default **`false`**).             |

**RTL / Arabic:** kit dialogs apply `Directionality` from the active `locale` (Arabic mirrors automatically; the price chip stays LTR). The **remove-ads confirm** dialog uses `[Cancel, Confirm]`, which under RTL mirrors to **Cancel on the right, Confirm on the left** (standard Material). Set **`GameKitSettingsDialogUiConfig(confirmButtonOnRightInRtl: true)`** to pin **Confirm to the visual right in RTL**.

Use **`gameKitRemoveAdsDialogColors(uiConfig)`** (or **`GameKitSettingsDialogColors.fromConfig`**) for remove-ads or other dialogs **outside** the settings route so they match. **`GameKitSettingsBody(uiConfig: …)`** can override per widget without re-running **`GameKit.initialize`**. Prefer **`gameKitRunRemoveAdsPurchaseFlow`** + **`GameKitRemoveAdsIconButton`** for the same confirmation dialog and purchase path as settings (see README).

### Defaults: contact and cross-promo

- **`GameKitDefaultContact`** - built-in support email and website. If you omit **`feedbackMailto`** / **`websiteUrl`** on **`GameKitSettingsUiConfig`**, **`GameKitSettingsBody`** uses these for Contact rows. Override only when the product needs different endpoints.
- **Contact email row:** the kit opens **`mailto:`** via **`url_launcher`** (`LaunchMode.externalApplication`, then **`platformDefault`**). On **Android 11+**, the host app **must** declare **`mailto`** visibility in **`AndroidManifest.xml`** - otherwise the system cannot resolve an email handler, **`launchUrl`** returns false, and the user sees the kit **“can’t open app”** snackbar. Use the **`<queries>`** snippet under **Platform checklist → Android** below (same rules apply to any custom **`mailto:`** code in the host).
- **`showCrossPromo`** defaults to **`true`** (Support section includes **Other games**). Set **`showCrossPromo: false`** to hide.
- **`hasAudio`** defaults to **`true`** (top **Audio** section with **Sound effects** + **Vibration** switches). Set **`hasAudio: false`** when the host supplies its own mute UI and optionally wires **`SoundConfig.isEnabled`** / **`HapticsConfig.isEnabled`**.
- **`crossPromoSheetSeedColor`** on **`GameKitConfig`** should usually match **`settingsUi.seedColor`**; **`showCrossPromotionBottomSheet`** does **not** take a color argument.

### Typical bootstrap order (`main` / app startup)

1. `WidgetsFlutterBinding.ensureInitialized();`
2. Optional: `Hive.initFlutter()` + open box(es) if storage uses Hive/dual.
3. Optional: load persisted **locale** so **`GameKitConfig.locale`** matches the first **`MaterialApp`** frame.
4. **FCM:** `await Firebase.initializeApp();` (host `[DEFAULT]`) then `FirebaseMessaging.onBackgroundMessage(gameKitFirebaseMessagingBackgroundHandler);` - **before** `runApp`. Skip if the host has no Firebase; the kit then no-ops FCM.
5. Optional: other DI / setup if config needs it.
6. `await GameKit.initialize(gameKitConfig);` - this also runs **`LevelPlay.init`** and **`GameKit.ads.preloadAds()`** (non-blocking warm-up). **Do not** duplicate ad SDK init in the host.
7. After init: **`await GameKit.iap.loadStoreProducts()`** so settings and shop cash prices load from the store by product id (shop catalog SKUs are registered at initialize).
8. SharedPreferences legacy premium keys (`ads_removed`, `total_donations`) are migrated inside **`GameKit.initialize`**; custom key names require calling **`migratePremiumLegacySharedPreferencesForGameKitIap`** before init (see README **Legacy premium storage**). Hive-only legacy premium data must be migrated by the host.
9. `runApp(...)`

Do **not** use `GameKit.ads` (etc.) before step 6 completes.

### Recommended order for Phase 3 (call-site migration)

1. **Bootstrap** - `GameKitConfig` + **`GameKit.initialize`** + optional **`loadStoreProducts`**.
2. **IAP UI** - bind remove-ads / restore / donation actions to **`GameKit.iap`**; listen to **`adsRemoved`** and purchase streams for consumables you grant in the host.
3. **Ads** - subscribe once (prefer **`GameKitSignals`**) to **`onShouldShowInterstitial`** (handle with **`runInterstitialCycle()`**) and optionally **`onShouldShowRemoveAdsTooltip`**; use **`GameKitBannerSlot`** for banners. If you keep a custom GMA flow, honor the **`adClosed`** contract (next subsection).
4. **Rating** - subscribe to soft-prompt / feedback streams; wire **`levelSucceeded`** / **`levelFailed`** / **`respond`**.
5. **Notifications** - wire **`onFirstDailyCompletion`** and **`markPlayedToday`**.
6. **Cross-promo** - entry points + **`showCrossPromotionBottomSheet`**; **`markGamesViewed`** when appropriate.
7. **Share** - **`shareApp`**.
8. **Haptics + sounds** - replace direct **`HapticFeedback`** and any host SFX player where semantics match (`validAction` / `invalidAction` / `milestoneSuccess` / `lightTap`).
9. **Settings** - integrate **`GameKitSettingsBody`** last if used, so **`GameKit.settingsUi`** and l10n are already correct.
10. **Economy + shop (optional)** - `migrateLegacyEconomyForGameKit` before init; pass **`economy`** + **`shopUi`**; replace wallet/hint call sites with **`GameKit.economy`**; compose **`GameKitShopBody`**. Delete the host wallet only after cutover.
11. **Force update (optional)** - wrap the app root with **`ForceUpdateGate`**; implement **`ForceUpdateRemoteConfig`**; wire **`ForceUpdateStrings`** to `GameKit.locale`; fetch + activate Remote Config before mounting.
12. **App moved (optional)** - wrap the app root with **`AppMovedGate`** when this binary is a last update on an old package id; publish **`show_app_moved`** plus **`new_*_store_url`**.

### Interstitial / ads behavior (summary)

The package ships a **`google_mobile_ads`** integration that loads/shows ads; prefer its helpers over a custom GMA wrapper.

- **`GameKit.initialize`** calls **`AdsModule.ensureNetworkInitialized()`** (`LevelPlay.init`, via `AdsLevelPlayController`) and then **`preloadAds()`** to warm the first interstitial/rewarded. Host apps must **not** initialise an ad SDK separately - remove any legacy host init when migrating.
- **`AdsConfig.requestNonPersonalizedAds`** defaults to **`false`**. Only set **`true`** when privacy/consent requires non-personalized requests (NPA often reduces fill).
- An unconfigured **prod** unit id stays **empty** and the controller skips the load; it does **not** fall back to a demo id, because LevelPlay demo inventory would serve real users and earn nothing.
- Call **`levelCompleted(failed: false)`** on success - the package increments a persisted **levels completed** counter and may emit **`onShouldShowInterstitial`** every **`interstitialEveryNLevels`‑th** success. **`failed: true`** on loss/abandon **does not** bump that counter and **does not** trigger the cadence signal on that call.
- **Recommended:** handle **`onShouldShowInterstitial`** by calling **`await GameKit.ads.runInterstitialCycle()`**. It performs **`load → show → adClosed()`** as one call, enforces premium / session cap / cooldown, and **always** calls **`adClosed()`** so **rating cooldown** and the **remove-ads tooltip** stay correct. Cooldown starts when the ad **closes**.
- **Manual path (only if you drive your own GMA flow):** **`showInterstitial` does not call `adClosed`** - you **must** call **`await GameKit.ads.adClosed()`** after the interstitial flow **ends** (user closed, load failed, or no fill). **`adClosed`** emits **`AdClosedEvent`**.

```dart
// Recommended - one safe call:
GameKit.ads.onShouldShowInterstitial.listen((_) {
  GameKit.ads.runInterstitialCycle();
});

// Manual equivalent (adClosed must always run):
await GameKit.ads.loadInterstitial();
final shown = await GameKit.ads.showInterstitial();
await GameKit.ads.adClosed();
```

- Wire signals with **`GameKitSignals`** / **`GameKitSignalsMixin`** (one place to subscribe; auto-cancel) instead of manual `StreamSubscription`s.
- **Banner:** use **`GameKitBannerSlot`** (self-loading, hides when ad-free, self-disposing, and collapsed to zero height until the network reports fill). Low-level **`loadBanner`** + **`bannersEnabled`** remain available if you render your own widget - honour `AdBannerHandle.isFilled` or you will reserve a blank strip.
- **Rewarded (must-watch):** **`canShowRewarded(RewardedReason.hint | extraMoves | skip)`** is the eligibility gate; **`showRewarded()`** loads on demand and returns true only when the reward was earned. **`isRewardedReady`** reflects load state. Rewarded does **not** share the interstitial cadence counter; **remove-ads IAP** does **not** disable rewarded.
- **Unlock / coin / refill grants:** **`requestAdGrant(placement: …, cooldownGroup: …)`** - connectivity probe, then rewarded (with a 4s load wait) → interstitial → free grant capped per group. A rewarded shown and closed early **stops** the chain. Grant only when **`outcome.isGranted`**. There are now **three** non-granting outcomes and each needs its own message: **`offline`** ("Connect to the internet to continue", no grant), **`skipped`** (the player closed the rewarded video early - no grant, say the ad did not finish), and **`noneAvailable`** (no fill *and* the free grant is on cooldown - "try again later", optionally with `GameKit.ads.freeGrantAvailableAt(group)`). A single "you are offline" message for all three tells the player something untrue. On **`grantedFree`** it is fine to name it ("No ad available, here is your reward anyway") - the per-group 1h cap is what stops that copy from teaching players to farm it. Pass a **`cooldownGroup`**: `currency` for coins / unlocks / rentals, `functional` for heart / hint / revive. Check **`shouldSkipAdGrantOffer`** before any watch-ad popup. Hard rules in **`docs/AD_GRANT.md`**.

### IAP surface (common calls)

- **`purchaseRemoveAds()`**, **`purchaseDonation(DonationTier)`**, **`purchaseStoreProduct(productId)`**, **`purchaseProduct(productId, consumable: …)`**, **`restore()`** / **`restorePurchases()`**.
- **`adsRemoved`** - **`ValueNotifier<bool>`**; also drives **`bannersEnabled`** inside **`AdsModule`**.
- **`onPurchaseComplete`** / **`onPurchaseRestored`** - **`Stream<String>`** of **product id**; grant **`consumableGrantsByProductId`** quantities here (remove-ads is handled inside the module). Also: **`onPurchaseError`** (`Stream<String>`), **`onPurchaseStarted`** / **`onPurchaseCanceled`** (`Stream<void>`), **`onRestoreComplete`** (`Stream<bool>`).
- **Donation totals are tracked automatically** on each successful donation purchase; read **`getTotalDonations()`** for display only (there is no public `addDonation`). Provide **`IapConfig.donationAmountsByProductId`** for exact totals before store prices load.
- Prefetch: **`loadStoreProducts()`** loads **`IapModule.queriedProductIds`** (IAP config + shop catalog product ids registered at initialize). Shop cash prices always come from **`getFormattedPrice(productId)`**, never hardcoded.
- **`DonationTier`** is **`small` / `medium` / `large`** - map to your three SKUs in config.

### `MaterialApp` - localizations (if you use kit settings or dialogs)

- Add **`GameKitLocalizations.delegate`** to **`localizationsDelegates`**.
- Include **`Locale('en')`** and **`Locale('ar')`** in **`supportedLocales`** if you ship both.
- On language change: **`GameKit.updateLocale(newLocale)`** so kit UI matches **`MaterialApp.locale`**.

### Settings screen (optional)

- Pass **`settingsUi`** in **`GameKitConfig`** (or **`GameKitSettingsBody.uiConfig`**). Compose **`GameKitSettingsBody`** in a **`ListView`** with **`shrinkWrap: true`** and **`physics: NeverScrollableScrollPhysics()`** when nested in a parent scroll view.
- **Sound effects + vibration:** **`GameKitSettingsBody`** shows an **Audio** section (first card) with **Sound effects** and **Vibration** switches. Toggling updates **`GameKit.preferences.soundsEnabled`** / **`vibrationsEnabled`** (persisted; survives restart) and gates **`GameKit.sounds`** / **`GameKit.haptics`**. Turning sound **on** plays a short tap cue; turning vibration **on** fires a short haptic tap as confirmation. Set **`GameKitSettingsUiConfig(hasAudio: false)`** to hide when the host keeps custom mute rows.
- **Contact → Email:** ensure Android **`SENDTO` / `mailto`** **`<queries>`** is present (see **Platform checklist**) so tapping the email row opens the user’s mail client when one is installed; otherwise the kit shows an error snackbar.
- Place other host-only rows (profile, haptics-only gate, language, legal) above/below the kit body. **Do not** duplicate sound/vibration toggles if you use the kit **Audio** section.
- For a custom block with the same card chrome: **`GameKitSettingSectionWidget`** with **`palette: GameKitSettingsPalette.fromUiConfig(GameKit.settingsUi!)`** when **`settingsUi`** was set on init; or **`GameKitSettingSection`** with **`GameKitSettingItem`** children.
- Remove-ads outside the list: **`GameKitRemoveAdsIconButton`** ( **`imagePath` / `width` / `height`** only) or **`gameKitRunRemoveAdsPurchaseFlow`** - with **`waitForStoreOutcome: true`** and no callbacks, success/error use the same kit **`AlertDialog`**s as **`GameKitSettingsBody`**; **`gameKitLocalizedPurchaseErrorMessageOrNull`** matches settings IAP error mapping. Use **`gameKitRunRemoveAdsPurchaseFlow`** with callbacks for custom feedback.

### Default rating policy (package behavior)

Unless **`RatingConfig`** overrides them:

- Prompt only when **level ≥ minLevel** (default **4**) and **session count ≥ minSession** (default **2**). **`GameKit.initialize`** registers the first session launch.
- **Not** on the same **local calendar day** as the last prompt, and at least **`minDaysBetween`** whole days since (default **4**).
- **Not** within **`minSecondsAfterAd`** seconds after the last interstitial close (default **60**); **`adClosed()`** feeds this.
- **`level`** passed to **`levelSucceeded`** must be the **1-based level number** your game shows the player (same as pre-migration if the host used “level 1” for first stage).
- After a **failed** level, **not** on the **next** success only - call **`levelFailed()`** on loss/abandon; the following **`levelSucceeded`** clears that without showing a prompt.
- **Positive** response → permanent stop; **`maxDismissals`** dismissals → permanent stop; at most **`maxLifetime`** soft prompts over the install (default **3**).

### Notifications

- **`onFirstDailyCompletion()`** - requests permission and (re)schedules when your UX says the first daily milestone was hit. Also requests FCM permission and subscribes to **`all_users`**.
- **`markPlayedToday()`** - when the player actually played today (your definition).
- **FCM receiver:** uses the host **`[DEFAULT]`** Firebase app, not the named `game_kit` app. Foreground: kit shows the Firebase **title + body** as a local notification. Background / terminated: the OS shows them. Tap is a normal app launch (no data payload / deeplink). Register **`gameKitFirebaseMessagingBackgroundHandler`** in `main()` as in **Typical bootstrap order**. Send campaigns from the host Firebase Console to topic **`all_users`** as a **notification** message (title and message fields), not data-only. Set **`enableFcm: false`** to opt out. Tests pass **`GameKitConfig.fcmClient`** (`FakeFcmClient`).

### Force update

The force-update gate is **standalone** - it does not integrate with `GameKit.initialize` and has no module on `GameKit.*`. Wire it at the widget level.

**How it works:**

1. `ForceUpdateGate` mounts as the root of your widget tree (wrap `MaterialApp.home` or the router entry point).
2. On first mount and on every `AppLifecycleState.resumed` event, it calls `ForceUpdateService.evaluate()`.
3. `evaluate()` compares `ForceUpdateConfig.currentVersion` against `min_required_version` from your Remote Config bridge.
4. If the current version is lower, `ForceUpdateScreen` is shown - centered rocket illustration, title, description, and an outlined **Update Now** button. `PopScope(canPop: false)` blocks all back navigation; the button opens the store URL.
5. While the check is in progress, a loading state is shown (same `backgroundColor`, bundled illustration, spinner tinted with `buttonColor`).
6. If `ForceUpdateRemoteConfig.isReady` is `false`, the gate passes through and shows the child. The check runs again on next resume.

**Classes exported from `package:game_kit/game_kit.dart`:**

| Class / type                               | Role                                                                                                                                                           |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ForceUpdateGate`                          | Widget; wraps your app root; drives check + UI swap on mount and resume                                                                                        |
| `ForceUpdateService`                       | Evaluates current vs. minimum version; call `evaluate()`                                                                                                       |
| `ForceUpdateStatus`                        | Result of `evaluate()` - `isRequired`, `currentVersion`, `minimumVersion`, `storeUrl`                                                                          |
| `ForceUpdateConfig`                        | Branding: `backgroundColor`, `textColor`, `buttonColor`, `buttonTextColor`, optional `illustrationAsset`, `currentVersion`, package IDs for store URL fallback |
| `ForceUpdateStrings`                       | Localized title, message, and button label; use `.english()` / `.arabic()` factories or build custom                                                           |
| `kGameKitForceUpdateIllustrationAssetPath` | Default bundled rocket illustration path (`assets/images/startup.png`)                                                                                         |
| `ForceUpdateRemoteConfig`                  | Abstract interface the host implements (bridge to Firebase RC or equivalent)                                                                                   |
| `ForceUpdateRemoteConfigKeys`              | Constants: `min_required_version`, `android_store_url`, `ios_store_url`                                                                                        |

**Remote Config keys** (from `ForceUpdateRemoteConfigKeys`):

| Key                    | Type   | Purpose                                |
| ---------------------- | ------ | -------------------------------------- |
| `min_required_version` | String | Semver (e.g. `1.3.0`); empty = no gate |
| `android_store_url`    | String | Optional Play Store URL override       |
| `ios_store_url`        | String | Optional App Store URL override        |

When store URLs are empty in RC, `ForceUpdateService` builds them automatically from `ForceUpdateConfig.androidPackageName` / `iosAppId`.

**Wiring `ForceUpdateGate`:**

```dart
// In your widget tree, wrapping MaterialApp.home or a shell route:
ForceUpdateGate(
  config: forceUpdateConfig,
  strings: (context) => GameKit.locale.languageCode == 'ar'
      ? ForceUpdateStrings.arabic()
      : ForceUpdateStrings.english(),
  service: ForceUpdateService(
    config: forceUpdateConfig,
    remoteConfig: MyFirebaseRemoteConfigAdapter(),
  ),
  // illustration: Image.asset('assets/images/custom.png', height: 220), // optional
  child: const MyHomePage(),
)
```

**Implementing `ForceUpdateRemoteConfig` (Firebase example):**

```dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:game_kit/game_kit.dart';

class FirebaseForceUpdateRemoteConfig implements ForceUpdateRemoteConfig {
  final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  @override
  bool get isReady => _rc.lastFetchStatus == RemoteConfigFetchStatus.success;

  @override
  String getString(String key) => _rc.getString(key);
}
```

Fetch and activate Remote Config **before** building the gate when possible, so the first render is authoritative:

```dart
await FirebaseRemoteConfig.instance.fetchAndActivate();
// then build the widget tree with ForceUpdateGate
```

If RC cannot be fetched before the first frame (cold start, no network), the gate lets the user through and re-evaluates on the next app resume.

### App moved

The app-moved gate is **standalone** - same adapter as force update, different RC keys.

**How it works:**

1. `AppMovedGate` mounts at the app root (outside splash / kit-ready if the host has one).
2. On mount, resume, and optional `recheck` listenable, it calls `AppMovedService.evaluate()`.
3. The gate blocks only when RC `show_app_moved` is `true`/`1`.
4. `AppMovedScreen` is a branded card (host colors + optional logo) with a download CTA. `PopScope(canPop: false)` blocks back navigation.
5. If RC is not ready, the gate passes through (fail open).

**Remote Config keys** (from `AppMovedRemoteConfigKeys`):

| Key                      | Type    | Purpose                                              |
| ------------------------ | ------- | ---------------------------------------------------- |
| `show_app_moved`         | Boolean | `true` shows the move screen on the old listing      |
| `new_android_store_url`  | String  | Play URL for the **successor** listing               |
| `new_ios_store_url`      | String  | App Store URL for the **successor** listing          |

Download URLs come only from those RC keys. Empty URLs still show the screen; the button reports unavailable.

### Cross-promo

- **`hasPromoCatalog`**, **`getGames()`**, **`hasNewGame`**, **`hasNewGameChanges`**, **`markGamesViewed()`**.
- **`await showCrossPromotionBottomSheet(context)`** - tint from **`GameKit.crossPromoSheetSeedColor`** only.

### Share

- **`GameKit.share.shareApp(context: context, sharePositionOrigin: …)`** - **`sharePositionOrigin`** optional; iPad popover is handled when omitted.

### Haptics

- **`GameKit.haptics.validAction()`**, **`invalidAction()`**, **`milestoneSuccess()`**, **`lightTap()`**, **`lightImpact()`**, **`mediumImpact()`**, **`heavyImpact()`** - Vibration cues via **`DefaultHapticsClient`**.
- Configure via **`HapticsConfig`**: `enabled`, optional `isEnabled` gate (AND-ed with **`GameKit.preferences.vibrationsEnabled`**).
- **Settings mute:** **`GameKit.preferences.setVibrationsEnabled(bool)`** or the kit **Vibration** switch in **`GameKitSettingsBody`**.
- Older aliases may still exist one release.

### Sounds

- **`GameKit.sounds.validAction()`**, **`invalidAction()`**, **`milestoneSuccess()`**, **`lightTap()`**, **`countdownTick()`**, **`go()`** - one-shot cues; fire-and-forget.
- **`startCountdownUrgency()`** / **`stopCountdownUrgency()`** - sustained final-seconds bed (`countdown.wav`). Always call **stop** on early exit (correct answer, pause, timeout, dispose).
- Configure via **`SoundConfig`**: `enabled`, optional `isEnabled` gate (AND-ed with **`GameKit.preferences.soundsEnabled`**), `volume`, `respectSilentMode`, and **`overrides`** (`GameKitSound.bundled` / `.asset` / `.none`). Bundled cue file names live in the package's `assets/sounds/`.
- **Settings mute:** **`GameKit.preferences`** (`PreferencesModule`) persists **`soundsEnabled`** (default **`true`**) using the configured **`StorageConfig`**. Read **`GameKit.preferences.soundsEnabled`** (`ValueNotifier<bool>`) or call **`await GameKit.preferences.setSoundsEnabled(bool)`** from code. The kit settings **Sound effects** switch uses this automatically - no host wiring required when **`GameKitSettingsBody`** is used with **`hasAudio: true`** (default).

### Migrating host countdown / GO sounds to bundled cues

If the host previously mapped **`lightTap` → tick.wav** or **`milestoneSuccess` → go.wav** via **`SoundConfig.overrides`**, or played host assets with a local **`AudioPlayer`**:

1. **Remove overrides** for tick/go - use bundled defaults (or omit **`SoundConfig.overrides`** entirely).
2. **Replace call sites:**
   - Pre-start beats: **`GameKit.sounds.countdownTick()`** (not **`lightTap()`**).
   - Answer-phase GO: **`GameKit.sounds.go()`** (not **`milestoneSuccess()`** sound).
   - Win / scoreboard: **`GameKit.haptics.milestoneSuccess()`** only, or add **`GameKit.sounds.milestoneSuccess()`** when you want **`milestone.wav`** - never use **`go()`** here.
   - UI buttons: keep **`GameKit.sounds.lightTap()`** (**`tap.wav`**).
3. **Answer-timer urgency:** when total duration **> 5s** and remaining **≤ 3s**, call **`startCountdownUrgency()`** once; **`stopCountdownUrgency()`** on done, timeout, pause, and dispose. When duration **≤ 5s**, do **not** start urgency (default rounds stay quiet except **`go`** + semantic cues).
4. **Delete** duplicate host **`assets/sounds/`** files and remove the folder from **`pubspec.yaml`** if empty.
5. **Smoke-test:** 5s timer (no urgency), 6s+ timer (urgency last 3s), 3s timer (no urgency), pause/resume, early answer stops audio.

### Stream and listener hygiene

- Subscribe to **`Stream`s** (ads, rating, IAP) in a **`StatefulWidget` `initState`**, a **`Bloc`/Cubit** `start` method, or a root **`WidgetsBinding`** observer - **one** logical subscription per stream for the app lifetime where possible.
- **Cancel** `StreamSubscription`s in **`dispose`** / **`close`** to avoid duplicates after navigation or hot reload quirks in tests.

### Platform checklist

- **Android:** `INTERNET`, billing, `POST_NOTIFICATIONS` (API 33+), notification channel ids matching **`NotificationsConfig`**, host `google-services.json` for FCM, AdMob **`applicationId`** in manifest per **`google_mobile_ads`**.
- **Android - `mailto:` / Contact email (`GameKitSettingsBody` or host `url_launcher`):** From API **30** (Android 11), package visibility limits which intents your app can **query**. Without a matching **`<queries>`** declaration, **`canLaunchUrl`** / **`launchUrl`** for **`mailto:`** may fail and **`UrlLauncher`** logs that the component name is **null**. Merge this **`intent`** into the existing **`<queries>`** block in **`android/app/src/main/AndroidManifest.xml`** (and flavor manifests if they override queries - keep them consistent):

```xml
<intent>
    <action android:name="android.intent.action.SENDTO" />
    <data android:scheme="mailto" />
</intent>
```

After adding or changing **`<queries>`**, do a **clean reinstall** on the device so the merged manifest is applied.

- **iOS:** StoreKit, App Store ID for share links, notification usage description if you request permission, Push Notifications capability, Background Modes → Remote notifications, APNs on the **host** Firebase project (not the named `game_kit` app), AdMob **`GADApplicationIdentifier`** (required while `google_mobile_ads` is linked for UMP consent) and **`SKAdNetworkItems`** from the LevelPlay network list in **`Info.plist`**, plus the network adapter pods in the `Podfile`. See **`docs/LEVELPLAY_SETUP.md`**.

### Tests

- Skip **`GameKit.initialize`** in some tests, or init with **`AdUnitEnvironment.test`**, **in-memory/fake** storage from **`GameKitStorage.inMemory('module')`**, and optional fake **`clock`** / **`hapticsClient`** / **`soundClient`** (a no-op `SoundClient` keeps unit tests off the audio plugin).
- Call **`await GameKit.dispose()`** in **`tearDown`** if you initialized.

### Troubleshooting (common mistakes)

| Symptom                                                                              | Likely cause                                                                                                                                    | Fix                                                                                                                                                                       |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rating never appears                                                                 | **`level`** too low, session count, same calendar day, or **`adClosed`** not called after ads                                                   | Verify **`levelSucceeded`** level, call **`adClosed`** after every interstitial flow, read **Default rating policy**                                                      |
| Rating right after a bad level                                                       | Missing **`levelFailed`**                                                                                                                       | Call **`levelFailed`** on loss/abandon                                                                                                                                    |
| Interstitial spam or none                                                            | Wrong **`interstitialEveryNLevels`** or cadence not tied to **`levelCompleted`**                                                                | Port host cadence into **`AdsConfig`**; ensure **`levelCompleted(false)`** on every win                                                                                   |
| Cooldown seems ignored                                                               | **`adClosed`** not paired with show attempts                                                                                                    | Always **`adClosed`** when the interstitial **flow** ends                                                                                                                 |
| Banners/interstitials never load in release                                          | Host still owns ads, prod unit ids empty/wrong, or **`requestNonPersonalizedAds: true`** with low fill                                          | Use **`GameKit.ads`** only; set real **`prodLevelPlayUnitIds`**; **check the network adapters are in the host Gradle / Podfile** and that every ad unit has a mediation group (`docs/LEVELPLAY_SETUP.md`)               |
| `Ad failed to load : 3` (NO_FILL) with real units                                    | AdMob serving / inventory, not missing package init                                                                                             | Confirm debug test units fill; check AdMob linking, geo, and unit approval; sample units in release prove wiring is correct                                               |
| Store UI shows “Price unavailable”                                                   | No **`loadStoreProducts`** before building price labels                                                                                         | Prefetch after init                                                                                                                                                       |
| Duplicate notification channels                                                      | Changed **`androidChannelId`** vs shipped app                                                                                                   | Keep live channel id; document intentional migration                                                                                                                      |
| Contact email does nothing / “can’t open”; log `component name for mailto:… is null` | Missing Android 11+ **`<queries>`** for **`mailto`**                                                                                            | Add **`SENDTO`** + **`mailto`** **`intent`** under **`<queries>`** (see **Platform checklist**); clean reinstall                                                          |
| Hive / “box not open” crash                                                          | **`GameKit.initialize`** before **`Hive.openBox`**                                                                                              | Open box before init                                                                                                                                                      |
| Force-update screen never shows                                                      | `ForceUpdateRemoteConfig.isReady` returns `false` (RC not yet fetched/activated), or `min_required_version` is empty / at/below current version | Ensure RC is fetched + activated before `ForceUpdateGate` mounts; verify the key name matches `ForceUpdateRemoteConfigKeys.minRequiredVersion` (`"min_required_version"`) |
| Force-update store button does nothing                                               | `storeUrl` is empty - RC URL keys are blank and `ForceUpdateConfig.iosAppId` / `androidPackageName` are not set                                 | Provide valid `iosAppId` and `androidPackageName` in `ForceUpdateConfig`, or populate `ios_store_url` / `android_store_url` in Remote Config                              |
| Coins double-credited on each pack buy                                               | Host still grants in `onPurchaseComplete` **and** `EconomyModule` is enabled, or the SKU is also in `consumableGrantsByProductId`               | Remove the host grant for catalog SKUs; drop those IDs from the IAP map                                                                                                   |
| Balance reset to starting coins after upgrade                                        | `migrateLegacyEconomyForGameKit` was not called before `GameKit.initialize`                                                                     | Call the helper with the live keys, then confirm `game_kit.economy.schemaVersion` is 1                                                                                    |
| Rewarded shop button permanently greyed                                              | Daily cap hit, cooldown not elapsed, or host clock differs from `GameKitConfig.clock`                                                           | Check `GameKit.economy.rewardedStatus()`; wait for next local day or cooldown; keep one clock                                                                             |

### Legacy premium storage (SharedPreferences + Hive notes)

[`GameKit.initialize`](lib/src/game_kit.dart) runs [`migratePremiumLegacySharedPreferencesForGameKitIap`](lib/src/iap/premium_legacy_shared_preferences_migration.dart) automatically for common **`SharedPreferences`** keys (`ads_removed`, `total_donations` → `game_kit.iap.*`). It is idempotent.

If the host used **different** legacy key names, call **`migratePremiumLegacySharedPreferencesForGameKitIap`** with custom parameters **before** **`GameKit.initialize`** (exported from **`package:game_kit/game_kit.dart`**).

**Hive:** The package does **not** ship a Hive premium migration helper. If premium lived in Hive under app-specific keys, plan a host-owned migration into **`GameKit.iap`** storage before dropping the old code.

---

### Phase 0 - Discover the host game

Before changing anything, build an inventory. Output it as a short report (markdown table) before proceeding.

1. Read the host app's `pubspec.yaml`. List every dependency that overlaps with `game_kit`'s feature set, including but not limited to:
   - `google_mobile_ads`, `gma_mediation_unity` (remove both from the host `pubspec`; the kit depends on `unity_levelplay_mediation`, and network **adapters** belong in the host's native build files)
   - `in_app_purchase`, `in_app_purchase_*`, store helpers
   - `in_app_review`, `rate_my_app`, custom review prompts
   - `flutter_local_notifications`, `awesome_notifications`, `timezone`, `flutter_timezone`
   - `share_plus`, `share`
   - `shared_preferences`, `hive`, `hive_flutter` (note: the package uses these too - keep them)
   - `url_launcher` (the package uses it)
   - `cached_network_image`, `dio`, `pretty_dio_logger` (the package uses them; only remove if the host app has no other use)
   - `package_info_plus`
   - `firebase_remote_config`, `firebase_core` (used solely for a force-update check)
   - HTTP clients used solely for the existing cross-promo or remote config catalog
   - **Platform targets:** note if **`web`**, **`windows`**, **`macOS`**, **`linux`** are enabled - they affect ads and store availability.
2. Search the host app source (`lib/`) for the following keywords and list every file + line that matches. Do not fix anything yet - this is a read-only audit:
   - **Ads:** `AdMob`, `InterstitialAd`, `RewardedAd`, `BannerAd`, **`MobileAds.instance`** (host init must be **removed** - the package brings the ad SDK up), `loadAd`, `levelCount`, any ads-cooldown / per-session counter, any `showInterstitial`/`maybeShowInterstitial` helper, any host-owned `AdsService` / `AppBannerAd` wrapper, any "remove ads" tooltip flag.
   - **IAP:** `InAppPurchase.instance`, `purchaseStream`, `queryProductDetails`, `buyNonConsumable`, `buyConsumable`, `restorePurchases`, any `RemoveAdsService`/`PremiumService`, donation product IDs, `adsRemoved`/`isAdFree` flag, premium Hive keys, restore button handlers.
   - **Rating:** `InAppReview`, `requestReview`, `RateMyApp`, any "Enjoying the game?" dialog, session counters, "minLevel"/"minSession" gating logic, post-ad cooldown logic specific to rating.
   - **Notifications:** `FlutterLocalNotificationsPlugin`, `AndroidNotificationChannel`, weekly schedule helpers, install-delay logic, "ignored count" logic, daily reminder copy.
   - **Cross-promo / "More games":** any list of other apps with image/title/store URL, network fetch for a games catalog, a "NEW" badge for fresh games, an "other games" bottom sheet/grid.
   - **Share:** `Share.share`, "Tell a friend", store URL builders.
   - **Haptics:** `HapticFeedback.lightImpact`, `selectionClick`, `mediumImpact`, `heavyImpact`, any host `HapticsService` not tied to gameplay-specific patterns the package does not cover.
   - **Vibration:** any host `VibrationService`, `Vibration.vibrate`, or motor-vibration helper - map to **`GameKit.haptics`** (same semantic methods as sounds). Delete host vibration prefs/UI when adopting kit settings.
   - **Sounds / SFX:** any `AudioPlayer`/`audioplayers`/`soundpool`/`just_audio` use that plays short cues for correct/wrong/win/tap - these map to **`GameKit.sounds`** (provide the host's existing files via `SoundConfig.overrides` if they should be kept). Background **music** is out of scope and stays host-owned.
   - **Settings UI:** the existing settings screen - note which rows exist (remove ads, restore, donate, rate, share, contact, more games, language, **sound mute**, haptics toggle, etc.). If adopting **`GameKitSettingsBody`**, the kit **Audio** section replaces a host **sound effects** toggle; plan to delete duplicate host prefs/UI and migrate any legacy sound-enabled key into **`GameKit.preferences`** or accept default **on** for existing users.
   - **Force update:** any existing blocking "update required" screen, version comparison logic, `min_required_version` Remote Config fetch, `firebase_remote_config` usage dedicated to force-update checks.
   - **Already using game_kit:** search for **`GameKit.`**, **`package:game_kit/`** to avoid double init or duplicate listeners.
3. Read `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. List entries related to AdMob app id, billing permission, `POST_NOTIFICATIONS`, `INTERNET`, notification channel ids, StoreKit, App Store id, custom URL schemes used by the legacy ad SDK or notification handler. Note **product flavor** manifests if any. List existing **`<queries>`** blocks; if you will use **`GameKitSettingsBody`** Contact email or any **`mailto:`** **`url_launcher`** flow, note whether **`android.intent.action.SENDTO`** with **`mailto`** is already declared (required on Android 11+).
4. Read the host app's bootstrap (`main.dart` and any `bootstrap`/`di`/`service_locator` file) and list what is initialized at startup that overlaps with `game_kit` modules.

Output the inventory as a single markdown report titled **"Phase 0 - Host audit"** with five sections: `Dependencies`, `Source matches`, `Platform manifests`, `Bootstrap`, `Open questions`. Stop and wait for the user to confirm before doing anything else.

### Phase 1 - Plan the migration

Produce a second markdown report titled **"Phase 1 - Migration plan"** with these tables. Do not write code yet.

1. **Mapping table** - for every host capability you found in Phase 0, list the replacement:

   | Host capability                                          | Replacement                                                                              | Notes                                                                                                                                           |
   | -------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
   | e.g. `AdsService.maybeShowInterstitialAfterLevel`        | `GameKit.ads.levelCompleted(failed:)` + listen on `GameKit.ads.onShouldShowInterstitial` | Cadence is `interstitialEveryNLevels` (default 2), cooldown 40s, max 8/session - copy host values into `AdsConfig` if different.                |
   | e.g. `MobileAds.instance.initialize()` in host `main`    | **Delete** - handled inside `GameKit.initialize`                                         | Duplicate init is unnecessary; all `GameKit.ads` load/show paths gate on package init.                                                          |
   | e.g. host `AdsService` / custom banner widget            | `GameKitBannerSlot` + `GameKit.ads`                                                      | Remove host GMA wrappers after cutover; keep native AdMob **app** ids in manifest / Info.plist only.                                            |
   | e.g. `PremiumService.removeAds()`                        | `GameKit.iap.purchaseRemoveAds()` + `GameKit.iap.adsRemoved`                             | Keep `removeAdsProductId` identical to the existing live SKU.                                                                                   |
   | e.g. host `SettingsCubit.soundOn` / `sound_enabled` pref | `GameKit.preferences.soundsEnabled` + kit **Audio** section in `GameKitSettingsBody`     | One-time migration: read legacy key before init if you must preserve mute state; otherwise default is **on**. Delete host toggle after cutover. |
   | e.g. host `VibrationService` / `vibration_enabled` pref  | `GameKit.haptics` + `GameKit.preferences.vibrationsEnabled`                              | Delete host service/prefs after cutover.                                                                                                                    |
   | e.g. `WalletCubit` / `WalletService`                     | `GameKit.economy` (`grantCoins` / `spendCoins` / `useAction`)                            | Call `migrateLegacyEconomyForGameKit` first. Never keep a parallel host wallet.                                                                  |
   | e.g. hint / solve inventory                              | `EconomySpendAction` list + `useAction`                                                  | Free stock is consumed before coins.                                                                                                             |
   | e.g. host shop screen                                    | `GameKitShopBody` + `GameKitShopUiConfig`                                                | Remove Ads pinned top; live prices from `IapModule.getFormattedPrice`.                                                                           |
   | e.g. `consumableGrantsByProductId` for coin SKUs         | `ShopCatalogConfig` entries                                                              | Kit credits catalog SKUs. Remove them from the IAP map to avoid double-credit.                                                                   |
   | e.g. `NotificationsService.scheduleWeekly`               | `GameKit.notifications` + `NotificationsConfig`                                          | Channel id **must stay the same** as the live one; otherwise users get duplicate channels.                                                      |
   | …                                                        | …                                                                                        | …                                                                                                                                               |

2. **Files to delete after migration** - list every file you intend to remove, grouped by reason (ads / iap / rating / notifications / cross-promo / share / haptics / sounds / settings). Include only files that exist purely to implement a capability now owned by `game_kit`. If a file mixes obsolete and still-needed logic, list it under **Files to refactor (partial removal)** instead.

3. **Dependencies to remove from `pubspec.yaml`** - only those with no other use after migration. Mark each as `safe to remove` (no other references) or `keep` (still used elsewhere).

4. **State / storage migration risks** - list any persisted keys in the host app that hold production data (premium ownership, donation totals, schedule state, rating dismissal counters, **coin balance**, **hint inventory**). Decide for each: keep + migrate into `game_kit`'s storage, or accept loss with explicit user approval. Common **`SharedPreferences`** keys `ads_removed` / `total_donations` are copied inside **`GameKit.initialize`**. Coin keys must be copied with **`migrateLegacyEconomyForGameKit`** **before** init - skipping it resets paying players to the starting grant. Never ship **`EconomyModule`** alongside a still-live host wallet. Hive or other layouts need a host-owned migration plan.

5. **Open questions for the user** - anything you cannot answer from the audit (e.g. "host app uses three donation tiers but stores SKUs as small/medium/large; confirm the live store SKU strings"). Stop and wait for answers before Phase 2.

### Phase 2 - Add the package and build the config

Only after Phase 1 is approved.

1. Add `game_kit` using the **Git dependency** at the top of this document (or `path:` if the user works offline / monorepo).
2. Run `flutter pub get`.
3. `import 'package:game_kit/game_kit.dart';`
4. Build **`GameKitConfig`** from the host app's existing values - **not** from generic examples. Follow the **`GameKitConfig` table**, **Config skeletons**, and **Bootstrap order** in **game_kit package reference** above. Port live AdMob unit ids, IAP SKUs, notification channel ids, and schedule copy from the Phase 0 audit.

Compile and run before Phase 3. Do **not** delete any host code yet.

### Phase 3 - Move call sites to `GameKit.*`

For each module, **redirect** the existing call sites to the new API, but keep the old class files in place for now so the project still compiles if you missed a reference. Follow **Recommended order for Phase 3** in the reference section.

- **Ads (`GameKit.ads`)** - **`levelCompleted`**, handle **`onShouldShowInterstitial`** with **`runInterstitialCycle()`** (or manual show + **`adClosed`** contract), **`GameKitBannerSlot`** for banners, **`requestAdGrant`** for unlocks/coins, **`showRewarded`** / **`canShowRewarded`** for must-watch hints, optional tooltip stream; wire via **`GameKitSignals`**.
- **IAP (`GameKit.iap`)** - purchases, restore, **`adsRemoved`**, consumable grants in **`onPurchaseComplete`**.
- **Rating (`GameKit.rating`)** - **`levelSucceeded`** (1-based level), **`levelFailed`**, streams, **`respond`**.
- **Notifications (`GameKit.notifications`)** - **`onFirstDailyCompletion`**, **`markPlayedToday`**. FCM: host `[DEFAULT]` **`Firebase.initializeApp`** + **`gameKitFirebaseMessagingBackgroundHandler`** in `main`; topic **`all_users`**.
- **Cross-promo (`GameKit.crossPromo`)** - sheet, badges, **`markGamesViewed`**.
- **Share (`GameKit.share`)** - **`shareApp`**.
- **Haptics (`GameKit.haptics`)** - semantic methods; **`HapticsConfig.isEnabled`**.
- **Sounds (`GameKit.sounds`)** - same semantic methods; **`SoundConfig`** gating/overrides; bundled cues or host assets. Drop host sound mute prefs/UI when using kit **Audio** section.
- **Settings UI (optional)** - **`GameKitSettingsBody`** (includes **Audio** / sound-effects toggle by default), sections/palette as in the reference section; on Android, merge **`mailto`** **`<queries>`** when using the Contact email row (see **Platform checklist**).
- **Force update (optional)** - implement **`ForceUpdateRemoteConfig`** adapter; wrap app root with **`ForceUpdateGate`**; pass **`ForceUpdateService`**, **`ForceUpdateConfig`** (including `currentVersion` and the four screen colors), locale-aware **`ForceUpdateStrings`**, and optional **`illustration`** widget. Remove any existing host-owned version-gate or blocking update screen once the kit gate is in place.

After each module migration, run `flutter analyze` and a smoke build.

### Phase 4 - Delete the obsolete code

Only after every call site has moved to `GameKit.*` and the project compiles cleanly.

**Rollback safety:** If anything regresses late in Phase 3, revert the last commit(s) **before** mass deletion in Phase 4. Prefer small commits per module so git revert is possible.

1. Delete Phase 1 **Files to delete** only when nothing references them; re-run Phase 0 greps.
2. Refactor **partial-removal** files - remove only migrated logic.
3. Remove **`safe to remove`** dependencies; `flutter pub get` + analyze after each.
4. **Platform manifests** - keep one valid AdMob app id; keep permissions the kit needs; do not change live notification channel ids without approval; remove duplicates / dead entries only when safe. If **`GameKitSettingsBody`** Contact email is shown, add **`<queries>`** **`SENDTO`/`mailto`** (see **Platform checklist**) to **`main`** (and flavor) manifests when missing.
5. Remove assets and l10n keys used **only** by deleted UI (search before delete).
6. Remove or rewrite tests that targeted deleted code.

Then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug   # or ios / web depending on the target
```

### Phase 5 - Final verification

Use this checklist on a **real device or emulator** (not analyzer-only):

| Check                        | Pass criteria                                                                                                                                                                                                                                                                                                          |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cold start                   | No crash; **`GameKit.initialize`** completes once                                                                                                                                                                                                                                                                      |
| Win level × N                | Interstitial appears per **`interstitialEveryNLevels`** when not ad-free; **`adClosed`** runs after each attempt                                                                                                                                                                                                       |
| Ad-free purchase             | Banners hidden; no interstitial; **`adsRemoved`** true after purchase                                                                                                                                                                                                                                                  |
| Restore                      | Ad-free restores on fresh install (sandbox / test account)                                                                                                                                                                                                                                                             |
| Lose then win                | No rating on immediate next win after **loss** if **`levelFailed`** was wired                                                                                                                                                                                                                                          |
| Rating prompt                | Soft prompt appears only when policy allows; **positive** / **negative** / **dismissed** update behavior                                                                                                                                                                                                               |
| First daily completion       | OS notification permission; scheduled notification uses correct **channel id** (Android); FCM topic **`all_users`** joined when `[DEFAULT]` Firebase is present                                                                                                                                                         |
| FCM campaign                 | Host Firebase Console send to **`all_users`** (notification title + body): tray in background; in-app banner in foreground; tap opens the app                                                                                                                                                                           |
| Cross-promo                  | Sheet opens; **NEW** badge clears after **`markGamesViewed`**                                                                                                                                                                                                                                                          |
| Share                        | Share sheet shows store link                                                                                                                                                                                                                                                                                           |
| Contact email (kit settings) | On Android, **`mailto:`** opens an email app when installed; no spurious “can’t open” after **`queries`** merge - verify on a device **after** clean install                                                                                                                                                           |
| Haptics                      | Effects match toggle if present                                                                                                                                                                                                                                                                                        |
| Sounds                       | Cues fire on correct/wrong/win; **settings Sound effects toggle** mutes/unmutes and **persists after restart**; optional **`SoundConfig`** volume / silent-switch behavior as configured                                                                                                                               |
| Locale                       | Switch **en/ar** (if shipped); kit strings follow **`GameKit.updateLocale`**                                                                                                                                                                                                                                           |
| **Puzzle cheat sheet**       | All items in **Puzzle game developer cheat sheet and acceptance criteria** verified or explicitly waived in the Phase 5 report                                                                                                                                                                                         |
| Rewarded ads                 | Unlock/coin taps use **`requestAdGrant`** (hard rules in **`docs/AD_GRANT.md`**); **`shouldSkipAdGrantOffer`** skips the watch-ad popup; airplane mode shows connect-to-internet and does **not** grant; must-watch hints use **`canShowRewarded`** + **`showRewarded`** |
| Fail → no interstitial       | **`levelCompleted(failed: true)`** on fail; no interstitial shown for that outcome                                                                                                                                                                                                                                     |
| In-game remove-ads entry     | Persistent control on gameplay screen opens pitch (not settings-only) if product requires it                                                                                                                                                                                                                           |
| Offline core play            | Puzzle works offline; graceful handling when ads/catalog unavailable                                                                                                                                                                                                                                                   |
| Force update gate            | Temporarily set `min_required_version` in RC above `ForceUpdateConfig.currentVersion` - blocking update screen appears (rocket illustration, localized copy, outlined button); back navigation is disabled; **Update Now** opens the correct store. Reset RC - normal child widget is shown after the next app resume. |
| Economy balance survives     | After upgrade, coins and inventory match pre-migration values (not reset to starting grant)                                                                                                                                                          |
| Shop purchase                | Buying a pack credits **once**; snackbar shows the coin amount; Remove Ads is pinned at the top of the shop                                                                                                                                          |
| Rewarded shop coins          | Button shows “X/5 left today”; greys out on cap and during cooldown; declining a view does not grant                                                                                                                                                 |
| Daily login                  | First return of a new local day pays once; same-day re-open pays nothing; a missed day resets the streak                                                                                                                                             |

Also confirm persisted data survived (legacy migration or matching storage).

Produce **"Phase 5 - Migration complete"** with: files added/modified/deleted, deps removed, manifests, checklist results, and open follow-ups.

### What you must not do

- Do not change live AdMob unit ids, IAP product ids, Android notification channel id, or store package names without explicit user approval.
- Do not delete a file until you confirm every responsibility has moved.
- Do not introduce new state-management or DI stacks; reuse the host patterns.
- Do not refactor the host architecture “while you’re here.”
- Do not leave large commented-out legacy blocks.
- Do not modify the **`game_kit`** package source in the dependency - if something is missing, report it.
- Do not register **duplicate** `StreamSubscription`s to **`GameKit`** streams on every rebuild without canceling the old ones.
- Do not hardcode a minimum required version in Dart - `min_required_version` must come from Remote Config so it can be updated server-side without a new build.

### Deliverables (recap)

1. **Phase 0 - Host audit** report.
2. **Phase 1 - Migration plan** - wait for user approval.
3. `pubspec.yaml` with `game_kit`.
4. `GameKitConfig` + bootstrap per this document.
5. Call sites on `GameKit.*`, module by module, analyzing clean.
6. Legacy code, deps, manifests, assets, tests removed where safe.
7. **Phase 5 - Migration complete** report with verification evidence and **Puzzle game developer cheat sheet** sign-off (or explicit waivers).
