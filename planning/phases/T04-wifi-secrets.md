# T04 — Remembered Wi-Fi and nearby settings

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T03  
**Next**: T05  
**Layer**: L2

## Description

Drift rows for SSIDs the user chose to remember, passphrases in the existing secret store, and settings for the visible switch (default on), idle minutes (default 3), members-can-invite (default on), and Shizuku-allowed (default off).

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-03 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-03 | execute started | Planned | InProgress | /task-2-execute T04 | user |
| 2026-10-03 | complete | InProgress | Done | /task-3-complete T04; verify re-confirmed 217 tests | agent |

## Requirements

- [x] Table: id, ssid, security (`wpa2-psk` or `wpa3-sae` only). No username, no enterprise, no passphrase column
- [x] Passphrase key lives in `SecretStore`. Write is refused when `usesSecureStorage` is false. The in-memory value can still be returned to the caller for this attempt
- [x] Remember checkbox is an explicit save. Default is not saved
- [x] Migration from the current schema. `dart run build_runner build` output committed
- [x] Tests: save/load round trip with `InMemorySecretStore(secure: true)`, and a failing write when `secure: false`

## Implementation Plan

### High-level notes (bootstrap)

- Follow `drift.mdc` and `security.mdc`
- Settings already use the database. Match that style for the four nearby keys (three bool + one int)

### Reality (from /task-1-plan)

- `schemaVersion` is **14**. `@DriftDatabase` lists 13 tables. No wifi/ssid/remembered table. No `nearby_*` settings keys.
- Settings API: `getSetting` / `setSetting` / `deleteSetting` in `lib/core/persistence/database.dart`. Bool pattern to copy: `peerSubnetFilterEnabled` / `setPeerSubnetFilterEnabled` (`'1'` / `'0'`, default `'1'`).
- `SecretStore` is in `lib/core/security/secret_store.dart`. Tests use `InMemorySecretStore(secure: …)`.
- **Trap:** `CompositeSecretStore.write` when `_secure == null` writes `secret_$key` into Drift. `SettingsSecretStore.write` always writes the settings table. `RememberedWifiStore` must check `usesSecureStorage` **before** calling `write`. Do not rely on the store to refuse.
- T03 Reality note still holds: wire PSK is `pskSeal`. Remembered SSIDs still must not store passphrase in Drift.

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-03
**Codebase snapshot:** T03 ✅ (`16d9701`) on branch `T04-wifi-secrets`. Drift `schemaVersion` 14, 13 tables, last migration `from < 14` adds `peers.stale`. Settings are key/value. Secret stores: `InMemorySecretStore`, `SettingsSecretStore` (sqlite), `CompositeSecretStore` (platform keyring, sqlite fallback). No remembered-wifi types. Nearby settings do not exist yet. `test/database_test.dart` asserts `schemaVersion == 14`.
**Execute model:** medium

### Context for executor

- **Goal:** Persist remembered SSIDs (id + ssid + security only) in Drift, keep the passphrase in `SecretStore` only when `usesSecureStorage` is true, and add four nearby settings with the INDEX defaults. No UI, no radios, no Shizuku read, no OS Wi-Fi join.
- **Key files:**
  - `lib/core/persistence/tables.dart` — add `RememberedNetworks`
  - `lib/core/persistence/database.dart` — schema 15, `createTable`, nearby getters/setters
  - `lib/core/persistence/database.g.dart` — regenerate, commit
  - `lib/core/security/remembered_wifi.dart` — **new**: `WifiSecurity`, `RememberedWifiSave`, `RememberedWifiStore`
  - `test/database_test.dart` — bump schema assertion `14` → `15`
  - `test/remembered_wifi_test.dart` — **new**
- **Invariants (from `drift.mdc` + `security.mdc`):**
  1. No passphrase column. No username. No enterprise / 802.1X columns.
  2. `SecretStore.write` for a PSK only if `usesSecureStorage == true`. Otherwise return the attempt value and do not write.
  3. Remember is explicit (`remember: false` default). Unchecked = no Drift row, no secret write.
  4. Never put a Wi-Fi passphrase, hotspot passphrase, or Shizuku output into SQLite, logs, BLE, or mDNS.
- **Allowed:** Drift, existing `SecretStore`, `package:uuid` (already used), `flutter_test`.
- **Forbidden:** `CompositeSecretStore` in tests (needs platform keyring). New HTTP stack. Nearby Connections. UI widgets. Changing `SecretStore` so `write` throws globally (device keys still need the sqlite fallback). Logging the passphrase.

