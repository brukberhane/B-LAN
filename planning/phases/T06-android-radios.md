# T06 — Android radios and invite UI

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T05  
**Next**: T07  
**Layer**: L6

## Description

Android implementation of the T05 ports: BLE advert and scan, classic Bluetooth with GATT fallback, local-only hotspot, Wi-Fi Direct group, and joining a network. Background invite is a dialog over the current screen when display-over-apps and full-screen intent are granted, otherwise a heads-up with Accept and Decline.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Foreground: advert + scan while the visible switch is on. Sharing foreground service: advert only, still accepts control invites
- [ ] Hotspot via `startLocalOnlyHotspot`. Use `startLocalOnlyHotspotWithConfiguration` when the public API exists. Credentials from the reservation go out only as a post-accept control frame
- [ ] If hotspot start fails, `WifiP2pManager` group. Only the group owner admits. System P2P dialog may follow our short code
- [ ] Join path: `WifiNetworkSpecifier` for the local-only hotspot, system suggestion for a normal LAN. No silent STA switch
- [ ] Permissions requested on first foreground start with the switch on: Bluetooth advertise/scan/connect, nearby Wi-Fi, notifications, overlay, full-screen intent. Denial leaves the switch on and is visible to the UI task
- [ ] Host spin-up surfaces that current Wi-Fi may pause
- [ ] Unit tests use fakes for policy. Platform channel tests mock the Android side where the Linux host cannot open a radio

## Implementation Plan

### High-level notes (bootstrap)

- Read `android-wifi.mdc` and `proximity.mdc` before editing `android/`
- Do not add Google Nearby Connections
- Shizuku PSK read is T07

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

- Mocked channel tests plus `make verify`
- Commands: `flutter test` and `make verify`

## Acceptance Criteria

- [ ] Dart calls map to the T05 interface with no policy reimplementation
- [ ] Overlay denial still produces a notification action path
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes

- T05 ports live in `lib/core/proximity/proximity_radios.dart` (`BlePresencePort`, `ControlChannelPort`, `PrivateNetworkPort`, `OsPassphrasePort`) with fakes in `proximity_radio_fakes.dart`. Bind Android to those abstracts — do not widen `PlatformServices`.
- Advert in = already-packed 31-byte `ProximityAdvert.pack()`; nick = scan-response bytes. Control `send` forwards codec JSON maps as-is (keep `x25519`).
- `walkHostChain` is the fail-stepper; policy WFD skip stays in `hostChain()`. OS PSK miss returns `null` (fall through). Shizuku bind is T07, not this task.
- Unit tests on Linux keep using T05 fakes; mock MethodChannels only where the host cannot open a radio.
