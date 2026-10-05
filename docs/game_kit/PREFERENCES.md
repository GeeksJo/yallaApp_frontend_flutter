# Preferences

Sound effects and vibration need toggles that **survive restart** and
actually mute `GameKit.sounds` / `GameKit.haptics`. Those flags are kit-owned
so settings, shop, and gameplay do not each keep a copy.

`lib/src/preferences/` · `GameKit.preferences`

## Why this shape

The module persists **`soundsEnabled`** and **`vibrationsEnabled`** (both
default `true`). `GameKit.initialize` AND-s them into `SoundConfig.isEnabled`
and `HapticsConfig.isEnabled`. Changing a toggle via `setSoundsEnabled` /
`setVibrationsEnabled` updates a `ValueNotifier` immediately, then disk.
The next sound or haptic call uses the new value without reinitializing the
kit or restarting the app. Disabling sound also stops an active countdown
urgency cue.

The settings **Vibration** row controls **`vibrationsEnabled`** and gates
**`GameKit.haptics`**.

## Known limits

- No locale or theme keys yet. Do not overload this module with host profile
  data.