### Types (`lib/core/security/remembered_wifi.dart`)

```dart
enum WifiSecurity {
  wpa2Psk('wpa2-psk'),
  wpa3Sae('wpa3-sae');

  const WifiSecurity(this.wire);
  final String wire;

  static WifiSecurity fromWire(String value) { /* … */ }
}

class RememberedWifiSave {
  const RememberedWifiSave({
    required this.networkId,      // null when remember == false
    required this.passphrase,     // always the attempt value (in memory)
    required this.passphrasePersisted,
  });
  final String? networkId;
  final String passphrase;
  final bool passphrasePersisted;
}

class RememberedWifiStore {
  RememberedWifiStore(this._db, this._secrets);
  // save / bySsid / passphraseFor / forget — see below
}
```

`fromWire`: accept only `'wpa2-psk'` and `'wpa3-sae'`. Anything else (`wpa-eap`, `wpa2-enterprise`, `open`, `none`, empty, unknown) → `ArgumentError`. Match T03 `ControlSecretBody.security` wire strings.

Secret key: `'wifi_psk_$networkId'` (id, not ssid — stable across SSID-unique upsert).

### `save` behavior

Signature:

```dart
Future<RememberedWifiSave> save({
  required String ssid,
  required WifiSecurity security, // or String; if String, call fromWire first
  required String passphrase,
  bool remember = false,
})
```

Prefer `WifiSecurity` in the signature so callers cannot pass enterprise without going through `fromWire`.

| `remember` | `usesSecureStorage` | Drift row | `secrets.write` | result |
| --- | --- | --- | --- | --- |
| false (default) | any | none | none | `networkId: null`, `passphrasePersisted: false`, passphrase returned |
| true | true | upsert by ssid | `wifi_psk_$id` | persisted true |
| true | false | upsert by ssid (metadata only) | **do not call write** | persisted false, passphrase still returned |

Also:

- Trim ssid. Empty ssid → `ArgumentError`.
- Empty passphrase → `ArgumentError` (do not persist an empty secret).
- Same ssid remembered again: reuse existing `id`, overwrite security, overwrite secret only if `usesSecureStorage`.
- New row id: `const Uuid().v4()` (same as `ensurePeerId`).

`passphraseFor(id)`: `readOrEmpty('wifi_psk_$id')`; return `null` if empty.

`bySsid(ssid)`: Drift lookup; does **not** attach the passphrase.

`forget(id)`: delete Drift row + `_secrets.delete('wifi_psk_$id')` (delete is always safe).

### Table (`tables.dart`)

Append after `Transfers` (end of file). Match existing style (`Shares` / `Peers`):

