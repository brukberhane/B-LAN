# T08 — Linux radios

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T07  
**Next**: T09  
**Layer**: L6

## Description

Linux bindings for the T05 ports: BlueZ BLE advert/scan and a GATT fallback, classic Bluetooth when available, NetworkManager hotspot, `nmcli --show-secrets` for the current personal PSK, and a window for an invite while the UI is paused. No Wi-Fi Direct group owner.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Current PSK read uses NetworkManager secrets for a user-owned WPA2/WPA3-Personal profile. No sudo. Polkit may prompt. iwd-only returns empty and the caller types or falls through
- [ ] Hosting starts a local-only hotspot and stops it on idle or Disband. Failure returns the T05 error so the orchestrator tries the next device
- [ ] Desktop invite raises the app window
- [ ] Tests fake NetworkManager and BlueZ. A live adapter is not required for `make verify`

## Implementation Plan

### High-level notes (bootstrap)

- Do not implement Wi-Fi Direct as a Linux host mode
- Joining an Android Wi-Fi Direct group is out of scope. The session layer skips that fallback when a desktop must join

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

- Fake NM/BlueZ tests
- Commands: `make verify`

## Acceptance Criteria

- [ ] Secret read failure is empty, not an exception that aborts the attempt
- [ ] Hotspot failure is observable on the port
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes
