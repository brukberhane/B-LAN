# T02 — Proximity session rules

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T01  
**Next**: T03  
**Layer**: L3

## Description

Pure Dart model of a nearby attempt: badges, link sheet, host choice, password fallthrough, invite queue, and trust outcomes. No radio, no UI. Later tasks call this instead of re-deciding policy.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Badges: Same LAN only after local-subnet IPv4 and `/hello` success; Other LAN when an address is advertised but that check fails; BLE only otherwise
- [ ] Untrusted non-LAN tap yields a sheet: Use a Wi-Fi LAN (mine or theirs, hide a side with no Wi-Fi; if neither has Wi-Fi the action is absent) or Private network
- [ ] Host pick defaults to the other device. Android failure order per device: hotspot, then Wi-Fi Direct, then the next device already in the attempt. Desktop: hotspot only. Desktop joiner skips Wi-Fi Direct. Every candidate failing ends the attempt
- [ ] Missing or refused LAN password falls through to that chain. Short-code decline and leaving the sheet before a choice abort and store nothing
- [ ] Trusted same-LAN opens immediately. Trusted different-LAN shows the sheet without a code. Trusted and neither on Wi-Fi skips the sheet
- [ ] One invite at a time, others wait, 60s timeout declines. Six-digit code is minted by the initiator
- [ ] Member invite trusts only the admitter and the new fingerprint. Wi-Fi Direct admit is owner-only. Hotspot invite may forward credentials only after accept and only when members-can-invite is on
- [ ] Table-driven tests cover each row above. No platform plugins

## Implementation Plan

### High-level notes (bootstrap)

- Rules: `.cursor/rules/proximity.mdc`
- Do not import Flutter bindings or `dart:io` sockets here if a pure library file can hold the types

## Execution plan (filled by /task-1-plan)

**Date:**  
**Codebase snapshot:**  
**Execute model:** small/default | large (only if justified)

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
- default (small/cheap) | large — rationale: …

## Test Plan

- Package tests for the matrix, host chain, queue, and abort vs fallthrough
- Commands: `flutter test` on the new file, then `make lint` at least

## Acceptance Criteria

- [ ] Requirements covered by tests that fail if a branch is dropped
- [ ] No Android/Linux/BLE calls in this layer
- [ ] Full `make verify` green
- [ ] No secrets committed

## Verification

*(Filled by `/task-2-execute`)*

## Files Modified

*(Filled by `/task-2-execute`)*

## Manual test (for humans)

*(Filled by `/task-3-complete`)*

## Learnings

*(Filled by `/task-3-complete`)*

## Reality notes
