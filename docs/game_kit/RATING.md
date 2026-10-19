# Rating

A store deep-link after every win burns Apple/Google quotas and feels like an
ad. The kit owns a **one-step** prompt: when policy allows, it requests the OS
**in-app** review sheet directly. No “Enjoying the game?” question comes first
(Google Play forbids pre-questions before the review card) and a low rating is
never routed to email. Settings “Rate this app” requests the same **in-app**
review sheet only (never deep-links to the store listing).

`lib/src/rating/` · `GameKit.rating` · `RatingConfig`

## Why this shape

Policy lives in `RatingStateMachine` so every game shares the same gates:
level ≥ **4**, session ≥ **2**, max **3** lifetime soft prompts, **4** local
calendar days between shows, **60s** after any interstitial close (`AdClosedEvent`),
never after a fail, never more than once per local day. Three dismissals →
permanent stop. A submitted rating (`positive`) also stops forever.

`levelFailed()` suppresses the **next** success so a recovery win does not
prompt. `registerSessionLaunch` runs from `GameKit.initialize`.

Prefer `GameKitRatingPrompt.presentIfEligible(context, level: …)` after a win.
It listens for the soft-prompt signal and, when it fires, calls
`requestNativeReview` straight away; it returns true so the caller skips the
interstitial on that beat. Tests inject `GameKitConfig.reviewClient` so the
native sheet never opens.

## iOS native sheet

iOS silently blocks the native sheet after **3 shows per year**. The kit
counts a **soft prompt shown**, not whether the OS actually presented a sheet.
If you trigger the flow and no sheet appears, that still consumed a kit
lifetime slot. Do not add a second host counter on top.

## Known limits

- There is no feedback branch: a “Contact us” row in settings is the only
  mailto, never a reaction to a rating answer.
- `openStoreListingForCurrentPlatform` needs `ShareConfig.iosAppId` on iOS
  or it no-ops (avoids `in_app_review` throwing).
