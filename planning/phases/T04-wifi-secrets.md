# T04 — Remembered Wi-Fi and nearby settings

**Status**: Pending  
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

## Requirements

- [ ] Table: id, ssid, security (`wpa2-psk` or `wpa3-sae` only). No username, no enterprise, no passphrase column
- [ ] Passphrase key lives in `SecretStore`. Write is refused when `usesSecureStorage` is false. The in-memory value can still be returned to the caller for this attempt
- [ ] Remember checkbox is an explicit save. Default is not saved
- [ ] Migration from the current schema. `dart run build_runner build` output committed
- [ ] Tests: save/load round trip with `InMemorySecretStore(secure: true)`, and a failing write when `secure: false`

## Implementation Plan

### High-level notes (bootstrap)

- Follow `drift.mdc` and `security.mdc`
- Settings already use the database. Match that style for the three bool/int keys

## Execution plan (filled by /task-1-plan)

**Date:**  
**Codebase snapshot:**  
**Execute model:**

### Context for executor
- …

### Steps
1. … → verify: …

### Tests to add
- …

### Verify commands
- …

### Risks / pitfalls
- …

### Out of scope
- …

### Execute model recommendation
- …

## Test Plan

- Drift tests beside `test/database_test.dart`
- Commands: `flutter test test/database_test.dart` and `make verify`

## Acceptance Criteria

- [ ] SQLite dump of a remembered network contains no passphrase
- [ ] Enterprise security value is rejected
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes

- T03 control frames put PSK on the wire only as AEAD `pskSeal` after Accept. Remembered SSIDs here still must not store passphrase in Drift.

