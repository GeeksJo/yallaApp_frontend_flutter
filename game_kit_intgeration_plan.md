# Phased game_kit integration plan for Yalla

## Delivery approach

Integrate **one phase per implementation request**. Each phase must include its code, focused tests, acceptance checklist, and a short handoff describing what remains.

Complete Phase 1 first. After that, phases can be selected individually according to their dependencies; finishing one phase does not automatically start the next.

Keep these agreed choices throughout:

- Yalla integration only; use resolved game_kit revision `5a43efe`.
- Retain the existing host economy and prices.
- Enable house ads.
- Use cache-first Remote Config startup.
- Rating begins from the second app session.
- Ad cadence counts completed rounds whose final turn succeeds.
- No ATT prompt.
- Process-termination match recovery remains deferred.

## Phase 1 — Firebase and Remote Config foundation

**Dependency:** None.  
**Purpose:** Remove the current compile errors and establish the configuration service used by later phases.

Implement:

- Restrict `FirebaseService` to initializing/retrieving host `[DEFAULT]` Firebase. A named Firebase app must not count as the default app.
- Consolidate RC ownership into `RemoteConfigService`; remove foreign-app imports, unsupported environment/logger references, duplicate constants, and the incorrect 120-second cooldown.
- Keep `YallaRemoteConfigAdapter extends GameKitRemoteConfig`, backed by the consolidated service.
- Provide initialization, refresh, disposal, typed getters, an ads resolver, and a cold-start LevelPlay identifier snapshot.
- Expose Firebase availability separately from RC readiness, plus ads state and a notifier for all activated configuration changes.
- Load cached values before GameKit initialization; fetch fresh values in the background.
- Use a 10-second fetch timeout, one-hour release interval, and zero debug interval.
- Coalesce overlapping operations, retry failed initialization, retain cached values after failures, and manage one realtime subscription.
- Refresh on resume; cancel subscriptions and ignore late completions after disposal.
- Register the FCM background handler based on Firebase availability rather than RC fetch success.
- Refresh kit banner state after host RC activation.
- Keep UMP consent enabled independently of the ads switch.

Configuration contract:

| Configuration | Resolution |
|---|---|
| Ads switch | Host RC → enabled |
| Minimum version/current store URLs | Host RC → no block/generated current-listing URLs |
| App-moved flag/successor URLs | Host RC → disabled/empty |
| Interstitial cooldown | Host → kit → 40 seconds |
| Startup grace | Host → kit → explicit 60 seconds |
| Free-grant cooldown | Host → kit → 60 minutes |
| Rewarded load wait | Host → kit → four seconds |
| Support email/website | Host → kit → packaged defaults |
| LevelPlay app keys and used unit IDs | Cached host overrides → existing platform identifiers |

Do not seed host defaults that hide shared kit settings. Preserve deliberate numeric zero and return caller defaults for malformed values. Freeze coherent ad identifiers for the process; new identifiers take effect on the next cold start.

**Acceptance:**

- Current RC compile errors are resolved.
- App starts without awaiting an RC network fetch.
- Offline launches retain cached configuration.
- Tests cover missing Firebase, missing default app, fetch/activation failures, retry, realtime updates, defaults, coalescing, and disposal.
- Existing gameplay behavior remains usable before later phases are integrated.

## Phase 2 — Force update and app-moved screens

**Dependency:** Phase 1.

Implement:

- Read installed version through a direct `PackageInfo` dependency.
- Replace hardcoded iOS version metadata with Flutter build variables.
- Add an emergency coordinator inside `MaterialApp.builder`, using kit services and screens.
- Evaluate cached RC immediately and reevaluate after configuration changes and resume.
- Give app-moved precedence over force update.
- Preserve the navigator/gameplay tree behind blockers; disable input/tickers and pause gameplay/audio while blocked.
- Use Yalla colors and kit Arabic/English strings.
- Keep current-listing and successor URLs separate.
- Fail open without valid configuration; retain cached valid blocks during network failure.

The host coordinator avoids the resolved package gates’ limitations around realtime rechecks and preserving the child tree.

**Acceptance:**

- Higher minimum versions block; equal/lower versions do not.
- App-moved changes appear without relaunch.
- URL-only updates refresh the action.
- Clearing a block restores existing navigation.
- Offline, malformed-version, localization, and precedence tests pass.

## Phase 3 — Interstitials, banners, and house ads

**Dependency:** Phase 1.

Implement:

- Replace host load/show orchestration with `GameKit.ads.runInterstitialCycle(context: ...)`.
- Remove host timeouts that release gameplay while a displayed ad remains open.
- Retain one presentation guard and prevent conflicting navigation.
- Let the kit own `adClosed()` and its remove-ads popup.
- Call `levelCompleted` exactly once per round boundary, including the final round.
- Count a round when its final turn succeeds; a final-turn timeout suppresses that boundary.
- Configure every second qualifying round, 40-second cooldown, eight/session, and 60-second startup grace.
- Remove forced interstitials from abandon/Home actions.
- Enable house-ad rotation and fallback.
- Remove the duplicate host remove-ads snackbar listener.
- Collapse banner wrappers completely when no ad fills.

**Acceptance:**

- Ads appear only at eligible round boundaries.
- Long displayed ads do not release underlying gameplay.
- House/network rotation and campaign fallback work.
- Ads switch and Remove Ads collapse banners immediately.
- No-fill leaves zero banner spacing.
- Boundary events and presentation attempts cannot duplicate.

## Phase 4 — Coin ad-grant flow

**Dependencies:** Phases 1 and 3.

Implement:

- Keep `requestAdGrant` with the `currency` cooldown group.
- Guard coin requests in both provider and UI; ignore overlapping taps.
- Apply +20 exactly once for a granted outcome.
- Handle all seven outcomes using kit localized notices.
- Show a localized generic error for unexpected exceptions without granting or claiming the device is offline.
- Pass presentation context for house-ad fallback.
- For Remove Ads owners, label the action “Get coins” and use the kit’s documented ad-free grant.
- Preserve the rewarded carve-out when pushed ads are disabled.

**Acceptance:**

- Offline, skipped, and cooldown outcomes grant nothing.
- Rewarded, interstitial, house-ad, and free outcomes grant once.
- Repeated taps produce one accepted attempt.
- Reward application finishes safely if the sheet closes.
- Paid-user and kill-switch behavior match the documented contract.

## Phase 5 — Host wallet and category transaction safety

**Dependency:** Phase 1.  
**Relationship:** Can be integrated before Phase 4; Phase 4 must then use its transaction API.

Implement:

- Retain `CoinProvider` as the wallet source of truth.
- Preserve 50 starting coins, +1 correct-answer rewards, +20 ad grants, 30-coin rentals, and 100-coin purchases.
- Persist wallet balance, purchased categories, and rental expiries in one versioned record.
- Migrate legacy keys idempotently without resetting a zero balance.
- Serialize mutations and persist before publishing updated state.
- Prevent negative balances, repeat permanent charges, and repeat charges for active rentals.
- Preserve the two-hour rental duration.

**Acceptance:**

- Existing users retain balances and entitlements.
- Failed writes leave visible balance and ownership unchanged.
- Concurrent rewards/spends remain consistent.
- Interrupted migrations resume safely.
- Kit economy, daily rewards, coin packs, and shop remain intentionally unused.

## Phase 6 — IAP and donation migration

**Dependency:** Phase 1.  
**Relationship:** Phase 3 supplies the final ad-suppression behavior.

Implement:

- Keep existing Remove Ads and donation product IDs.
- Replace custom gameplay purchase UI with the kit helper/button.
- Use store-formatted prices and kit cancellation/error handling.
- Prevent overlapping purchases.
- Verify restore updates the shared `adsRemoved` entitlement.
- Make legacy donation migration restart-safe and ensure source data is cleared only after a successful migration.
- Avoid duplicate purchase analytics or host entitlement flags.

**Acceptance:**

- Purchase/restore removes banners and boundary interstitials.
- Cancelled or failed purchases do not change entitlement.
- Rewarded behavior remains available as documented.
- Donation totals migrate once and survive restart.
- Store SKUs are recorded as externally verified or awaiting verification.

## Phase 7 — Settings, preferences, sounds, and haptics

**Dependency:** Phase 1.

Implement:

- Make kit preferences the sole sound/vibration source.
- Migration precedence: existing kit vibration preference → explicit legacy haptics → legacy sound → enabled.
- Remove duplicate host vibration UI and the extra host haptic gate.
- Update the localized About description whenever locale changes.
- Correct the current “30-second” description to match configurable gameplay timing.
- Retain `respectSilentMode: false`.
- Stop countdown audio on pause, background, emergency blocking, and exit.
- Pair sound/haptics for success and completion events.
- Remove empty listeners and give retained subscriptions one disposable owner.

