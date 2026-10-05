# Share

“Tell a friend” copy used to be a hardcoded Arabic string in one game and
missing in others. `ShareModule` builds localized text
(`GameKitLocalizations.shareAppMessage`) plus the correct store URL for the
current platform.

`lib/src/share/` · `GameKit.share` · `ShareConfig`

## Why this shape

`appName` is required (also the default notification title). `iosAppId` and
`androidPackageName` build App Store / Play links. Missing iOS id on iOS
falls through to the Play URL rather than crashing. Promo-ads also send
`iosAppId` as `app_identifier` when `platform=ios`.

When `analyticsGameName` is set, `shareApp` logs host `share_tapped`. Omit it
if the host already logs share itself.

Uses `defaultTargetPlatform` / `kIsWeb`, not `dart:io` `Platform`.

## Known limits

- System share sheet only (`share_plus`). No custom cards or referral codes.
- Settings “Share the app” row is the usual entry; hosts may call `shareApp`
  from anywhere they have a `BuildContext`.
