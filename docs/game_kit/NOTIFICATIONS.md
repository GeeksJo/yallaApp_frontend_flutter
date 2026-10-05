# Notifications

Daily “come back” spam gets apps ignored or uninstalled. The kit schedules a
**sparse local** reminder (default Mon / Wed / Fri at **19:00** local), waits
**48 hours** after install, skips a day the player already opened, and
**stops after 3 ignored** scheduled days until they open the app again.

The same module receives **FCM** on the host `[DEFAULT]` Firebase app:
topic `all_users`, title + body only. See [FCM.md](FCM.md).

`lib/src/notifications/` · `GameKit.notifications` · `NotificationsConfig`

## Why this shape

Hosts pass Android channel id + optional copy. Title defaults to
`ShareConfig.appName`; body and channel strings default to kit l10n. That
avoids shipping English-only leftovers in Arabic apps.

`initialize` does not block first frame. Plugin failures are reported, not
thrown. Tests inject `GameKitConfig.notificationsService` and
`GameKitConfig.fcmClient`.

Hosts must call `markPlayedToday()` (or the kit equivalent after a session)
so “already played today” can skip that day’s fire. Permission should be
requested after first meaningful play, not on first launch - that is host
UI; the module only schedules (and subscribes to FCM topics) once allowed.

## Known limits

- FCM uses host `[DEFAULT]` Firebase, not the named `game_kit` app.
- Default weekdays are Mon/Wed/Fri, not the Arab-weekend Fri/Sun/Tue
  checklist. Override `days` / `hour` per product.
- Deep link into “today’s puzzle” is host routing; the local payload is a
  reminder, not a route table. FCM taps are a normal app launch.
