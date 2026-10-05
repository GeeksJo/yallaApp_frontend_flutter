# Signals

Hosts used to declare six `StreamSubscription`s and forget to cancel one on
dispose. `GameKitSignals.bind` subscribes only to the callbacks you pass;
`GameKitSignalsMixin` cancels them in `State.dispose`.

`lib/src/app/game_kit_signals.dart`

## Why this shape

Call `bind` **once**, after `GameKit.initialize`. Binding twice asserts.
Omit unused callbacks; there is no empty listener tax.

Typical bind: interstitial → `runInterstitialCycle`, rating soft prompt /
feedback, IAP complete / restore / error, optional `onEconomyGrant`. The
remove-ads popup is kit-owned (after an end-of-round network interstitial,
capped); do not bind `onShouldShowRemoveAdsTooltip` unless you set
`presentRemoveAdsTooltip: false`.

This is glue, not a second event bus. The modules still own the streams.

## Known limits

- Interstitial callback is `void Function()?`. If you need `BuildContext`
  for the promo interstitial, close over it or pass `context` into
  `runInterstitialCycle(context: …)` from a `State`.
- Economy grant subscription is skipped when `GameKit.hasEconomy` is false.
