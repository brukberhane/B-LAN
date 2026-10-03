# T10 — Windows radios

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T09  
**Next**: T11  
**Layer**: L6

## Description

Windows implementation of the T05 ports at best effort: BLE presence, control channel, and a hotspot when the OS API allows it. Failures surface on the port so the host chain moves on. Tests are mocked and still assert the expected calls.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Implements the same Dart interface as Android and Linux
- [ ] Does not advertise mDNS. Existing Windows browse-only limit stays
- [ ] No Wi-Fi Direct host mode
- [ ] Tests lock the fallback: hotspot failure is a port error, not a thrown UI string

## Implementation Plan

### High-level notes (bootstrap)

- Keep Windows-specific code in the windows runner and a Dart binding. Policy stays in T02

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

- Mocked Windows binding tests
- Commands: `make verify`

## Acceptance Criteria

- [ ] Port methods exist and are covered by fakes
- [ ] mDNS advertise is still off on Windows
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes
