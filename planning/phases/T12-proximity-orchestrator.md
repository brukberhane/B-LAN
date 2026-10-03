# T12 — Proximity orchestrator

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T11  
**Next**: T13  
**Layer**: L4

## Description

Wires the session rules to the radio ports, mDNS `/hello`, trust storage, and the existing HTTPS client. After a private link is up, transfers use the address from the control channel. Spin-up is the only host-failure path. In-flight LAN transfers on a dropped interface pause and use the existing retry. They are not moved onto a new group owner mid-session.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] App start follows the visible switch and foreground vs background advertise rules
- [ ] Same-LAN success does not start a hotspot
- [ ] Password miss calls the host chain. Short-code decline does not
- [ ] Idle timer (settings minutes, default 3) and Disband close hotspot or Wi-Fi Direct. Switch off stops advert only. Associated clients and running transfers keep the network up
- [ ] Third device that sees a host or joiner joins that group instead of starting one. Wi-Fi Direct relays to the owner. Hotspot members forward the PSK only after accept when the setting allows
- [ ] Round-robin includes only devices already in the attempt
- [ ] Tests drive fakes through same-LAN, password fallthrough, all-hosts-fail, and member invite

## Implementation Plan

### High-level notes (bootstrap)

- Hook from `AppService.initialize` / resume / `shutdownSharing`. Do not start a second long-lived isolate
- HTTPS client stays `transfer_client.dart` / pinned client. Pass the new base URL in

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

- Orchestrator tests with fakes
- Commands: `make verify`

## Acceptance Criteria

- [ ] No file bytes on the control channel
- [ ] All-fail stops without a retry loop
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes

- T02 shipped `lib/core/proximity/` (pure policy + `InviteQueue`). Call it; do not re-decide badges/sheets/host order.
- `InviteQueue.tick` expires from `enqueuedAt`, not promote time. After a 60s active dialog, a waiter can decline on the next tick unless you reset the clock on promote or only tick the active window.
- Host chain already skips Wi-Fi Direct when any non-host is desktop/iOS. Do not re-add those steps in the orchestrator.
