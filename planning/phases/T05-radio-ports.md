# T05 — Radio ports and fakes

**Status**: Done  
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
| 2026-10-03 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-03 | execute started | Planned | InProgress | /task-2-execute T05 | user |
| 2026-10-03 | complete | InProgress | Done | /task-3-complete T05; verify re-confirmed 226 tests | agent |

## Requirements

- [x] Interfaces cover start/stop advert, scan results, connect control channel, send frame, start/stop hotspot, start/stop Wi-Fi Direct group, join SSID, read current personal PSK
- [x] Fakes record calls and can fail hotspot, fail Wi-Fi Direct, and return no PSK
- [x] A fake-driven test runs the T02 host chain: hotspot fail → Wi-Fi Direct fail → next device
- [x] No new pub.dev radio plugin in this task. Platform tasks bind these interfaces

## Implementation Plan

### High-level notes (bootstrap)

- Put fakes under `test/` or `lib/.../fakes.dart` if later platform code must share them. Prefer `lib` only for the interface
- iOS, macOS, and Windows tests in later tasks must use these fakes rather than skipping

### Reality (from /task-1-plan)

- **No radio ports exist.** `lib/platform/PlatformServices` is multicast / foreground / SAF / nick only. Channels: `com.brukb.blan/platform`, `com.brukb.blan/sharing`. Do **not** stuff radios into `PlatformServices` — new abstracts. T06 binds Android.
- Host builder is `hostChain(...)` → `List<HostStep>` (`proximity_policy.dart`). No runtime fail-stepper. Session tests only assert list order. T05 adds `walkHostChain` over **per-device** `PrivateNetworkPort` fakes.
- Advert bytes: `ProximityAdvert.pack()` = 31-byte payload; nick = `ProximityScanResponse`. Control send payload = `ControlFrameCodec.encode` JSON map (`x25519` stays in the map).
- T04: schema 15, `RememberedWifiStore` / `WifiSecurity`. Radio ports may take SSID/PSK args. Do **not** call `RememberedWifiStore` here.
- pubspec: no BLE/Wi-Fi/Nearby Connections plugins. Do not add any.

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-03
**Codebase snapshot:** T04 ✅ (`8943ed3`) on `T05-radio-ports`. `lib/core/proximity/` has types, policy, invite queue, advert, control frames. Zero BLE/hotspot/WFD Dart ports. `PlatformServices` unrelated. `hostChain` is pure list order.
**Execute model:** medium

### Context for executor

- **Goal:** Dart ports + in-memory fakes so Linux tests can drive BLE advert/scan, a paired control channel, hotspot/WFD/join, and OS PSK read. One walker that executes T02 `hostChain` steps until a start succeeds. No Kotlin, no plugins, no T12 orchestrator (no invite UI, no trust writes, no HTTPS aim).
- **Key files to create** (names under `lib/core/proximity/` must contain `proximity`):
  - `lib/core/proximity/proximity_radios.dart` — abstracts, result types, `walkHostChain`
  - `lib/core/proximity/proximity_radio_fakes.dart` — in-memory impls (shared with T06/T09/T11 tests)
  - `test/proximity_radios_test.dart`
- **Do not edit:** `platform_services.dart`, `pubspec.yaml` (no new deps), `android/`, `RememberedWifiStore`, T02 policy functions.
- **Invariants:**
  1. No Nearby Connections. No system BT pairing dialog types.
  2. Advert payload is already packed 31 bytes; nick is scan-response only. Never fingerprint or PSK in advert bytes.
  3. Control `send` takes the codec JSON map as-is. Do not re-sign, strip `x25519`, or decode inside the port.
  4. PSK args stay in memory on the fake. Do not write Drift/settings/logs. Test token `t05-psk-token` only.
  5. WPA2/WPA3-Personal only (`WifiSecurity`). Join/OS-read APIs take that enum, not free-form enterprise strings.
  6. Missing OS PSK = `null` (fall through). Do not throw "abort".
- **Allowed in lib:** `dart:async`. Import existing `proximity_types.dart`, `proximity_advert.dart`, `remembered_wifi.dart` (`WifiSecurity` only).
- **Forbidden:** `dart:io` sockets, `package:flutter/services.dart` MethodChannel in these files, BLE/Wi-Fi plugins, `database.dart`, Nearby Connections.

### Types (`proximity_radios.dart`)

```dart
class BleScanHit {
  const BleScanHit({
    required this.advert,       // length 31
    required this.scanResponse, // utf8 nick pack; may be empty
    required this.peerHandle,   // opaque id for ControlChannelPort.connect
  });
  final List<int> advert;
  final List<int> scanResponse;
  final String peerHandle;
}

class HotspotCredentials {
  const HotspotCredentials({
    required this.ssid,
    required this.passphrase,
    required this.security,
  });
  final String ssid;
  final String passphrase;
  final WifiSecurity security;
}

class OsWifiNetwork {
  const OsWifiNetwork({
    required this.ssid,
    required this.passphrase,
    required this.security,
  });
  final String ssid;
  final String passphrase;
  final WifiSecurity security;
}

class PrivateNetworkException implements Exception {
  const PrivateNetworkException(this.method);
  final HostMethod method;
  @override
  String toString() => 'PrivateNetworkException($method)';
}

enum ControlTransport { rfcomm, gatt }

abstract class BlePresencePort {
  Future<void> startAdvert({
    required List<int> payload,      // must be length 31
    required List<int> scanResponse,
  });
  Future<void> stopAdvert();
  Future<void> startScan();
  Future<void> stopScan();
  Stream<BleScanHit> get scans;
}

abstract class ControlLink {
  ControlTransport get transport;
  Future<void> send(Map<String, dynamic> frame);
  Stream<Map<String, dynamic>> get incoming;
  Future<void> close();
}

abstract class ControlChannelPort {
  /// Client: classic RFCOMM first; if that throws, caller (T12) may retry GATT.
  /// T05 fake: `connect` honors [transport] and records it.
  Future<ControlLink> connect(String peerHandle, {required ControlTransport transport});
  Future<void> startListening();
  Future<void> stopListening();
  Stream<ControlLink> get inbound;
}

abstract class PrivateNetworkPort {
  Future<HotspotCredentials> startHotspot();
  Future<void> stopHotspot();
  Future<HotspotCredentials> startWifiDirect();
  Future<void> stopWifiDirect();
  Future<void> join({
    required String ssid,
    required String passphrase,
    required WifiSecurity security,
    required bool localOnly, // true = specifier path later (T06); fake only records
  });
  Future<void> leaveJoined();
}

abstract class OsPassphrasePort {
  /// Connected personal PSK, or null if missing / enterprise / denied / unsupported.
  Future<OsWifiNetwork?> readCurrentPersonalPsk();
}
```

`startAdvert`: `payload.length != ProximityAdvert.packedLength` → `ArgumentError`. Do not pack inside the port.

### `walkHostChain` (same file)

Not the orchestrator. Only private-network starts, in `hostChain` order. Each `HostStep.hostId` maps to **that device's** `PrivateNetworkPort` (two phones = two fake ports).

```dart
Future<HostStep?> walkHostChain({
  required List<HostStep> steps,
  required Map<String, PrivateNetworkPort> portsByHostId,
}) async {
  for (final step in steps) {
    final port = portsByHostId[step.hostId];
    if (port == null) {
      throw StateError('no PrivateNetworkPort for ${step.hostId}');
    }
    try {
      if (step.method == HostMethod.hotspot) {
        await port.startHotspot();
      } else {
        await port.startWifiDirect();
      }
      return step;
    } on PrivateNetworkException {
      continue;
    }
  }
  return null; // hostChainExhausted
}
```

Do **not** catch other exceptions. Do **not** call `stop*` here (T12 tears down). Do **not** skip WFD inside the walker — `hostChain()` already omitted illegal WFD steps.

### Fakes (`proximity_radio_fakes.dart`)

`FakeBlePresencePort`:
- `calls` = `List<String>` e.g. `startAdvert`, `stopAdvert`, `startScan`, `stopScan`
- `emit(BleScanHit hit)` after `startScan`
- `startAdvert` stores last payload/scanResponse; reject length != 31

`FakeControlLink` + `FakeControlChannelPort`:
- Static/helper `FakeControlPair.connect()`: two `FakeControlLink`s, each `send` adds to the other `incoming` stream. Transport recorded (`rfcomm` or `gatt`).
- `calls` records `connect:$peerHandle:$transport`, `send`, `close`, `startListening`, `stopListening`
- `inbound` can `emitInbound(FakeControlLink)` for host-side tests
- `send` must forward the map **by value** (`Map<String, dynamic>.from(frame)`) so tests can assert `x25519` still present

`FakePrivateNetworkPort`:
- Flags: `failHotspot = false`, `failWifiDirect = false`
- On fail: throw `PrivateNetworkException(method)` and still append the call
- On success hotspot: return `HotspotCredentials(ssid: 'fake-hotspot', passphrase: 't05-psk-token', security: WifiSecurity.wpa2Psk)`
- On success WFD: ssid `'fake-wfd'`, same token, `wpa2Psk`
- `join` records `{ssid, security.wire, localOnly}` — keep passphrase in a field `lastJoinPassphrase` for the attempt; do **not** put it in `calls` strings
- `calls`: `startHotspot`, `startWifiDirect`, `stopHotspot`, `stopWifiDirect`, `join:$ssid`, `leaveJoined`

`FakeOsPassphrasePort`:
- `next` nullable `OsWifiNetwork?` (default `null`)
- `calls` = `readCurrentPersonalPsk` (no secret in the string)

### Tests (`test/proximity_radios_test.dart`)

Use distinctive token `t05-psk-token`. Do not `print` it from lib.

1. **Advert size gate:** `startAdvert(payload: [0], …)` throws `ArgumentError`. Valid `ProximityAdvert.pack()` + `ProximityScanResponse(nick: 'Ada').pack()` records `startAdvert` / `stopAdvert`. After `startScan`, `emit` a hit; stream yields advert length 31. Unpack nick = `Ada`.
2. **Control round-trip:** two `DeviceIdentity` + `InMemorySecretStore(secure: true)` (same pattern as `test/proximity_control_frames_test.dart`). `ControlFrameCodec.encode(ControlHelloBody(...))` → `linkA.send(map)` → `linkB.incoming` first event. Decode on B. Assert wire map still has `x25519` (non-empty). `connect(..., transport: ControlTransport.gatt)` records gatt.
3. **Join records metadata only:** `join(ssid: 'Home', passphrase: token, security: wpa2Psk, localOnly: true)`. `calls` contains `join:Home` and does **not** contain the token.
4. **OS PSK miss:** default `readCurrentPersonalPsk()` is `null`. Set `next` to a network and read it back.
5. **Host chain hotspot→WFD→next (AC):**
   - `remote = AttemptDevice(id: 'R', kind: android)`, `local = AttemptDevice(id: 'L', kind: android)`
   - `steps = hostChain(local: local, remote: remote)`  
     Expect order already tested in T02: R hotspot, R wifiDirect, L hotspot, L wifiDirect.
   - `fakeR.failHotspot = true; fakeR.failWifiDirect = true;` `fakeL` succeeds hotspot.
   - `winner = await walkHostChain(steps: steps, portsByHostId: {'R': fakeR, 'L': fakeL})`
   - `winner == HostStep(hostId: 'L', method: HostMethod.hotspot)`
   - `fakeR.calls == ['startHotspot', 'startWifiDirect']`
   - `fakeL.calls == ['startHotspot']`
6. **All fail:** both fakes fail both methods → `winner == null`, each fake has both start calls.
7. **Desktop joiner (no WFD calls):** `hostChain` android remote + desktop local → steps are remote hotspot, local hotspot only. Walk with fakes that would succeed WFD if called. Assert neither fake's `calls` contains `startWifiDirect`.

Do **not** open a real radio. Do **not** construct `CompositeSecretStore`.

### Steps

1. Add `proximity_radios.dart` abstracts + `walkHostChain` + exception/result types. → verify: file analyzes (fakes next).
2. Add `proximity_radio_fakes.dart` with call logs and fail flags. → verify: `dart analyze lib/core/proximity/proximity_radio*.dart` clean.
3. Add `test/proximity_radios_test.dart` cases 1–7. → verify: `flutter test test/proximity_radios_test.dart`
4. Full gate. → verify: commands below. `git grep t05-psk-token` hits tests + this plan, not logs in lib `calls`.

### Tests to add

See cases 1–7. Especially case 5 (AC fallback order) and case 7 (walker does not invent WFD).

### Verify commands

```bash
flutter test test/proximity_radios_test.dart test/proximity_session_test.dart
make verify
```

`make verify` = analyze + test + debug apk. Do not bump Gradle/AGP/Kotlin (deprecation warnings only).

### Risks / pitfalls

