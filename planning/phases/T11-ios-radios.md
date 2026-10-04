# T11 — iOS radios

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T10  
**Next**: T12  
**Layer**: L6

## Description

iOS platform code for the T05 ports, and tests that assert the expected behavior. There is no `ios/` runner today. This task adds it. Assertions run against mocks on Linux until a Mac can execute them on a simulator or device.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Add the iOS runner without removing Linux, Android, macOS, or Windows
- [ ] BLE presence, control channel, and hotspot-or-failure behind the T05 interface. Wi-Fi Direct is not an iOS host mode
- [ ] Expected tests exist and pass under mock. They are not skipped and not reduced to a TODO
- [ ] Manual test section lists what to run on a Mac later

## Implementation Plan

### High-level notes (bootstrap)

- `flutter create --platforms=ios .` is the likely way to add the runner. Do not let it rewrite unrelated platforms
- Info.plist needs Bluetooth and local-network usage strings when those APIs are called

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

- Mocked iOS tests in `flutter test`
- Commands: `make verify`

## Acceptance Criteria

- [ ] iOS binding compiles as Dart and is asserted
- [ ] `make verify` still green on Linux
- [ ] Mac run steps are written in Manual test, not treated as done
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes

- T10 (2026-10-04): Windows mDNS advertise is Bonsoir, same as the other desktops. Do not copy a browse-only early return. Windows radios are a Win32 success-envelope stub (`bleUnavailable`, `hotspotFailed`, `wifiDirectFailed`), not a real BLE stack.
