# Shop UI - one list, per-app theme

The shop is the same idea as settings: **one widget tree**, look-and-feel from
config. Hosts do not fork cards per game.

## Theming chain

`GameKitShopUiConfig` (host colors, fonts, section flags) →
`GameKitShopPalette.fromUiConfig` (resolved tokens) → widgets.

Shop **numbers** (prices, coin amounts, bonus %) default to bundled
**Poppins** (`GameKitShopFonts`, declared in this package’s `pubspec.yaml`).
Hosts only set `numbersFontFamily` to override; leave it null for kit Poppins.

Override order in `GameKitShopBody`: `widget.palette` → `widget.uiConfig` →
`GameKit.shopUi` → seed fallback. `GameKit.updateShopUi` pushes a new config
through `shopUiListenable` so a running shop re-themes without a rebuild of
the host route.

`sectionCardAppearance` is the same enum as settings (`opaqueLight` /
`frosted`) so a shop sitting next to `GameKitSettingsBody` can match it.

Pack colors are an ordered `List<ShopTone>` assigned **by tier index**, not
by coin amount. A four-pack ladder does not inherit six hardcoded
breakpoints.

## Catalog

`ShopCatalogConfig` on `EconomyConfig`:

- **Coin packs** - IAP consumables. Each pack is a **store product id**.
  Cash prices are loaded with `IapModule.loadProducts({productId})` →
  `getFormattedPrice(productId)` - never a Dart `$0.99`. `coins` on the
  pack is the in-game grant, not money. `GameKit.initialize` registers
  catalog SKUs so `loadStoreProducts()` includes them even when they are
  absent from `IapConfig.consumableGrantsByProductId`.
- **Bundles** - optional. Coins plus `Map<String,int>` inventory grants.
  Same IAP price path as coin packs.
- **Inventory packs** - optional, coin-priced, no store round-trip.

The word-game spec ships six coin packs and no bundles / inventory packs.
Hosts that sell those extra sections set `hasBundles` / `hasInventoryPacks`
on the UI config **and** pass the lists.

Art is `ShopArt.asset` (PNG; `package: null` for host assets, `'game_kit'`
for kit art), `ShopArt.icon`, or `ShopArt.builder` for SVG / custom. The kit
does not depend on `flutter_svg`.

**Defaults** are bundled PNGs (`GameKitShopAssets`): coin and video both use
`coin.png`, hint bulb / search, six coin-pack tiers (`2`-`5`, `7`, `10`),
and three bundle images (`6`, `8`, `9`). Omit `art` on a pack or bundle
and the shop picks by tier index.
Override:

```dart
ShopCoinPack(
  productId: 'mygame.coins_small',
  coins: 2000,
  art: ShopArt.asset('assets/icons/my_pile.png'), // host asset
),

GameKitShopUiConfig(
  seedColor: brand,
  coinArt: ShopArt.asset('assets/icons/coin.png'),
  videoArt: ShopArt.asset('assets/icons/video.png'),
  actionArt: <String, ShopArt>{
    'letter_hint': ShopArt.asset('assets/icons/hint_bulb.png'),
    'word_hint': ShopArt.asset('assets/icons/hint_search.png'),
  },
)
```

`GameKitShopStrings` overrides pack display names. Kit EN/AR is the
fallback (Handful / Pile / Sack / Bucket / Chest / Vault).

## Composition

Host owns the scaffold. Embed:

```dart
GameKitShopBody(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
)
```

Or push `GameKitShopScreen` for a ready-made app bar + coin pill.

Remove Ads is **pinned at the top** (QA checklist). Free-coins is second.
Both hide themselves when ads are already removed / the faucet is disabled.

Coin packs use `GameKitShopUiConfig.coinPackColumns` (default **3**). Set
`coinPackColumns: 1` for full-width horizontal pack rows with a larger icon.

## Controller

`ShopController` is a `ChangeNotifier` (no bloc). It retries store prices at
0s / 2s / 4s, guards double-taps, and emits `Stream<ShopEvent>` for
snackbars. `debugGrantWithoutBilling: true` is the tester / example path -
not a dart-define.

## Known limits

- No subscriptions.
- No server-side receipt validation; grants are client-trusted.
- No `flutter_screenutil`; cards use logical pixels and the kit’s tablet
  column-width helpers.
- Ad failure never gates the shop: missing prices show the store
  placeholder, the free-coins button greys out, coin-priced packs still
  work offline.

## QA baked into the widgets

- Remove Ads is the first row; hidden when `adsRemoved` is true.
- Free-coins button is ≥ 44×44, greys out with a **text** label on cap
  (“come back tomorrow”) and cooldown (“available again in a few minutes”),
  plus “X/5 left today” when ready.
- Pack cards use `AnimatedScale` press feedback, `RepaintBoundary`, and a
  ≥ 44 pt price strip. In-flight purchases ignore extra taps.
- Store prices are wrapped in `Directionality.ltr` so Arabic layout mirrors
  but `$4.99` stays readable.
- Success / failure fire `GameKit.haptics` + `GameKit.sounds` (milestone vs
  invalid). Restore purchases remains the settings / IAP path.
