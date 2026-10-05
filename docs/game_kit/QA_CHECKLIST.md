# Game Kit — QA Checklist

Test on **Android + iOS** (one small phone, one tablet). Mark items that don't apply as **N/A + reason**.
Ask the developer for the game's configured values (ad cadence, notification days/hour, enabled features) — numbers below are kit defaults.

**Game:** ______ **Version:** ______ **Tester:** ______ **Date:** ______

## Ads
- [ ] EU (VPN) fresh install: consent form shows before any ad; Settings has an ad privacy row.
- [ ] Interstitial only between levels, every 2nd win, 40 s cooldown, max 8/session, none in the first 60 s.
- [ ] No ad after a lost level or on the retry right after it.
- [ ] Promo ads (if enabled): alternate promo / AdMob; CTA → store, never shown again; 4× X → never shown again.
- [ ] Banner doesn't cover buttons or the safe area.
- [ ] Rewarded hint: full watch → reward once; closed early → no reward.
- [ ] Unlock / get coins: offline → "connect to internet", no grant; online → grant once (even with no ad), never "no ad available"; double tap → one grant.

## Remove Ads ($2.99)
- [ ] "No ads" icon at the top of the game screen opens a popup with the store price.
- [ ] Purchase removes banners + interstitials immediately; icon hides.
- [ ] Cancel / fail → clear message, no change.
- [ ] Reinstall → Restore purchases → ads removed again.
- [ ] Reminder popup after an AdMob ad: max once/session, 3 ever, 4 days apart.

## Coins & Shop (if used)
- [ ] Starting coins given once; hints use free stock first, then coins; never negative.
- [ ] Daily login: +30 → 70 streak, once per day, resets after a missed day.
- [ ] Coin packs add the right amount once; prices come from the store.
- [ ] Free coins: +40, 5/day, 20 min cooldown, button shows text when unavailable.
- [ ] Coins survive restart and updating from the old game version.

## Rating
- [ ] Only after a win, level ≥ 4, session ≥ 2; never after a loss or within 60 s of an ad.
- [ ] "Yes" → native in-app rating popup; "Not really" → feedback email.
- [ ] Max 3 prompts ever, 4 days apart; stops after rating or 3 dismissals.

## Settings, Sounds & Haptics
- [ ] All rows work: Remove ads, Restore, Donate, Rate, Share, More games, Email, Website.
- [ ] Sound and Vibration toggles work instantly and persist after restart.
- [ ] Tap, correct, wrong, and level-complete each have distinct sound + vibration.
- [ ] Countdown sound stops when leaving the screen; phone call pauses sounds.

## More Games & Share
- [ ] More Games on home (and game screen); opens correct store pages; current game not listed.
- [ ] NEW badge shows for a new game and clears after viewing; works offline from cache.
- [ ] Share sends a localized message + the correct store link.

## Notifications
- [ ] Permission asked after the first completed game, not on launch.
- [ ] None in the first 48 h; only on configured days/hour; skipped if played today; stops after 3 ignored.
## Offline, Resilience & Layout
- [ ] Fully playable in airplane mode; ad failures never block progress.
- [ ] Background / kill mid-level → no lost progress.
- [ ] Arabic: everything translated and mirrored; English: no RTL leftovers.
- [ ] No text overflow on small phone or tablet; buttons ≥ 44 pt.

**Bug report:** Section · Device/OS · Version · Language · Online? · Steps · Expected · Actual · Screenshot
