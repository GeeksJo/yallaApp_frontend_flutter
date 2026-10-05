# Haptics

Buttons that sometimes vibrate and sometimes don’t feel like a broken
device. The kit exposes **semantic** methods (`validAction`, `invalidAction`,
`milestoneSuccess`, `lightTap`) so audio and haptics stay in lockstep across
games. Hosts rarely pick raw platform effects at the call site.

Also exposes **`lightImpact()`**, **`mediumImpact()`**, and **`heavyImpact()`**
when the caller wants a specific platform strength without tying it to a game
event.

`lib/src/haptics/` · `GameKit.haptics` · `HapticsConfig`

## Why this shape

`enabled` is the compile-time master switch. `isEnabled` is an optional
runtime gate (settings toggle). When the gate is null, only `enabled`
applies. Methods no-op when gated off - they do not throw.

Tests inject `GameKitConfig.hapticsClient`. Production uses
`DefaultHapticsClient` (the `vibration` package on Android and iOS).

`GameKit.initialize` AND-s `HapticsConfig.isEnabled` with
`GameKit.preferences.vibrationsEnabled` so the settings **Vibration** switch
actually mutes.

Package-owned UI (promo interstitial, force-update, app-moved) routes through
`GameKit.haptics` when initialized so the same preference applies.

## Default mapping

| Method | Duration | Amplitude | Typical use |
|--------|---------:|----------:|-------------|
| `lightTap()` / `lightImpact()` | 45 ms | 70 | Ordinary button tap |
| `validAction()` | 60 ms | 100 | Accepted move or selection |
| `milestoneSuccess()` / `mediumImpact()` | 140 ms | 170 | Level completion or reward |
| `invalidAction()` / `heavyImpact()` | 260 ms | 230 | Rejected move or strong cue |

The amplitude range is 1-255. The client queries `Vibration.hasAmplitudeControl()`
once; on unsupported devices or query failure it plays the same duration at
the system default amplitude. iOS uses Core Haptics on supported devices and
falls back to the system vibration on older devices. The settings switch gates
new cues immediately and cancels an active default-client vibration, including
cues waiting for capability detection.

Deprecated aliases (one release): `correctMove()` → `validAction()`,
`levelComplete()` → `milestoneSuccess()`.

## Known limits

- Sensation varies by device. Inject `hapticsClient` if you need custom patterns.
- No per-event override config yet - swap the whole client via
  `GameKitConfig.hapticsClient` for bespoke behavior.
- Android host apps must declare `android.permission.VIBRATE` in their main
  `AndroidManifest.xml`. The example app includes it.
