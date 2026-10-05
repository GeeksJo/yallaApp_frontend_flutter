# Rating

A store deep-link after every win burns Apple/Google quotas and feels like an
ad. The kit owns a **two-step, sentiment-based** prompt: “Enjoying the game?”
then either the **in-app** review sheet or a feedback mailto. Settings “Rate
this app” requests the **in-app** review sheet only (never deep-links to the
store listing).

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
It listens for the soft-prompt signal, shows kit EN/AR copy, then calls
`respond`. Tests inject `GameKitConfig.reviewClient` so the native sheet never
opens.

## iOS native sheet

iOS silently blocks the native sheet after **3 shows per year**. The kit
counts a **soft prompt shown**, not whether the OS actually presented a sheet.
If you trigger the flow and no sheet appears, that still consumed a kit
lifetime slot. Do not add a second host counter on top.

## Known limits

- Feedback after “Not really” is a mailto, not an in-app form.
- `openStoreListingForCurrentPlatform` needs `ShareConfig.iosAppId` on iOS
  or it no-ops (avoids `in_app_review` throwing).
