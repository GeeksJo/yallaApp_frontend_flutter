# Economy module - why the kit owns coins

Word games share one economy: a single coin balance, a handful of spend
actions (hint, solve, shuffle, …), a daily-login streak, a capped rewarded
faucet, and IAP packs. Hosts used to re-implement all of that, then map
`onPurchaseComplete` onto their own wallet. That split is how balances
diverge, grants double-fire, and a shop UI cannot be reused.

`EconomyModule` is the opt-in source of truth. When a host passes
`GameKitConfig.economy`, the kit persists coins and inventory, credits IAP
from the shop catalog, and pays daily-login / rewarded-ad grants itself.
Hosts that omit `economy` keep the old contract: the kit never grants
content, and `IapConfig.consumableGrantsByProductId` stays a metadata map
the host reads.

## Storage schema (`game_kit.economy.*`)

Scope `economy`. Logical keys (no prefix in `GameKitStore` calls):

| Logical key | Type | Meaning |
|-------------|------|---------|
| `schemaVersion` | int | Layout version. Current: **1**. |
| `coins` | int | Wallet balance. `0` is a real balance, not “unset”. |
| `inventory` | string (JSON object) | `{actionId: count}` so adding an action never orphans a key. |
| `installGrantDone` | bool | One-time starting coins + free stock. Never tops up a spent-down player. |
| `login.lastDayKey` | string | Last paid local calendar day (`yyyy-mm-dd`). |
| `login.streak` | int | Consecutive paid days. Caps at the ladder length. |
| `login.installDayKey` | string | Install local day. Streak starts on the first *return*, not install day. |
| `rewarded.dayKey` | string | Local day the rewarded counter belongs to. |
| `rewarded.count` | int | Completed rewarded views that granted coins today. |
| `rewarded.lastAtMs` | int (epoch ms) | When the last granted view closed. Cooldown starts here. |

Day keys are **local-timezone** calendar dates derived from
`GameKitConfig.clock` (`yyyy-mm-dd`). Not UTC, not epoch-day.

No new package dependencies: JSON via `dart:convert`, persistence via
`GameKitStore`, UI state via `ValueNotifier`.

## Spend actions

Each game declares `List<EconomySpendAction>` (id, coin cost, starting free
grant). Spec default: `hint` @ 20 with 2 free, `solve` @ 100 with 1 free.
`useAction` consumes **free stock first**, then coins, and reports which
path was taken so gameplay can celebrate without re-reading balances.

## Daily login

First open of a new local day after install day pays the streak ladder
`[30, 37, 43, 50, 57, 63, 70]`. Same-day re-opens pay nothing. A missed
calendar day resets to day 1. Call `claimDailyLoginIfDue()` from the host
when it is ready to show a celebration (returns `null` when nothing is owed).

## Rewarded faucet

`+40` coins per completed view, **5/day**, **20 min cooldown** after the
reward is earned. `RewardedCoinsStatus` exposes `remainingToday`,
`nextAvailableAt`, and `isReady` so the shop button can grey out with
“X/5 left today” instead of failing silently.

This cap is **not** in `AdsModule` (that module only tracks interstitial
cooldown / session cap). It lives here because it is an economy rule.

## IAP crediting

When the economy is enabled, the shop catalog is the source of truth for
consumable SKUs. `onPurchaseComplete` for a catalog product credits coins +
inventory inside the kit. Do **not** also grant from a host listener, and
do **not** list the same SKU in `IapConfig.consumableGrantsByProductId`
(debug-asserted).

Cash prices are **not** on the catalog. Hosts pass store product ids;
`IapModule` queries those ids and the shop renders `getFormattedPrice`.

Grants are client-trusted - the kit has no server-side receipt validation.

## Legacy migration

Call `migrateLegacyEconomyForGameKit` **before** `GameKit.initialize` with
the host’s live SharedPreferences keys (coins + per-action inventory). It
is idempotent: writes only when `game_kit.economy.schemaVersion` is unset.
Skipping it resets paying players to the starting grant.

## Known limits

- No subscriptions, no second currency, no server receipts.
- Override mode (`applyOverride`) is in-memory only - for store screenshots
  and demos. It must not persist.
- Daily login is claimed by the host (`claimDailyLoginIfDue`), not on init,
  so the celebration UI is never skipped.