```dart
class RememberedNetworks extends Table {
  TextColumn get id => text()();
  TextColumn get ssid => text().unique()();
  TextColumn get security => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

**No** passphrase column. **No** username. **No** CHECK required (Dart `fromWire` is the gate). Do not add extra columns.

Drift table name will be `remembered_networks`.

### Database (`database.dart`)

1. Add `RememberedNetworks` to the `@DriftDatabase(tables: […])` list (after `Transfers`).
2. `schemaVersion => 15`.
3. In `onUpgrade`, after the `from < 14` block:

```dart
if (from < 15) {
  await migrator.createTable(rememberedNetworks);
}
```

`onCreate` already calls `createAll()` — new installs get the table. Do not rewrite older `from < N` blocks.

4. Nearby settings **on `AppDatabase`**, next to `peerSubnetFilterEnabled`. Exact keys and defaults:

| key | default | API |
| --- | --- | --- |
| `nearby_visible` | `'1'` (on) | `Future<bool> nearbyVisible()` / `setNearbyVisible(bool)` |
| `nearby_idle_minutes` | `'3'` | `Future<int> nearbyIdleMinutes()` / `setNearbyIdleMinutes(int)` |
| `nearby_members_can_invite` | `'1'` (on) | `Future<bool> nearbyMembersCanInvite()` / `setNearbyMembersCanInvite(bool)` |
| `nearby_shizuku_allowed` | `'0'` (off) | `Future<bool> nearbyShizukuAllowed()` / `setNearbyShizukuAllowed(bool)` |

Bool helpers: same as subnet filter (`raw != '0'` for the default-on keys; for Shizuku default-off use `raw == '1'` so missing key is false).

`setNearbyIdleMinutes`: `ArgumentError` if `minutes < 1`. No upper cap.

No writes on first read — defaults come from `getSetting(…, defaultValue: …)` so an unset key does not insert a row.

### Codegen

From repo root:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Commit `database.g.dart` with the table change. If analyze complains about missing `rememberedNetworks` getters, codegen did not run.

Bump `test/database_test.dart` `'opens at current schema version'` from `14` to `15`.

### Tests (`test/remembered_wifi_test.dart`)

Use `AppDatabase(NativeDatabase.memory())` in setUp/tearDown like `database_test.dart`. Distinctive passphrase token: `t04-psk-token` (not a realistic password). Never log it.

Cases:

1. **Defaults:** unset keys → `nearbyVisible() == true`, `nearbyIdleMinutes() == 3`, `nearbyMembersCanInvite() == true`, `nearbyShizukuAllowed() == false`.
2. **Settings round-trip:** set each, read back. `setNearbyIdleMinutes(0)` throws `ArgumentError`.
3. **remember false:** `save(…, remember: false)` with secure store → no row in `remembered_networks`, `secrets.readOrEmpty('wifi_psk_…')` empty, `networkId == null`, `passphrasePersisted == false`, returned passphrase equals input.
4. **round-trip secure:** `InMemorySecretStore(secure: true)`, `remember: true` → `bySsid` returns ssid + `WifiSecurity.wpa2Psk` (and a wpa3-sae case), `passphraseFor(id) == token`, `passphrasePersisted == true`.
5. **write refused insecure:** `InMemorySecretStore(secure: false)`, `remember: true` → Drift row exists (ssid + security), `passphraseFor` is null/empty, `passphrasePersisted == false`, returned passphrase equals input. Token must not appear in `SELECT * FROM remembered_networks` or `SELECT * FROM settings`.
6. **SettingsSecretStore refuse:** `RememberedWifiStore(db, SettingsSecretStore(db))`, `remember: true`, token `t04-psk-token` → after save, `customSelect('SELECT key, value FROM settings')` concatenated values must **not** contain the token. This is the production leak path if you call `write` without the gate.
7. **SQLite file dump:** temp file `NativeDatabase(File(path))`, save with `InMemorySecretStore(secure: true)` and `remember: true`, `db.close()`, read file bytes, `utf8.decode(bytes, allowMalformed: true)` must not contain `t04-psk-token`. Also assert `SELECT * FROM remembered_networks` has ssid/security and no extra columns named like passphrase/password/psk.
8. **Enterprise reject:** `WifiSecurity.fromWire('wpa-eap')`, `'wpa2-enterprise'`, `'open'` each throw `ArgumentError`. `save` is never reached.
9. **upsert:** remember same ssid twice with secure store → one row, same id, latest security + passphrase.

Do **not** construct `CompositeSecretStore` in tests.

### Steps

1. Add `RememberedNetworks` table; register it; set `schemaVersion` 15; add `from < 15` `createTable`. → verify: file compiles after step 2.
2. Run `dart run build_runner build --delete-conflicting-outputs`. → verify: `database.g.dart` contains `RememberedNetworks` / `rememberedNetworks`. `test/database_test.dart` expects `15`.
3. Add nearby getters/setters on `AppDatabase` with the four keys/defaults above. → verify: `flutter test test/remembered_wifi_test.dart` defaults + round-trip (write those tests first or with this step).
4. Add `lib/core/security/remembered_wifi.dart` with `WifiSecurity`, `RememberedWifiStore.save/bySsid/passphraseFor/forget`. Gate: `if (remember && _secrets.usesSecureStorage) await _secrets.write(...)` — never `write` otherwise. → verify: cases 3–9 in `test/remembered_wifi_test.dart` pass.
5. Lint + full verify. → verify: commands below green. No token in any committed file (`git grep t04-psk-token` should hit tests only).

### Tests to add

See cases 1–9 under Tests. Also bump schema assertion in `test/database_test.dart`.

### Verify commands

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/database_test.dart test/remembered_wifi_test.dart
make verify
```

`make verify` = `flutter analyze` + `flutter test` + `flutter build apk --debug`. Pre-commit is `make quick-verify` (analyze + test only).

### Risks / pitfalls

