# T07 — Android Shizuku passphrase read

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T06  
**Next**: T08  
**Layer**: L6

## Description

Read the current WPA2/WPA3-Personal passphrase through Shizuku or Shevery, using the same provider detection as SecureSettingsManager. If that cannot run, the caller types a password or the attempt falls through. This task does not grant overlay permissions via Shizuku.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Detect `com.hamondev.shevery`, `moe.shizuku.privileged.api`, `moe.shizuku.manager`, then the permission / provider / receiver scan from `ShizukuManager.kt`
- [ ] States: unknown, ready, no permission, dead, not installed. Sticky binder listeners. Pre-v11 reported too old
- [ ] One-time ask when a password is needed and the binder is up. Persisted in the T04 Shizuku-allowed setting
- [ ] Privileged `WifiManager` read of the connected or saved personal network. Not `WRITE_SECURE_SETTINGS`. Not the SecureSettingsManager "start after unlock" flow
- [ ] Tests with a fake binder: found Shevery package, permission denied, dead, and a returned PSK that never touches Drift

## Implementation Plan

### High-level notes (bootstrap)

- Reference file: `/home/brukb/projects/Android/SecureSettingsManager/app/src/main/java/com/secure/settings/manager/core/shizuku/ShizukuManager.kt`
- Spoke: `shizuku.mdc`

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

- Fake-binder tests on the Linux host
- Commands: `flutter test` and `make verify`

## Acceptance Criteria

- [ ] Shevery package is recognized, not only official Shizuku
- [ ] PSK from the fake never appears in a Drift insert
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes
