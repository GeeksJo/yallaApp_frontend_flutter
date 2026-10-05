# Sounds

The same semantic API as haptics, with bundled WAV cues, so a valid move is
never “haptic only” in one game and “sound only” in another. Cues **pre-load
on init** (not awaited on the first frame) and **never crash** - missing file
or platform error is skipped (debug log only).

`lib/src/sound/` · `GameKit.sounds` · `SoundConfig` · `assets/sounds/`

## Why this shape

| Method | Default cue | Typical use |
|--------|-------------|-------------|
| `validAction` | `valid.wav` | Correct move |
| `invalidAction` | `invalid.wav` | Error / fail |
| `correctAction` | `correct.mp3` | Alternate correct / success cue |
| `errorAction` | `error.mp3` | Alternate error / failure cue |
| `milestoneSuccess` | `milestone.wav` | Win / level-up - not GO |
| `lightTap` | `tap.wav` | UI tap |
| `countdownTick` | `tick.wav` | 3-2-1 beats |
| `go` | `go.wav` | Answer phase start |
| `startCountdownUrgency` / `stopCountdownUrgency` | `countdown.wav` | Sustained bed; **always stop** on early exit; the kit also stops it when sound is disabled |

Override per event with `GameKitSound.bundled` / `.asset` / `.none`. Swap the
engine with `soundClient` (tests).

`respectSilentMode` defaults **true** (honor iOS Ring/Silent, mix with
music). Games that must play SFX through the silent switch set it `false`.
Android always mixes without taking audio focus.

`GameKit.initialize` AND-s `SoundConfig.isEnabled` with
`GameKit.preferences.soundsEnabled` so the settings toggle actually mutes.

Pair with [`GameKit.haptics`](HAPTICS.md) at the same game events when you want
multi-modal feedback.

## Known limits

- Not a music / BGM engine. No ducking of other apps beyond mix-with-others.
- Widget tests skip preload (`_inWidgetTest`) so `audioplayers` does not hang.
