# T13 — Nearby UI

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T12  
**Next**: T14  
**Layer**: L7

## Description

Peers shows a Nearby section above the mDNS list with same-LAN, other-LAN, and BLE-only badges. Settings holds the visible switch, idle minutes, members-can-invite, and Shizuku. While this device hosts, Peers shows status and Disband (one confirm). The link sheet and short-code dialog use the orchestrator. No new rail destination.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Nearby rows are separate from mDNS rows and show the badge
- [ ] Tap runs the T02 outcomes: immediate open, sheet, or auto host
- [ ] Target dialog shows nick, code, host plan, and link plan
- [ ] Settings: visible default on, idle default 3, members can invite default on, Shizuku row matches the dead / missing / needs-permission copy
- [ ] Remember checkbox on the type-password sheet, default off
- [ ] Permission denial banner on Peers while the switch stays on
- [ ] Widget tests for badge text, sheet actions, and Disband confirm

## Implementation Plan

### High-level notes (bootstrap)

- Extend `lib/features/peers/peers_page.dart` and `lib/features/settings/`. Rail stays in `lib/app/shell.dart`
- Do not replace the existing peer menu (trust, forget, re-authenticate)

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

- Widget tests
- Commands: `flutter test` widget files and `make verify`

## Acceptance Criteria

- [ ] No new `NavigationRail` destination
- [ ] Widget tests cover the three badges and the password-skip path's call into the orchestrator
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes

- T12 (2026-10-05): `ProximityOrchestrator` is live. `lib/app/app.dart` passes `production()` except on web. `providers.dart` stays `AppService(db)`. Widget tests must not call `production()` — Linux opens the system bus.
- Call the orchestrator. Do not construct platform radios from the UI, and do not reorder `hostChain`.
- `presentInvite` is `(nick, code)`. Android keeps one `AndroidInvitePresenter`, shows that nick and code, and applies `inviteResults` (`accept` / `decline`) to the queue. Desktop and iOS `present()` only raise the window. The Accept dialog is this task.
- `checkIdle` is not on a timer. A Disband control calls `disband()`. If a timer is added, refresh in-use counts first. Clients and in-flight transfers keep the network up.
