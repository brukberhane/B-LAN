# T05 — Radio ports and fakes

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T04  
**Next**: T06  
**Layer**: L4

## Description

Dart interfaces for BLE advert/scan, the control socket, hotspot, Wi-Fi Direct, LAN join, and OS passphrase read. In-memory fakes implement them so the orchestrator and UI can be tested on Linux without radios.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Interfaces cover start/stop advert, scan results, connect control channel, send frame, start/stop hotspot, start/stop Wi-Fi Direct group, join SSID, read current personal PSK
- [ ] Fakes record calls and can fail hotspot, fail Wi-Fi Direct, and return no PSK
- [ ] A fake-driven test runs the T02 host chain: hotspot fail → Wi-Fi Direct fail → next device
- [ ] No new pub.dev radio plugin in this task. Platform tasks bind these interfaces

## Implementation Plan

### High-level notes (bootstrap)

- Put fakes under `test/` or `lib/.../fakes.dart` if later platform code must share them. Prefer `lib` only for the interface
- iOS, macOS, and Windows tests in later tasks must use these fakes rather than skipping

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

- Fake host-chain test
- Commands: `flutter test` for the new file

## Acceptance Criteria

- [ ] Interfaces compile with no platform implementation required
- [ ] Fallback order is asserted on the fake
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes

- BLE advert bytes: `ProximityAdvert.pack()` is already the 31-byte legacy payload; nick is `ProximityScanResponse`, not the advert. Do not invent a second layout.
- Control socket `send frame` carries `ControlFrameCodec` JSON maps. Do not re-sign or drop the hello `x25519` field — it is part of the signed transcript.
- T04 landed: Drift schemaVersion **15**, `RememberedNetworks` + `RememberedWifiStore` (`wifi_psk_$id` only when `usesSecureStorage`), nearby settings keys on `AppDatabase`. Radio ports may accept SSID/PSK args; do not re-implement remember/settings persistence here.

