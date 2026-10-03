# T03 — Sealed control frames

**Status**: Done  
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
| 2026-10-03 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-03 | execute started | Planned | InProgress | /task-2-execute T03 | user |
| 2026-10-03 | complete | InProgress | Done | /task-3-complete T03; verify re-confirmed 208 tests | agent |

## Requirements

- [x] Frame types for hello, invite, accept, decline, secret, host-failed, invite-member
- [x] A secret frame cannot be encoded before accept state
- [x] Round-trip tests with two in-memory identities from `lib/core/security/`
- [x] Decline encodes no passphrase
- [x] Advert struct (flags, IPv4, port, short id, role, group id) fits a 31-byte legacy advert budget. Nick is a separate scan-response field

## Implementation Plan

### High-level notes (bootstrap)

- Reuse `cryptography` and `device_identity.dart`. Do not invent a second key type
- GATT vs RFCOMM is a later transport. This task is the payload codec

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-03
**Codebase snapshot:** T02 ✅ on `T03-control-frames`. Policy lives in `lib/core/proximity/` (`HostStep`, `ProximityRole`, `HostMethod`). Identity: `DeviceIdentity.signUtf8` + `Ed25519` only (`lib/core/security/device_identity.dart`). Verify today is `HelloTransport.verifyHello` only — add a small `verifyUtf8` next to `signUtf8`. Private seed is SecretStore key `device_private_key` (base64). Tests: `InMemorySecretStore(secure: true)` then `DeviceIdentity(store).ensureIdentity()` (`test/security_test.dart:245`). `protocolVersion` is `1`. No BLE/GATT types. Do not add radio plugins.
**Execute model:** medium

### Context for executor

- **Goal:** Bytes for the pre-IP control channel: BLE advert pack (31-byte budget) + signed/sealed JSON frames. No sockets, no Flutter plugins, no Drift. T05 will send these bytes; T12 will drive session order.
- **Key files to create/edit** (filenames under `lib/core/proximity/` must contain `proximity`):
  - `lib/core/security/device_identity.dart` — add `verifyUtf8` (static) mirroring `HelloTransport.verifyHello`'s Ed25519 verify. Do **not** rewrite hello.
  - `lib/core/proximity/proximity_advert.dart` — 31-byte advert + nick scan-response
  - `lib/core/proximity/proximity_control_frames.dart` — frame types, session, encode/decode
  - `test/proximity_control_frames_test.dart`
- **Invariants:**
  1. Seal with **existing Ed25519 identity**. No second stored key type. X25519 below is **derived** from the Ed25519 seed, never written to SecretStore.
  2. Secrets (LAN/hotspot PSK) only after Accept. Decline has no passphrase field.
  3. Advert: flags, IPv4, port, short peer id, role, group id. Nick is **scan response only**. Never fingerprint or PSK in advert.
  4. Do not re-implement T02 badge/sheet policy. Invite body **carries** nick, code, host plan (`List<HostStep>`), link-plan booleans.
  5. No Nearby Connections. No system pairing dialog types.
- **Allowed:** `dart:convert`, `dart:typed_data`, `dart:math`, `package:cryptography`, `package:crypto` (sha256 already used). Tests: `flutter_test`.
- **Forbidden:** `dart:io` sockets, `package:flutter/…` in lib, `database.dart`, BLE plugins, putting a PSK in advert or decline.

### Advert (`proximity_advert.dart`)

Fixed **31-byte** packed payload. This **is** the AD payload budget T06 will stuff into manufacturer/service data. BLE AD type/length bytes are **not** added here (T05/T06). If you add a field and `pack().length != 31`, the size test must fail.

```
offset  size  field
0       1     flags
1       4     ipv4 (network order; 0.0.0.0 if none)
5       2     port uint16 BE (HTTPS peer port; 0 if none)
7       4     shortPeerId
11      1     role: 0=none, 1=owner, 2=member
12      4     groupId (0 = not in a group)
16      15    reserved, must be 0
```

**flags (bit0 = LSB):**

| bit | meaning |
| --- | ------- |
| 0 | hasIpv4 (ipv4 not 0.0.0.0) |
| 1 | hasWifi |
| 2–7 | 0 |

**shortPeerId:** UUID `peerId` with `-` stripped, take first 8 hex chars, decode to 4 bytes. (Same 8-char prefix idea as `mdns_service_name.dart`.)

**groupId:** 4 raw bytes. Tests may use `0x00000001`.

```dart
enum AdvertRole { none, owner, member }

class ProximityAdvert {
  const ProximityAdvert({
    required this.hasWifi,
    required this.ipv4, // 4 bytes
    required this.port,
    required this.shortPeerId, // 4 bytes
    required this.role,
    required this.groupId, // 4 bytes
  });
  final bool hasWifi;
  final List<int> ipv4;
  final int port;
  final List<int> shortPeerId;
  final AdvertRole role;
  final List<int> groupId;

  List<int> pack(); // always length 31
  static ProximityAdvert unpack(List<int> bytes); // throws FormatException if length != 31
}

class ProximityScanResponse {
  const ProximityScanResponse({required this.nick});
  final String nick;
  List<int> pack(); // utf8 nick, not counted in 31
  static ProximityScanResponse unpack(List<int> bytes);
}

List<int> shortPeerIdFromUuid(String peerId); // strip '-', first 8 hex → 4 bytes
```

`pack` sets flag bit0 iff ipv4 is not `[0,0,0,0]`. Reject ipv4 length != 4, shortPeerId != 4, groupId != 4, port not in 0..65535 with `ArgumentError`.

### Frames (`proximity_control_frames.dart`)

**Types (exact names):** `hello`, `invite`, `accept`, `decline`, `secret`, `hostFailed`, `inviteMember`.

Wire JSON envelope:

```json
{
  "v": 1,
  "type": "hello",
  "from": "<16-char fingerprint>",
  "x25519": "<base64 32-byte X25519 public, hello only; omit on other types>",
  "body": { },
  "sig": "<base64 Ed25519 signature>"
}
```

`v` must equal `protocolVersion` (1).

**Signature payload** (utf8, then `DeviceIdentity.signUtf8`):

```
'$v|$type|$from|${jsonEncode(body)}'
```

Do **not** include `sig` or `x25519` in the signed string. Body JSON key order = insertion order from your `toJson`. Keep `toJson` field order stable.

**Bodies:**

```dart
class ControlHelloBody {
  final String peerId;
  final String nick;
  final String publicKeyBase64; // Ed25519
}

class ControlInviteBody {
  final String nick;
  final String code; // 6 digits
  final List<HostStep> hostPlan;
  final bool useLanMine;
  final bool useLanTheirs;
  final bool usePrivateNetwork;
}

class ControlAcceptBody {
  const ControlAcceptBody();
}

class ControlDeclineBody {
  final String reason; // 'user' | 'timeout' — no psk field, ever
}

class ControlSecretBody {
  final String ssid;
  final String psk; // plaintext in memory; wire uses pskSeal only
  final String security; // 'wpa2-psk' | 'wpa3-sae'
  final String kind; // 'lan' | 'hotspot'
}

class ControlHostFailedBody {
  final String hostId;
  final HostMethod method;
}

class ControlInviteMemberBody {
  final String newFingerprint;
  final String nick;
  final String code;
}
```

`ControlFrame` tagged union or class with `type` + body. `toJson`/`fromJson` on bodies.

**Session:**

```dart
class ControlSession {
  bool accepted = false;
  String? peerFingerprint;
  String? peerEd25519PublicKeyB64;
  String? peerX25519PublicKeyB64;
}
```

Decode of `hello` **fills** the three peer* fields from the frame (`from`, `body.publicKeyBase64`, `x25519`). Decode of `accept` sets `accepted = true`. Decode of `decline` must **not** set accepted.

**Codec:**

```dart
class ControlFrameCodec {
  ControlFrameCodec(this.identity);
  final DeviceIdentity identity;

  Future<Map<String, dynamic>> encode(
    Object body, {
    required ControlSession session,
    List<int>? pskNonce, // 12 bytes; tests pass fixed; production Random.secure
  });

  Future<Object> decode(
    Map<String, dynamic> json, {
    required ControlSession session,
  });
}
```

`encode` infers type from body class. Steps: `ensureIdentity()`, build envelope without sig, sign payload, add `sig`. For `hello`, also add `x25519` (local derived public, see Seal).

**Secret gate:** `encode(ControlSecretBody, …)` throws `StateError` if `!session.accepted`. `decode` of type `secret` throws `StateError` if `!session.accepted` **before** opening the seal.

**Decline:** `ControlDeclineBody` has no psk/ssid. `toJson` keys are only `reason`. If encode is given a secret body as decline — it can't; wrong class.

**hostFailed / inviteMember:** no extra session gate (AC only gates secret).

### Seal (PSK confidentiality)

Do **not** persist an X25519 key. Derive from Ed25519 seed already in `device_private_key`:

```dart
// seed = base64Decode(await secrets.readOrEmpty('device_private_key'))
final material = sha256.convert([...seed, ...utf8.encode('blan-ctl-x25519-v1')]).bytes;
final x25519 = X25519();
final keyPair = await x25519.newKeyPairFromSeed(material);
```

ECDH: `x25519.sharedSecretKey(keyPair: local, remotePublicKey: SimplePublicKey(peerX25519Bytes, type: KeyPairType.x25519))`.

AEAD: `Chacha20.poly1305Aead()`. Nonce **12 bytes**. `SecretKey(await shared.extractBytes())`.

Wire `body.pskSeal` = base64(`nonce || mac.bytes || cipherText`). Do **not** put plaintext `psk` on the wire. `decode` as the recipient recovers `psk`. A third identity must fail `MacValidationException` or equivalent — test expects throw.

Hello without `x25519` cannot encode/decode secret (throw `StateError`).

Add `verifyUtf8` on `DeviceIdentity`:

```dart
static Future<bool> verifyUtf8({
  required String publicKeyBase64,
  required String message,
  required String signatureBase64,
}) async { /* same Ed25519.verify as HelloTransport.verifyHello */ }
```

Decode verifies `sig` with `body.publicKeyBase64` on hello, else `session.peerEd25519PublicKeyB64`. Fail → `FormatException('bad signature')`.

Export `proximity_types.dart` HostStep JSON: `{'hostId': id, 'method': 'hotspot'|'wifiDirect'}`. Add `HostStep.toJson`/`fromJson` on `HostStep` in `proximity_types.dart` (tiny, needed for invite hostPlan).

### Steps

1. Add `DeviceIdentity.verifyUtf8` + `HostStep.toJson`/`fromJson`. → verify: `make lint` clean on those files.
2. Implement advert pack/unpack + `shortPeerIdFromUuid`. → verify: `flutter test test/proximity_control_frames_test.dart --name advert`
3. Implement frame types + encode/decode without secret. Two `InMemorySecretStore` identities A/B: A hello → B decode fills session; B hello → A decode. Tamper `sig` → FormatException. → verify: `--name "frame round trip"`
4. Accept then secret: A encode secret after `session.accepted=true` and B's hello stored; B decode recovers `ssid`/`psk`/`security`/`kind`. Secret encode **before** accept throws. Decline JSON string contains no `psk` / `pskSeal` / `ssid`. Third store C cannot open A's secret to B. → verify: `--name secret`
5. Advert size test: `expect(pack().length, 31)` and a comment in the test: `// BLE legacy AD payload budget: 31 bytes`. Packing a 32nd payload byte is impossible if length is fixed — also `expect(unpack(pack(a)), matches a)`. Reserved tail all zeros. Nick only on `ProximityScanResponse`. → verify: `--name advert`
6. `flutter test test/proximity_control_frames_test.dart` then `make lint` then `make verify`. → verify: exit 0.
7. Fill Verification + Files Modified. No commit. No T04 schema.

### Tests to add

`test/proximity_control_frames_test.dart`. Two helpers:

```dart
Future<(DeviceIdentity, DeviceIdentityData, InMemorySecretStore)> ident() async {
  final s = InMemorySecretStore(secure: true);
  final d = DeviceIdentity(s);
  return (d, await d.ensureIdentity(), s);
}
```

**advert**

- UUID `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee` → strip dashes, first 8 hex `aaaaaaaa` → `[0xaa, 0xaa, 0xaa, 0xaa]`.
- Round-trip: hasWifi true, ipv4 `192.168.1.2`, port `59488`, role owner, groupId `[0,0,0,1]`.
- No address: ipv4 zeros, port 0, flag bit0 clear.
- `pack().length == 31`.
- `unpack` of 30 or 32 bytes throws FormatException.
- Scan response nick `'Ada'` round-trips; `advert.pack()` utf8 must **not** contain `'Ada'`.

**frame round trip**

- A hello / B hello exchange: fingerprints match `ensureIdentity`, nicks round-trip, `session.peerX25519PublicKeyB64` set.
- Invite: nick, code `'123456'`, hostPlan `[HostStep(hostId:'r', method: HostMethod.hotspot)]`, useLanMine true, others false.
- Accept then decline: decline reason `user`; `jsonEncode(encoded)` has no `psk`, `pskSeal`, `ssid`.
- hostFailed: hostId + `HostMethod.wifiDirect`.
- inviteMember: newFingerprint + nick + code.
- Bad sig: flip last char of `sig` → decode throws FormatException.

**secret**

- Before accept: `encode(ControlSecretBody(ssid:'s', psk:'x', security:'wpa2-psk', kind:'hotspot'))` throws StateError.
- After A↔B hello and `session.accepted = true` on both (or decode accept): encode secret with **fixed** 12-byte nonce `List.filled(12, 7)`; B decode `psk == 'x'`, `ssid == 's'`. Encoded JSON has `pskSeal`, not plaintext `'x'` as the psk field.
- Identity C hello/session cannot decode that secret (throws).
- Do **not** use a realistic passphrase string. `psk: 'x'` only.

