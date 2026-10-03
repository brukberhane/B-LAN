# T09 — macOS radios

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T08  
**Next**: T10  
**Layer**: L6

## Description

macOS implementation of the T05 ports, plus expected tests. Radio and keychain calls are mocked so `make verify` passes on Linux. A Mac later runs the same assertions against the real runner.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Keychain read of the AirPort password for the current SSID, which raises Touch ID or a password prompt. No sudo
- [ ] BLE advert/scan and control channel behind the T05 interface. Hotspot host is best-effort and returns the port failure when the OS will not start one
- [ ] Invite raises a window
- [ ] Tests name the expected keychain and hotspot outcomes and run them through fakes here. No `skip:` that deletes the expectation

## Implementation Plan

### High-level notes (bootstrap)

- This Linux checkout cannot open CoreBluetooth. Do not weaken assertions to "not run"
- WPA2/WPA3-Personal only

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

- Mocked macOS channel tests included in `flutter test`
- Commands: `make verify`

## Acceptance Criteria

- [ ] Expected macOS behaviors are asserted on fakes
- [ ] Real device checks are listed in the manual-test section, not omitted from the suite
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes
