# T03 — Sealed control frames

**Status**: Pending  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T02  
**Next**: T04  
**Layer**: L3

## Description

Bytes for the pre-IP channel. Identity handshake, then nick, code, link plan, and host plan. LAN and hotspot secrets only in a frame that exists after Accept. Sealed with the existing Ed25519 device keys. No Bluetooth pairing dialog and no Nearby Connections.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |

## Requirements

- [ ] Frame types for hello, invite, accept, decline, secret, host-failed, invite-member
- [ ] A secret frame cannot be encoded before accept state
- [ ] Round-trip tests with two in-memory identities from `lib/core/security/`
- [ ] Decline encodes no passphrase
- [ ] Advert struct (flags, IPv4, port, short id, role, group id) fits a 31-byte legacy advert budget. Nick is a separate scan-response field

## Implementation Plan

### High-level notes (bootstrap)

- Reuse `cryptography` and `device_identity.dart`. Do not invent a second key type
- GATT vs RFCOMM is a later transport. This task is the payload codec

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

- Codec tests only
- Commands: `flutter test` for the new file

## Acceptance Criteria

- [ ] Tests show secrets are rejected before accept and accepted after
- [ ] Advert size test fails if the packed struct exceeds 31 bytes of AD payload budget documented in the test
- [ ] `make verify` green
- [ ] No secrets committed

## Verification

## Files Modified

## Manual test (for humans)

## Learnings

## Reality notes
