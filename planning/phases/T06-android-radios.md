# T06 — Android radios and invite UI

**Status**: Done  
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
| 2026-10-03 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-03 | execute started | Planned | InProgress | /task-2-execute T06 | user |
| 2026-10-03 | review fixes + close-out | InProgress | Done | reviewer findings folded (4 red, 15 yellow), /task-3-complete T06 | user |

## Requirements

- [ ] Foreground: advert + scan while the visible switch is on. Sharing foreground service: advert only, still accepts control invites
- [ ] Hotspot via `startLocalOnlyHotspot`. Use `startLocalOnlyHotspotWithConfiguration` when the public method exists. Credentials from the reservation go out only as a post-accept control frame
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

### Reality (from /task-1-plan)

- Android tree: `MainActivity.kt` (channels `com.brukb.blan/platform` + `/sharing`, 15 handlers), `BlanForegroundService.kt` (channel `blan_tasks`, task `transfer-server`, `dataSync` type), `SharingStopReceiver.kt`. No BLE/hotspot/overlay/FSI code, no radio permissions.
- SDK: minSdk **24**, targetSdk/compileSdk **36** (Flutter defaults). API 33+ needs `NEARBY_WIFI_DEVICES` neverForLocation + `BLUETOOTH_ADVERTISE/SCAN/CONNECT`; pre-33 substitute is `ACCESS_FINE_LOCATION` (maxSdk 32), pre-31 BT is `BLUETOOTH`/`BLUETOOTH_ADMIN` (maxSdk 30).
- No `setMockMethodCallHandler` usage in tests yet — T06 introduces it for the proximity channel.
- `permission_handler` used only for notifications today (`AndroidPlatformServices.requestNotificationPermission`).
- T05 ports + fakes in `lib/core/proximity/proximity_radios.dart` / `proximity_radio_fakes.dart`. Fakes stay the Linux test path; T06 adds channel-mock tests for the Android impl class only.

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-03
**Codebase snapshot:** T05 ✅ (`3fceea9`) on `T06-android-radios`. Ports live in `lib/core/proximity/proximity_radios.dart`. Android has zero radio code. Manifest has 8 permissions, none radio.
**Execute model:** large — five Kotlin subsystems + channel plumbing + invite UI + tests in one task.

### Context for executor

- **Goal:** Bind the four T05 ports to real Android radios behind one new MethodChannel, and surface invites as full-screen dialog or heads-up. Linux runs only Dart-level channel-mock tests; real radio behavior is device-manual (T14).
- **Key files to create:**
  - `lib/platform/android/android_proximity_radios.dart` — `AndroidProximityRadios` implementing `BlePresencePort`, `ControlChannelPort`, `PrivateNetworkPort`, `OsPassphrasePort`; plus `AndroidInvitePresenter` (dialog/heads-up trigger + result stream)
  - `android/app/src/main/kotlin/com/brukb/blan/proximity/ProximityPlugin.kt` — channel host, method dispatch
  - `android/app/src/main/kotlin/com/brukb/blan/proximity/BleRadio.kt` — advert + scan
  - `android/app/src/main/kotlin/com/brukb/blan/proximity/ControlRadio.kt` — RFCOMM + GATT link
  - `android/app/src/main/kotlin/com/brukb/blan/proximity/WifiRadios.kt` — hotspot + WFD + join
  - `android/app/src/main/kotlin/com/brukb/blan/proximity/InviteActivity.kt` — full-screen invite dialog
  - edits: `MainActivity.kt` (register plugin), `AndroidManifest.xml` (permissions + activity + receiver), `BlanForegroundService.kt` (invite notification helper only if needed — prefer InvitePresenter own channel `blan_invites` HIGH)
  - `test/android_proximity_radios_test.dart` — channel-mock tests
- **Channel design** (one `MethodChannel('com.brukb.blan/proximity')` + two `EventChannel`s `'…/scans'`, `'…/frames'`):
  - Dart→Kotlin methods: `startAdvert{payload,scanResponse}`, `stopAdvert`, `startScan`, `stopScan`, `connectControl{peerHandle,transport}` → linkId, `startListening`, `stopListening`, `sendFrame{linkId,frameJson}`, `closeLink{linkId}`, `startHotspot`, `stopHotspot`, `startWifiDirect`, `stopWifiDirect`, `join{ssid,passphrase,security,localOnly}`, `leaveJoined`, `showInvite{nick,code}` → dialog-or-notification result via `'…/inviteResult'` events (`accept`/`decline`), `hasFullScreenIntent`, `hasOverlayPermission`, `requestInvitePermissions`
  - Kotlin→Dart events: scans (peerHandle + advert bytes + scanResponse bytes), inbound control links (`'…/inbound'` events with linkId), frames (`linkId`, frameJson map), invite result
- **Invariants:**
  1. No Nearby Connections. No system BT pairing dialog (`createInsecureRfcommSocketToServiceRecord` with our UUID — never `createBond`).
  2. Advert payload in = already-packed 31 bytes → `AdvertiseData` manufacturer data (id 0xFDAA-style custom, any 16-bit id is fine — document chosen id). Nick = scan response. Never fingerprint/PSK in bytes.
  3. Frames flow as JSON maps both ways. Kotlin does not parse/sig-check — Dart codec owns that.
  4. Hotspot creds come from `LocalOnlyHotspotReservation.getSoftApConfiguration()` (API 30+; else `WifiConfiguration` fallback) and are returned to Dart only in `startHotspot` result — Dart sends them only post-accept (T12; here they just return).
  5. `startLocalOnlyHotspotWithConfiguration` if public at runtime; else plain `startLocalOnlyHotspot`. Reflection guard not required — try/catch `NoSuchMethod` is fine.
  6. WFD only after hotspot fail: the walker (T05) enforces order; Kotlin `startWifiDirect` just creates a group via `WifiP2pManager.createGroup`.
  7. Join: `localOnly=true` → `WifiNetworkSpecifier` + `ConnectivityManager.requestNetwork`; `localOnly=false` → `WifiNetworkSuggestion` add. Never toggle STA directly.
  8. OS PSK read is T07. `AndroidProximityRadios.readCurrentPersonalPsk()` returns `null` this task.
  9. Invite: check `USE_FULL_SCREEN_INTENT` granted (`NotificationManager.canUseFullScreenIntent()` API 29+) and overlay (`Settings.canDrawOverlays`) → launch `InviteActivity` (translucent, showWhenLocked/turnScreenOn) else heads-up notification (channel `blan_invites`, IMPORTANCE_HIGH) with Accept/Decline actions → `BroadcastReceiver` → plugin → Dart.
  10. Permissions (first fg start with switch on, via `permission_handler` in Dart): `bluetoothAdvertise`, `bluetoothScan` (neverForLocation), `bluetoothConnect`, `nearbyWifiDevices` (neverForLocation), `notification`, overlay + FSI via `requestInvitePermissions` (Settings intents). Denial leaves switch on; expose `InvitePermissionStatus` to UI task (T13).
  11. PSK never in logs. `join` passes passphrase over the channel only (memory), Kotlin does not persist.
- **Allowed:** Kotlin stdlib + framework APIs, `permission_handler` (existing dep), `TestDefaultBinaryMessengerBinding` mocks in tests.
- **Forbidden:** pubspec additions, Nearby Connections, `flutter_blue*`, Drift writes from radios, changing T05 abstracts (additive only if a signature truly misses an arg — record it).

### Kotlin behavior notes

- **BleRadio:** `BluetoothLeAdvertiser.startAdvertisingSet` (API 26+; minSdk 24 → plain `startAdvertising` fallback for API 24/25). Scan: `BluetoothLeScanner` with `ScanFilter` on our service UUID `0000fdaa-…` (same 16-bit id), `ScanSettings` low latency. Map `ScanRecord.getManufacturerSpecificData(id)` → payload; scan response = `getServiceData` or second manufacturer field — simplest: put nick in service data of scan record. peerHandle = device address.
- **ControlRadio:** RFCOMM: `listenUsingInsecureRfcommWithServiceRecord` name `blan-ctl` UUID `xxxxxxxx` (generate once, put const in both files — must match). Client connect = `createInsecureRfcommSocketToServiceRecord`, then `connect()` on a worker thread. GATT fallback: server `BluetoothGattServer` with a writable characteristic; frames chunk at 512-byte MTU — length-prefix JSON frames (4-byte BE length + utf8). One `linkId` counter; `sendFrame` writes; inbound reads → decode length-prefixed frames → Dart.
- **WifiRadios:** hotspot reservation stored; `stopHotspot` closes it. WFD: `createGroup` + `requestGroupInfo` for owner/SSID; WFD passphrase via `WifiP2pConfig` (random or `wps` pin) — return group owner address as SSID-joined address. If `createGroup` fails → `PrivateNetworkException` equivalent: return error code string to Dart, Dart throws `PrivateNetworkException(method)`.
- **Error mapping:** Kotlin replies `Map{error: 'hotspotFailed'|'wifiDirectFailed'|…}`; Dart maps to `PrivateNetworkException`. Never silently succeed on radio failure.
- **InviteActivity:** full-screen translucent, shows nick + 6-digit code, Accept/Decline buttons, 60s countdown handled by Dart queue (Kotlin just relays button events). Declared in manifest with `showWhenLocked`, `turnScreenOn`, `excludeFromRecents`, not exported, theme translucent.

### Steps

1. Manifest: add permissions (BT advertise/scan/connect, legacy BT maxSdk 30, FINE_LOCATION maxSdk 32, NEARBY_WIFI_DEVICES neverForLocation, CHANGE_WIFI_STATE, SYSTEM_ALERT_WINDOW, USE_FULL_SCREEN_INTENT), `InviteActivity` declaration, `blan_invites` receiver. → verify: `flutter build apk --debug` still green.
2. `ProximityPlugin.kt` + `BleRadio.kt` + register in `MainActivity.configureFlutterEngine`. → verify: apk builds; `flutter test` still green (no Dart caller yet).
3. `lib/platform/android/android_proximity_radios.dart` — ports + invite presenter over the channel; `AndroidOsPassphrasePort` returns null. → verify: analyze clean.
4. `ControlRadio.kt` (RFCOMM+GATT) + Dart `ControlChannelPort` impl (linkId bookkeeping, frame maps). → verify: analyze clean.
5. `WifiRadios.kt` (hotspot + WFD + join) + Dart `PrivateNetworkPort` impl with `PrivateNetworkException` mapping. → verify: analyze clean.
6. `InviteActivity.kt` + heads-up fallback + `requestInvitePermissions`; presenter result stream. → verify: apk builds.
7. `test/android_proximity_radios_test.dart` — channel-mock tests (below). → verify: `flutter test test/android_proximity_radios_test.dart`.
8. Wire `hasOverlayPermission`/`hasFullScreenIntent` exposure for UI task. → verify: `make verify` green.

### Tests to add (`test/android_proximity_radios_test.dart`)

Use `TestWidgetsFlutterBinding` + `setMockMethodCallHandler` on `com.brukb.blan/proximity`; mock EventChannels via `TestDefaultBinaryMessengerBinding` stream handlers.

1. `startAdvert` sends `payload`+`scanResponse` verbatim; 31-byte assert stays in Dart (`assertAdvertPayload` call before channel hop).
2. `startHotspot` returns mock creds → `HotspotCredentials(ssid/passphrase/security)` mapping incl. `WifiSecurity.fromWire`.
3. Kotlin `error: 'hotspotFailed'` mock reply → `startHotspot` throws `PrivateNetworkException(HostMethod.hotspot)`; same for `wifiDirectFailed`.
4. `join` sends `{ssid, passphrase, security.wire, localOnly}` — passphrase present in the *invoke args* of the mock capture (in-memory only), and presenter never logs it.
5. `connectControl(rfcomm)` → invoke args carry transport `'rfcomm'`; mock returns linkId 7; `sendFrame` carries `{linkId:7, frameJson}` with `x25519` field intact.
6. Invite: mock `hasFullScreenIntent: true` → `showInvite` results stream yields `accept`; `false` → presenter used notification path (mock `showInvite` returns `'notification'`), result stream still yields `decline`.
7. `readCurrentPersonalPsk` returns null without channel hop? — No: it should NOT hop (T07). Assert no method call recorded.
8. Fakes still used: keep `test/proximity_radios_test.dart` untouched — proves fakes+ports unchanged.

### Verify commands

```bash
flutter test test/android_proximity_radios_test.dart
make verify
```

Device paths (manual, T14): `flutter run -d android` with two handsets — advert/scan visible in Peers, invite dialog over lock screen, hotspot creds after Accept.

### Risks / pitfalls

- **UUID mismatch Dart/Kotlin** → control connect never binds. Single const, copied into plan-review diff.
- **API 24/25 no AdvertisingSet** → plain `startAdvertising` fallback path must exist or min-scan devices break.
- **GATT MTU**: frames > MTU must length-prefix; hello map is ~300–400 bytes — fine at 512, but secret frames similar. Test chunking on device (T14), not here.
- **`USE_FULL_SCREEN_INTENT` on API 33+ needs Play exemption / user grant** — heads-up fallback is the primary path; dialog is best-effort.
- **Full-screen dialog from background blocked (Android 10+)** — only allowed because FSI; if denied → notification path (AC).
- **Hotspot reservation leak** on process death — `stopHotspot` must close; service teardown calls it (T12 wires; Kotlin `onCleared`-style cleanup in plugin `detachFromEngine`).
- **WFD passphrase unavailable on modern Android** — `requestGroupInfo` may hide it; then Dart receives empty ssid/passphrase → treat as `wifiDirectFailed` (fall to next step). Map this case explicitly.
- **Mock EventChannel plumbing** — first use in repo; use `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler` if available in current Flutter, else guard the test with a small helper.
- **Do not bump Gradle/AGP/Kotlin** (deprecation warnings known).
- **No secret in logs**: Kotlin must not Log the join passphrase.

### Out of scope

- Shizuku/Shevery PSK read (T07 — `readCurrentPersonalPsk` stays null)
- Linux/macOS/Windows/iOS radios (T08–T11)
- Orchestrator wiring, idle timer, disband (T12)
- Settings UI toggles for the new permissions (T13 — expose status only)
- Real-device radio verification (T14 manual)
- Second mDNS-style discovery path (BLE only)

### Execute model recommendation

- **large** — five Kotlin subsystems (BLE, RFCOMM/GATT, hotspot, WFD, join) + invite UI + permission matrix + first channel-mock test harness in one task. Plan gives names/shapes, but API details (advertising callback wiring, GATT server threading, network callback lifecycles) demand a strong executor.

## Test Plan

- Channel-mock tests in `test/android_proximity_radios_test.dart`
- Commands: `flutter test` and `make verify`

## Acceptance Criteria

- [x] Dart calls map to the T05 interface with no policy reimplementation
- [x] Overlay denial still produces a notification action path
- [x] `make verify` green
- [x] No secrets committed

## Verification

- Tooling presence: `Makefile` `verify:` target, `lefthook.yml`, `analysis_options.yaml` — all present (hard gate).
- `flutter analyze` — clean, no issues.
- `flutter test` — 239 passing (226 prior + 13 new in `test/android_proximity_radios_test.dart`).
- `flutter build apk --debug` — green; Kotlin compiles (Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 untouched; deprecation warnings known).
- `make verify` — green end-to-end, re-run after reviewer fixes.
- Reviewer pass (cavecrew-reviewer): 4 red + 15 yellow + 1 blue. All 4 red fixed (GATT length cap, MTU-23 chunking, API 24–28 join guards, Dart sendFrame error swallow). Yellows fixed: main-thread `MethodChannel.Result` replies, ConcurrentHashMap link maps, GATT disconnect cleanup, `offset != 0` rejection, latch-based GATT connect, hotspot late-callback leak (`disposed` flag), WFD poll budget 10s, volatiles, `InviteActivity` → plain `Activity`, sequential Settings intents, Dart `connect()` wires frames pre-return, `showInvite` error-map check. Deferred by design: `advertiseError` surfacing and link-closed push — no T05 event exists for either; T12 orchestrator owns advert health and dead-link detection (send fails surface it).
- Fakes contract: `test/proximity_radios_test.dart` untouched.
- Security pass: no PSK/passphrase in Kotlin logs; no `Log.` anywhere under `proximity/`; frames opaque in Kotlin; no `createBond`.

## Files Modified