### Verify commands

```bash
flutter test test/proximity_control_frames_test.dart
make lint
make test
make verify
```

### Risks / pitfalls

- BLE 31-byte budget is the **packed struct**, not JSON frames. Frames ride RFCOMM/GATT later.
- Including nick or fingerprint in `ProximityAdvert.pack` fails AC.
- Signing `jsonEncode` of a map with a `sig` key still inside — strip sig first.
- X25519 seed must be 32 bytes (`sha256` digest). Do not pass Ed25519 seed raw to `X25519.newKeyPairFromSeed` (different clamp).
- Do not write X25519 keys to SecretStore.
- `Chacha20.poly1305Aead` MAC is separate from cipherText — concatenate as specified or decode will fail across implementations.
- `HostStep.==` already exists; JSON round-trip must use `method` names `hotspot` / `wifiDirect`.
- Kotlin 2.2.20 Gradle warning is not a failure (T01/T02). Do not bump.
- T02 lesson: do not sleep; no network.

### Out of scope

- Radio sockets, BLE plugins, GATT MTU (T05+)
- Drift Wi-Fi rows / SecretStore PSK persistence (T04)
- Orchestrator, UI (T12–T13)
- Refactoring `HelloTransport` beyond optional one-line call to `verifyUtf8`
- Encrypting invite/hello bodies (identity keys are public by design)

### Execute model recommendation

- **medium** — codec + derived X25519 seal + advert layout. Not large: no platforms, APIs fully specified.

## Test Plan

- Codec tests only
- Commands: `flutter test` for the new file

## Acceptance Criteria

- [x] Tests show secrets are rejected before accept and accepted after
- [x] Advert size test fails if the packed struct exceeds 31 bytes of AD payload budget documented in the test
- [x] `make verify` green
- [x] No secrets committed

## Verification

*(Filled by `/task-2-execute`; re-confirmed by `/task-3-complete`)*

**Date:** 2026-10-03 (execute)

| Command | Result | Notes |
| ------- | ------ | ----- |
| `flutter test test/proximity_control_frames_test.dart` | exit 0 | 14 tests: advert, frame round trip, secret |
| `make lint` | exit 0 | "No issues found!" |
| `make test` | exit 0 | **208 passed** (194 prior + 14 new) |
| `make verify` | exit 0 | apk built; log `tmp/t03-verify.log`. Kotlin 2.2.20 deprecation warning only |
| `make verify` (close-out re-run) | exit 0 | lint 0; **208** tests; apk (`tmp/t03-complete-verify.log`) |

**Deviations from plan (security):**

- Hello `x25519` **is** included in the signed payload (`v|type|from|x25519|bodyJson`). Plan said omit it; leaving it unsigned lets a BT MITM swap the ECDH key and open the PSK. Encode/decode both use the same extra field (empty string when omitted).
- `encode(ControlAcceptBody)` sets `session.accepted = true` so the invitee can decode a later secret without decoding their own accept.

No `dart:io` / Flutter / Drift / BLE plugins in the new lib files. PSK on the wire is `pskSeal` only; tests use `psk: 'x'`.

## Files Modified

*(Filled by `/task-2-execute`)*

- `lib/core/security/device_identity.dart` — `verifyUtf8`, `ed25519Seed`
- `lib/core/proximity/proximity_types.dart` — `HostStep` JSON + `hostMethodFromName`
- `lib/core/proximity/proximity_advert.dart` — 31-byte pack + scan-response nick
- `lib/core/proximity/proximity_control_frames.dart` — codec, session, derived X25519 seal
- `test/proximity_control_frames_test.dart`
- `planning/phases/T03-control-frames.md` — InProgress + verification
- `planning/phases/INDEX.md` — T03 InProgress

## Manual test (for humans)

Nothing to test — codec only, no radio or UI until T05/T13. Unit proof:

```bash
flutter test test/proximity_control_frames_test.dart
```

Expect 14 passing cases. Secret before accept throws; after accept the wire JSON has `pskSeal` not plaintext `psk`.

## Learnings

- Unsigned ECDH public next to a signed body lets a control-link MITM steal a sealed PSK. Cover the sealing public key in the signature. Encoded in `security.mdc`.
- Session `accepted` must flip on encode(accept), not only decode — the local accept never returns through decode. Encoded in `proximity.mdc`.

## Reality notes

- T02 policy types reused for invite hostPlan. Packed advert is 31 bytes including 15 reserved zeros; nick is scan-response only. Hello `x25519` is derived from the Ed25519 seed (not stored) and is inside the signed transcript.