- **Calling `SecretStore.write` when `usesSecureStorage` is false.** `SettingsSecretStore` and insecure `CompositeSecretStore` persist the PSK in SQLite (`settings` / `secret_$key`). The store interface does **not** refuse. Your store class must skip `write`.
- **Putting passphrase in Drift** as a column or via `setSetting('wifi_psk', …)`. Forbidden. Secret key is only `wifi_psk_$id` inside SecretStore.
- **Using `CompositeSecretStore` in tests** — needs `FlutterSecureStorage` plugin. Use `InMemorySecretStore` and `SettingsSecretStore` only.
- **Forgetting codegen** — analyze will miss `rememberedNetworks`.
- **Changing `SecretStore.write` to throw** when insecure — would break device-key fallback. Gate only in `RememberedWifiStore`.
- **Default remember=true** — INDEX: remember is explicit; default is not saved.
- **Logging the token** in test failure messages is fine; do not `print` it from lib.

### Out of scope

- Settings UI / remember checkbox widget (T13)
- Reading OS Wi-Fi PSK (T07 Shizuku, T08 NetworkManager, T09 keychain)
- Hotspot / Wi-Fi Direct / join APIs (T06+)
- Control-frame `pskSeal` (done T03)
- Orchestrator wiring (T12)
- SchemaVerifier / drift migration test package
- Changing CompositeSecretStore fallback behavior

### Execute model recommendation

- **medium** — schema bump is mechanical, but one missed `usesSecureStorage` check silently writes the PSK into SQLite via `SettingsSecretStore` / Composite fallback. Executor must follow the gate table, not “just call write”.

## Test Plan

- `test/database_test.dart` — schema version 15
- `test/remembered_wifi_test.dart` — settings defaults, remember gate, dump, enterprise reject
- Commands: `flutter test test/database_test.dart test/remembered_wifi_test.dart` then `make verify`

## Acceptance Criteria

- [x] SQLite dump of a remembered network contains no passphrase
- [x] Enterprise security value is rejected
- [x] `make verify` green
- [x] No secrets committed

## Verification

*(Filled by `/task-2-execute`; re-confirmed by `/task-3-complete`)*

**Date:** 2026-10-03 (execute)

| Command | Result | Notes |
| ------- | ------ | ----- |
| `dart run build_runner build --delete-conflicting-outputs` | exit 0 | `database.g.dart` has `RememberedNetworks` |
| `flutter test test/database_test.dart test/remembered_wifi_test.dart` | exit 0 | schema 15 + 9 remembered-wifi cases |
| `make verify` | exit 0 | lint 0 issues; **217** tests (208 prior + 9); apk `build/app/outputs/flutter-apk/app-debug.apk`. Gradle/AGP/Kotlin deprecation warnings only — do not bump |
| `git grep t04-psk-token` | tests + plan only | token not in lib |
| `make verify` (close-out re-run) | exit 0 | lint 0; **217** tests; apk (`tmp/t04-complete-verify.log`) |

`RememberedWifiStore` never calls `SecretStore.write` unless `usesSecureStorage`. `SettingsSecretStore` leak test covers the sqlite fallback path.

## Files Modified

*(Filled by `/task-2-execute`)*

- `lib/core/persistence/tables.dart` — `RememberedNetworks` (id, ssid unique, security)
- `lib/core/persistence/database.dart` — schema 15, `from < 15` createTable, nearby settings
- `lib/core/persistence/database.g.dart` — regenerated
- `lib/core/security/remembered_wifi.dart` — `WifiSecurity`, `RememberedWifiStore`
- `test/database_test.dart` — schemaVersion 15
- `test/remembered_wifi_test.dart` — settings, remember gate, dump, enterprise
- `planning/phases/T04-wifi-secrets.md` — InProgress + verification
- `planning/phases/INDEX.md` — T04 InProgress

## Manual test (for humans)

Nothing on device — persistence only, no UI until T13. Unit proof:

```bash
flutter test test/remembered_wifi_test.dart
```

Expect 9 passing cases. Remembered row has ssid + `wpa2-psk`/`wpa3-sae` only. File sqlite dump must not contain `t04-psk-token`. `fromWire('wpa-eap')` throws.

## Learnings

- `SecretStore.write` does not refuse when `usesSecureStorage` is false — insecure stores dump into Drift. Gate at the remembered-Wi-Fi call site; do not make `write` throw globally (device-key fallback). Encoded in `security.mdc` + `drift.mdc`.

## Reality notes

- T03 control frames put PSK on the wire only as AEAD `pskSeal` after Accept. Remembered SSIDs here still must not store passphrase in Drift.
- Snapshot at plan: schemaVersion 14, no `remembered_networks`, no `nearby_*` keys. `CompositeSecretStore.write` sqlite-falls-back when the keyring is missing — T04 must not call `write` unless `usesSecureStorage` is true.