- `android/app/src/main/AndroidManifest.xml` — radio permissions (BT advertise/scan/connect, legacy BT maxSdk 30, fine location maxSdk 32, NEARBY_WIFI_DEVICES neverForLocation, CHANGE_WIFI_STATE, SYSTEM_ALERT_WINDOW, USE_FULL_SCREEN_INTENT), `InviteActivity` + `InviteActionReceiver` declarations
- `android/app/src/main/res/values/styles.xml` — `InviteTheme`
- `android/app/src/main/kotlin/com/brukb/blan/proximity/ProximityIds.kt` — new: shared ids (manufacturer 0xFDA9, BLE service, RFCOMM, GATT UUIDs)
- `android/app/src/main/kotlin/com/brukb/blan/proximity/BleRadio.kt` — new: advert (AdvertisingSet API 26+, legacy fallback) + scan
- `android/app/src/main/kotlin/com/brukb/blan/proximity/ControlRadio.kt` — new: RFCOMM + GATT fallback, length-prefixed JSON frames
- `android/app/src/main/kotlin/com/brukb/blan/proximity/WifiRadios.kt` — new: hotspot + WFD + join, `RadioException(code)`, no passphrase logging
- `android/app/src/main/kotlin/com/brukb/blan/proximity/InviteBus.kt` — new
- `android/app/src/main/kotlin/com/brukb/blan/proximity/InviteActivity.kt` — new: accept/decline dialog
- `android/app/src/main/kotlin/com/brukb/blan/proximity/InviteActionReceiver.kt` — new: notification action buttons
- `android/app/src/main/kotlin/com/brukb/blan/proximity/InvitePresenter.kt` — new: dialog vs heads-up decision, `blan_invites` channel
- `android/app/src/main/kotlin/com/brukb/blan/proximity/ProximityPlugin.kt` — new: MethodChannel host + 4 EventChannels, executor pool, `Map{error:code}` replies, dispose()
- `android/app/src/main/kotlin/com/brukb/blan/MainActivity.kt` — plugin registration + `cleanUpFlutterEngine` dispose
- `lib/platform/android/android_proximity_radios.dart` — new: `AndroidProximityRadios` (four T05 ports, PSK null until T07), `AndroidInvitePresenter`
- `test/android_proximity_radios_test.dart` — new: 10 channel-mock tests (`setMockMethodCallHandler` + `MockStreamHandler`, first use in repo)
- `planning/phases/T06-android-radios.md`, `planning/phases/INDEX.md` — status tracking

## Manual test (for humans)

Device paths deferred to T14 (two handsets): advert/scan visible in nearby list, invite dialog over lock screen, heads-up fallback when FSI/overlay denied, hotspot creds returned after Accept, RFCOMM control connect between two devices.

## Learnings

- Android BT/Wi-Fi class names must be verified, not recalled: `AdvertisingSet*` (not `AdvertiseSet*`), legacy `startAdvertising(settings, data, scanResponse, callback)` order, `setLegacy` is SystemApi, p2p manager via `getSystemService`. Encoded in `proximity.mdc`.
- `flutter analyze`/Kotlin compile will not catch post-minSdk runtime APIs (no Android Lint in the gate): `WifiNetworkSpecifier` 29+, 3-arg `requestNetwork` 28+, `Channel.close()` 27+, `canUseFullScreenIntent` 29+, FSI settings intent 34+. Manual `Build.VERSION` guards; encoded in `flutter.mdc`.
- `MethodChannel.Result` must be replied on the platform main thread — pool-thread replies hang Dart. Encoded in `flutter.mdc`.
- GATT default ATT MTU 23 → 20 usable write bytes; `requestMtu(247)` + chunk `mtu - 3`. Encoded in `proximity.mdc`.
- EventChannel mocking: `setMockStreamHandler` + `MockStreamHandler.inline` (Flutter 3.47); clear handlers in `tearDown`. Encoded in `flutter.mdc`.
- Known deferral: server-side GATT links are receive-only (writable characteristic); server→client frames need a notify characteristic — T12 if the GATT fallback path becomes primary. RFCOMM is primary and bidirectional.

## Reality notes

- T05 ports live in `lib/core/proximity/proximity_radios.dart` (`BlePresencePort`, `ControlChannelPort`, `PrivateNetworkPort`, `OsPassphrasePort`) with fakes in `proximity_radio_fakes.dart`. Bind Android to those abstracts — do not widen `PlatformServices`.
- Advert in = already-packed 31-byte `ProximityAdvert.pack()`; nick = scan-response bytes. Control `send` forwards codec JSON maps as-is (keep `x25519`).
- `walkHostChain` is the fail-stepper; policy WFD skip stays in `hostChain()`. OS PSK miss returns `null` (fall through). Shizuku bind is T07, not this task.
- Unit tests on Linux keep using T05 fakes; mock MethodChannels only where the host cannot open a radio.
- Android snapshot at plan: minSdk 24 / target 36; channels `com.brukb.blan/platform` + `/sharing`; FG service `blan_tasks` `dataSync`; no radio permissions; no `setMockMethodCallHandler` in tests yet.