**Acceptance:**

- Sound/vibration switches work immediately and persist.
- Existing preferences migrate without overriding newer kit choices.
- Arabic/English About text changes immediately.
- Audio stops on every relevant interruption.
- Settings contain no conflicting duplicate controls.

## Phase 8 — Rating flow

**Dependencies:** Phases 3 and 7.

Implement:

- Use session ≥2 and minimum four cumulative successful answers.
- Keep cumulative answer counting independent of round numbering.
- Evaluate rating only at a successful round/results boundary after fullscreen handling.
- Call `levelFailed()` for timeout and abandonment.
- Use `GameKitRatingPrompt.presentIfEligible`.
- Remove global rating listeners and English-only custom dialogs.
- Let the kit own lifetime limits, dismissal limits, review behavior, and feedback contact resolution.

**Acceptance:**

- No prompt in session one, after failure, or during gameplay/ad presentation.
- Recovery-win suppression and the post-ad delay work.
- Prompt and feedback flow are localized.
- There is one rating flow and no duplicate counters/listeners.

## Phase 9 — Local notifications and FCM

**Dependencies:** Phases 1 and 7.

Implement:

- Run first-completion handling for every player, including Remove Ads owners.
- Preserve Mon/Wed/Fri at 18:00 and the documented delay/suppression rules.
- Use localized kit reminder/channel defaults.
- Refresh scheduling after locale changes and resume.
- Keep permission requests tied to meaningful completion.
- Complete iOS background modes and verify signing/APNs configuration.
- Use host Firebase and notification title/body campaigns; taps remain normal app launches.

**Acceptance:**

- Permission is not requested on launch or repeatedly after denial.
- Paid users receive the same permission opportunity.
- Reminder delay, played-today suppression, and ignored-reminder limits work.
- Foreground/background FCM is verified on physical devices.
- Missing Firebase does not prevent play.

## Phase 10 — More Games and sharing

**Dependencies:** Phases 1 and 7.

Implement:

- Keep More Games on home/gameplay and one settings entry.
- Use kit catalog caching and refresh on resume.
- Ensure NEW badge changes rebuild their UI and clear after viewing.
- Verify self-exclusion and platform store links.
- Set share analytics identity to stable `yalla`.
- Preserve localized share text and existing Android/iOS identifiers.

**Acceptance:**

- Cached games remain available offline.
- Failed refresh retains the previous catalog.
- NEW badge appears and clears correctly.
- Yalla is excluded from its own promotions.
- Sharing uses the correct platform link.

## Phase 11 — Host analytics

**Dependency:** Phase 1.  
**Relationship:** Integrate after the relevant UI phases to instrument their final behavior.

Implement:

- Use stable game identity `yalla`.
- Start sessions when the first answer phase begins.
- Complete sessions before results.
- Track confirmed abandonment.
- Use `logReplayedOnly` when Play Again returns to setup; start the next session when gameplay begins.
- Register `GameAnalyticsNavigatorObserver` and stable route names.
- Disable automatic native screen reporting on both platforms.
- Log host-owned offers and feedback actions only; retain kit-owned ad/IAP/rating events.
- Correct comments describing the named kit app as an analytics destination.
- Record GA4 custom definitions and BigQuery linkage as external setup tasks.

**Acceptance:**

- Each semantic action produces one appropriate event.
- Setup navigation does not count as gameplay.
- Screens have readable names.
- Kit and host events reach host Firebase.
- DebugView verification is recorded; no duplicate logging exists.

## Phase 12 — Final integration and release verification

**Dependency:** All selected implementation phases.

Complete:

- Replace the placeholder widget test with real smoke coverage.
- Run static analysis and the complete test suite.
- Build Android and iOS.
- Execute device QA in Arabic/English on a small phone and tablet.
- Verify offline play, RC activation, emergency screens, consent, ads, grants, purchases/restore, preferences, rating, sharing, and FCM.
- Verify Firebase identity, published RC parameters, mediation groups, test devices, store SKUs, and APNs configuration.
- Publish the final integration checklist with evidence and remaining external dependencies.

**Acceptance:**

- Required automated checks and platform builds pass.
- Selected phases satisfy their individual acceptance criteria.
- External setup is clearly verified or outstanding.
- Unrelated workspace changes are preserved.
- Kit economy/shop, ATT, and process-termination recovery remain explicitly excluded.
