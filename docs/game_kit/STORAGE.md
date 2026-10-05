# Storage

Modules must not each invent a key prefix or pick Hive vs prefs at call
sites. `GameKitStorage` opens **one scoped `GameKitStore` per module**
(`game_kit.<module>.<key>`). Tests use `FakeStorage` / `inMemory`.

`lib/src/storage/` · `StorageConfig` on `GameKitConfig`

## Why this shape

| Backend | When |
|---------|------|
| `sharedPreferences` (default) | Lightweight flags, counts, timestamps |
| `hive` | Host already has an opened Hive box |
| `dualSharedPreferencesAndHive` | Read prefs then Hive; write both (migration) |

Hive backends require `Hive.init` / `openBox` **before** `GameKit.initialize`.

`Clock` is injectable on `GameKitConfig` so day-key and cooldown tests do
not depend on wall time.

## Known limits

- Dual store is for migration, not a sync protocol across devices.
- Sensitive secrets do not belong here; this is not secure storage.
