# Settings UI

Each game used to fork a settings list, then drift on restore, donate, and
“more games”. `GameKitSettingsBody` is **one widget tree**; look-and-feel comes
from `GameKitSettingsUiConfig`. Hosts own the scaffold and any extra rows
(profile, gameplay toggles).

`lib/src/settings/` · `GameKit.settingsUi` · optional on `GameKitConfig`

## Why this shape

Theming is config → `GameKitSettingsPalette` → widgets, same pattern as the
shop. `frosted` vs `opaqueLight` exists so a dark party game and a light puzzle
game share structure without sharing chrome.

`GameKit.updateSettingsUi` pushes through `settingsUiListenable` so a running
settings screen re-themes without rebuilding the host route.

RTL: kit dialogs wrap `Directionality` from `GameKit.locale`. Price chips stay
LTR. Confirm-button-on-visual-right in RTL is opt-in
(`confirmButtonOnRightInRtl`).

## What the body includes

Remove ads, restore, donate, rate, share, cross-promo (first in Support when
`showCrossPromo` is true), contact email + website, and an About card. Host
rows go above/below in the host `ListView`.

About is always on the list. It shows `ShareConfig.appName`, the installed
version, and `GameKitSettingsUiConfig.aboutDescription`. The description is a
required constructor argument: the host's localized blurb for the current
locale (the same role as Charades' `appDescription`). Call
`GameKit.updateSettingsUi` when the locale changes so the blurb switches
language. The version is read from the running binary (`PackageInfo`), which
Flutter writes from the app `pubspec.yaml` `version:` at build time.

Contact URLs: host override on the UI config → kit Remote Config → packaged
defaults (`office@majoonstudio.com`, `https://majoonstudio.com`).

## Known limits

- Settings does not persist toggles itself. The **Sound & vibration** section
  (**Sound effects** and **Vibration** rows) uses [PREFERENCES.md](PREFERENCES.md)
  (`soundsEnabled`, `vibrationsEnabled`) and gate **`GameKit.sounds`** /
  **`GameKit.haptics`** automatically.
- Cross-promo row hides when the catalog is empty (`hasPromoCatalog`).
- Until package info returns, About still shows the app name and description.
  The version number fills in on the same line once the binary version loads.
  Widget tests have no platform channel, so that number stays off the line.