- **One fake port for two hostIds.** Walker must index `portsByHostId[step.hostId]`. A single shared fake cannot prove "next device".
- **Re-implementing WFD skip in the walker.** That logic is `hostChain()`. If you skip WFD again, case 5 (two androids) never calls `startWifiDirect` on R.
- **Packing advert inside the port.** T06 stuffs manufacturer data; port takes raw 31 bytes.
- **Stripping `x25519` on send.** Control port is a pipe.
- **Logging/join-call strings containing the PSK.** Keep secrets off `calls`.
- **Adding plugins or MethodChannels.** T06's job.
- **Writing `RememberedWifiStore` from join/OS-read.** Persistence is T04; T12 decides remember.
- **Catching all exceptions in `walkHostChain`.** Only `PrivateNetworkException` is a fallback. A bug should surface.

### Out of scope

- Android/iOS/desktop radio impl (T06–T11)
- Shizuku / NetworkManager / keychain read (T07–T09)
- Orchestrator, trust DB, invite UI, HTTPS aim (T12–T13)
- Widening `PlatformServices`
- Nearby Connections
- Changing `hostChain()` policy
- Idle timer / disband (T12)

### Execute model recommendation

- **medium** — four ports + paired fake control + two-device walker. Easy to smash into one fake or re-code WFD skip. Not large: no platforms, APIs fully specified.

## Test Plan

- Fake host-chain test in `test/proximity_radios_test.dart`
- Commands: `flutter test test/proximity_radios_test.dart` then `make verify`

## Acceptance Criteria

- [x] Interfaces compile with no platform implementation required
- [x] Fallback order is asserted on the fake
- [x] `make verify` green
- [x] No secrets committed

## Verification

*(Filled by `/task-2-execute`; re-confirmed by `/task-3-complete`)*

**Date:** 2026-10-03 (execute)

| Command | Result | Notes |
| ------- | ------ | ----- |
| `flutter test test/proximity_radios_test.dart test/proximity_session_test.dart` | exit 0 | radio + session hostChain order |
| `make verify` | exit 0 | lint 0 after initializing-formal fix; apk built. Gradle/AGP/Kotlin deprecation warnings only |
| `flutter test test/proximity_radios_test.dart` (post-review) | exit 0 | **9** cases: mutate-after-send copy proof, close→emitsDone, StateError propagate |
| `make verify` (close-out re-run) | exit 0 | lint 0; **226** tests; apk (`tmp/t05-complete-verify.log`) |

`walkHostChain` uses `portsByHostId[step.hostId]`. Two-android AC: R hotspot+WFD fail → L hotspot. Desktop joiner: no `startWifiDirect`. Control fake copies the JSON map; hello `x25519` survives. `close` closes `tx`.

## Files Modified

*(Filled by `/task-2-execute`)*

- `lib/core/proximity/proximity_radios.dart` — ports + `walkHostChain`
- `lib/core/proximity/proximity_radio_fakes.dart` — in-memory impls
- `test/proximity_radios_test.dart`
- `planning/phases/T05-radio-ports.md` — InProgress + verification
- `planning/phases/INDEX.md` — T05 InProgress

## Manual test (for humans)

Nothing on device — fakes only, no radios until T06. Unit proof:

```bash
flutter test test/proximity_radios_test.dart
```

Expect 7 passing. Host chain: R hotspot fail, R WFD fail, L hotspot wins. Wire hello still has `x25519`.

## Learnings

- Host-chain walker must index private-network ports by `hostId` and continue only on a typed private-network failure — do not re-filter WFD or catch-all. Control `send` must copy the JSON map so sealing fields survive post-send mutation. Encoded in `proximity.mdc`.

## Reality notes

- BLE advert bytes: `ProximityAdvert.pack()` is already the 31-byte legacy payload; nick is `ProximityScanResponse`, not the advert. Do not invent a second layout.
- Control socket `send frame` carries `ControlFrameCodec` JSON maps. Do not re-sign or drop the hello `x25519` field — it is part of the signed transcript.
- T04 landed: Drift schemaVersion **15**, `RememberedNetworks` + `RememberedWifiStore` (`wifi_psk_$id` only when `usesSecureStorage`), nearby settings keys on `AppDatabase`. Radio ports may accept SSID/PSK args; do not re-implement remember/settings persistence here.
- `hostChain()` returns the step list only. T05 `walkHostChain` is the first runtime stepper; T12 will wrap it with control/trust/HTTPS. Two androids → R hotspot, R WFD, L hotspot, L WFD.
