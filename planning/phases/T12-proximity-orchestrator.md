# T12 — Proximity orchestrator

**Status**: Done  
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
| 2026-10-05 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-05 | execute started | Planned | InProgress | /task-2-execute T12 | user |
| 2026-10-05 | completed | InProgress | Done | /task-3-complete T12 | user |

## Requirements

- [x] App start follows the visible switch and foreground vs background advertise rules
- [x] Same-LAN success does not start a hotspot
- [x] Password miss calls the host chain. Short-code decline does not
- [x] Idle timer (settings minutes, default 3) and Disband close hotspot or Wi-Fi Direct. Switch off stops advert only. Associated clients and running transfers keep the network up
- [x] Third device that sees a host or joiner joins that group instead of starting one. Wi-Fi Direct relays to the owner. Hotspot members forward the PSK only after accept when the setting allows
- [x] Round-robin includes only devices already in the attempt
- [x] Tests drive fakes through same-LAN, password fallthrough, all-hosts-fail, and member invite

## Implementation Plan

### High-level notes (bootstrap)

- Hook from `AppService.initialize` / resume / `shutdownSharing`. Do not start a second long-lived isolate
- HTTPS client stays `transfer_client.dart` / pinned client. Pass the new base URL in

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-05
**Codebase snapshot:** T11 ✅ on `T12-proximity-orchestrator`. Policy is pure functions in `lib/core/proximity/proximity_policy.dart`. Ports and `walkHostChain` are in `proximity_radios.dart`. Fakes are in `proximity_radio_fakes.dart`. No orchestrator class. Radios are not constructed from `AppService`, `platform_factory.dart`, or `DesktopPlatformServices`. Live app builds one `AppService` in `lib/app/app.dart` `_start` and overrides `appServiceProvider`. Widget tests pass their own `AppService` and must not open a radio. `make verify` is analyze + test + debug apk. 296 tests at T11 close.
**Execute model:** medium

### Context for executor

Wire T02 policy to the T05 ports, `/hello`, and trust. Do not re-decide badges, sheet options, or host order. Do not build T13 widgets. One class, `ProximityOrchestrator`, in `lib/core/proximity/proximity_orchestrator.dart`. Tests in `test/proximity_orchestrator_test.dart` drive fakes. No second isolate, no second HTTP client, no file bytes on a control frame.

Call these. Do not copy their logic:

- `badgeFor`, `tapAction`, `hostChain`, `passwordMissingFallsThrough`, `isAbort`, `onInviteAccepted`, `onInviteRejected`, `canAdmit`, `mayForwardHotspotCredentials`, `memberInviteTrust` in `proximity_policy.dart`
- `InviteQueue` in `proximity_invite_queue.dart`
- `ControlFrameCodec.encode` / `decode` in `proximity_control_frames.dart`. `encode(ControlAcceptBody)` and a decoded accept both set `session.accepted`. A secret before that throws `StateError('secret before accept')`. Hello already carries x25519 inside the codec. Do not add a second key field.
- `walkHostChain` only for steps whose `hostId` is the local device. It throws `StateError('no PrivateNetworkPort for …')` when the map lacks that id. This process has one `PrivateNetworkPort`. A remote step is a control frame, not a local `startHotspot`.
- Same-LAN reachability is `hostSharesLocalSubnet` (`lib/core/platform/lan_addresses.dart`) plus `TransferClient.helloAndRegisterPin(peerHttpsUrl(host, port), secrets:)` (`lib/core/transfers/transfer_client.dart`, `lib/core/network/peer_url.dart`). There is no combined helper.
- Android personal PSK is `ShizukuPskGate.read` (`lib/core/security/shizuku_psk_gate.dart`). `choice` is `db.nearbyShizukuChoice` (null means never asked). Do not use `nearbyShizukuAllowed` for that callback. `persist` is `db.setNearbyShizukuAllowed`. `state` / `requestPermission` / `ask` are `AndroidShizukuConsent` in `lib/platform/android/android_proximity_radios.dart` (`state`, `requestPermission`, `confirm`). `read` is `AndroidProximityRadios.readCurrentPersonalPsk`. `confirm` throws when the dialog was not shown. Let that throw. Do not persist it as No. Other platforms call `readCurrentPersonalPsk` directly. Null means fall through. Never log a passphrase.

Local radios, constructed only from `ProximityOrchestrator.production()`:

| OS | Construct |
| --- | --- |
| Android | `AndroidProximityRadios()` (no `production()` factory) |
| Linux | `LinuxProximityRadios.production()` |
| macOS | `MacosProximityRadios.production()` |
| Windows | `WindowsProximityRadios.production()` |
| iOS | `IosProximityRadios.production()` |

Each class implements all four ports. Invite presenters already exist and only raise a window or a notification: `AndroidInvitePresenter`, `LinuxInvitePresenter`, `MacosInvitePresenter`, `WindowsInvitePresenter`, `IosInvitePresenter`. Call `present()`. Do not draw Accept UI.

iOS still receives `ProximityAdvert.pack()` (31 bytes). The iOS radio publishes a service UUID and local name and serves those bytes as a GATT read. Do not add an orchestrator branch that invents a different manufacturer payload.

Foreground vs background, from the visible switch (`db.nearbyVisible()`, default on):

- Visible and resumed: `startAdvert`, `startScan`, `startListening`.
- Visible and background: `startAdvert` and `startListening`. `stopScan`. Background still accepts invites.
- Switch off: `stopAdvert` and `stopScan` only. Do not stop the hotspot or Wi-Fi Direct.
- Idle (`db.nearbyIdleMinutes()`, default 3) and `disband()` stop the private network. Idle does not fire while `associatedClients > 0` or `transfersInFlight > 0`. `disband()` stops even then. The confirm dialog is T13. This method is the stop.
- `shutdownSharing` stops advert, scan, and listen. It stops the private network only when both counts are 0.

Connect: `connect(handle, transport: ControlTransport.rfcomm)`. On `StateError`, retry `ControlTransport.gatt`. Any other error propagates. A thrown `send` is link-down: `close()` that link. There is no closed event on the port.

Advert health: if `startAdvert` throws, store `advertError` and allow one `retryAdvert()` call. A second failure stays stored. No timer loop.

In-flight LAN downloads stay on the existing retry. Do not change their host, and do not move them onto a new group owner. A private-link handshake runs only when that peer has no in-flight download.

### Steps

1. Reset the invite clock on promote. In `InviteQueue._promoteNext`, take `DateTime now` and replace the waiter with a new `InviteRequest` that copies the fields and sets `enqueuedAt: now`. `tick` passes its `now`. `acceptActive` and `declineActive` pass `DateTime.now()`. `enqueuedAt` is `final`, so this is a new object, not a field write. Existing queue tests stay valid. Add one assertion in `test/proximity_session_test.dart`: after `tick(t0 + 60s)` promotes `b`, a second `tick` at that same instant returns null and `b` is still active. → verify: `flutter test test/proximity_session_test.dart`

2. Add `ProximityOrchestrator` with an injectable constructor. Ports, `InviteQueue`, `ControlFrameCodec`, `DateTime Function() now`, `Future<void> Function()? presentInvite`, `Future<OsWifiNetwork?> Function() readPersonalPsk`, `Future<void> Function(String host, int port) openLan`, and `Future<void> Function(String peerId)? trustPeer`. `associatedClients` and `transfersInFlight` are settable ints, default 0. `production()` is the only place that calls the table above and the matching presenter. Tests never call `production()`.

   Public methods to implement, and no others that start work:

   - `Future<void> start({required bool foreground})` — reads nothing itself; the caller passes visibility via `Future<void> setVisible(bool visible, {required bool foreground})`. `start` is `setVisible(true, foreground: foreground)` when the app calls it with the settings value.
   - `Future<void> setVisible(bool visible, {required bool foreground})`
   - `Future<void> onForeground()` / `Future<void> onBackground()`
   - `Future<void> stopRadios({required bool keepPrivateNetwork})`
   - `Future<void> retryAdvert()`
   - `Future<void> disband()`
   - `void checkIdle(DateTime now)` — tests call this. Do not sleep for 3 minutes.
   - `ProximityBadge badgeForHit(BleScanHit hit, {required bool onLocalSubnet, required bool helloSucceeded})` — `ProximityAdvert.unpack(hit.advert)`. `hasAdvertisedIpv4` is any non-zero IPv4 byte. Then `badgeFor`.
   - `TapAction actionFor(TapFacts facts)` — returns `tapAction(facts)` and does not touch the radio.
   - `Future<AttemptEndReason> openSameLan({required String host, required int port})` — calls `openLan` only. Does not call `startHotspot` or `startWifiDirect`.
   - `Future<AttemptEndReason> abort(UserAbort event)` — `isAbort` is true. Does not walk the host chain.
   - `Future<AttemptEndReason> passwordMiss()` — `passwordMissingFallsThrough()` is true, so this walks the host plan.
   - `Future<AttemptEndReason> runHostPlan({required AttemptDevice local, required AttemptDevice remote, List<AttemptDevice> extraMembers = const [], required ControlLink link, required ControlSession session})` — `steps = hostChain(...)`. Ignore any device that is not `local`, `remote`, or `extraMembers`. For `step.hostId == local.id`, call `walkHostChain` with that single step and a map of only the local id. `PrivateNetworkException` → `codec.encode(ControlHostFailedBody(...))` and `link.send`. Success → remember `HotspotCredentials`. Send `ControlSecretBody` only after `session.accepted` and `mayForwardHotspotCredentials` (hotspot, accepted, `canAdmit`). For any other `hostId`, do not touch the local port. Wait on `link.incoming` for a decoded secret (they hosted; then `join`) or `ControlHostFailedBody` for that step. Exhausted list → `AttemptEndReason.hostChainExhausted`. Do not iterate the list again.
   - `Future<void> onInbound(ControlLink link)` — decode frames. An invite goes to `InviteQueue.enqueue`. Call `presentInvite` only when that invite is `queue.active`. Accept path uses `onInviteAccepted` and stores it on `lastTrust`. Decline and timeout use `onInviteRejected` / `TrustDecision.none`. When `queue.tick` promotes a waiter, `presentInvite` runs again. The queue reset from step 1 is what keeps that waiter alive for 60s.
   - `Future<AttemptEndReason> onScan(BleScanHit hit)` — unpack. If `role` is `owner` or `member` and `groupId` is not four zero bytes, connect and do not call `runHostPlan`. Wi-Fi Direct admit uses `canAdmit` (owner only). A hotspot member forwards a PSK only when `mayForwardHotspotCredentials` is true.

   `lastTrust` is the mutual decision even when Wi-Fi fails. Call `trustPeer` only when a peer id is already known. Do not add a Drift table.

   → verify: `dart analyze lib/core/proximity/proximity_orchestrator.dart`

3. Add the tests below. Use `FakeBlePresencePort`, `FakeControlChannelPort`, `FakePrivateNetworkPort`, `FakeOsPassphrasePort`. Count `startHotspot` / `startWifiDirect` by wrapping the fake or by a subclass that increments. Do not construct `LinuxProximityRadios.production` or any D-Bus / channel radio. → verify: `flutter test test/proximity_orchestrator_test.dart test/proximity_session_test.dart`

4. Hook the live app without touching widget-test constructors. `AppService` factory gains `ProximityOrchestrator? proximity`. Null means the radios stay off. `initialize` calls `proximity?.start(foreground: true)` only when `await db.nearbyVisible()`. `onAppResumed` calls `proximity?.onForeground()`. Add `onAppPaused` → `onBackground`. `shutdownSharing` calls `stopRadios(keepPrivateNetwork: associatedClients > 0 || transfersInFlight > 0)`. `lib/app/app.dart` passes `ProximityOrchestrator.production()` into the one `AppService` it builds, and `didChangeAppLifecycleState` calls `onAppPaused` for `paused`, `inactive`, and `hidden`. Leave `lib/app/providers.dart` as `AppService(db)` so an override cannot accidentally open a radio. Give the orchestrator `openLan: (host, port) => _handshakePeer(host: host, port: port, manual: false)` via a method on `AppService` that checks in-flight downloads first. → verify: `flutter test test/widget_test.dart test/proximity_orchestrator_test.dart`

5. Presence gate. → verify: `test -f Makefile && grep -q '^verify:' Makefile && test -f lefthook.yml && test -f analysis_options.yaml && make verify`

### Tests to add

`test/proximity_orchestrator_test.dart`:

- Same-LAN `openSameLan` calls `openLan` once and `startHotspot` zero times.
- `abort(UserAbort.codeDecline)` and `abort(UserAbort.sheetCancel)` call `startHotspot` zero times.
- `passwordMiss` with a local Android device and a remote Android device calls `startHotspot` on the local port only for the local step. A remote step does not call the local port. `FakePrivateNetworkPort(failHotspot: true, failWifiDirect: true)` plus a remote `ControlHostFailedBody` ends as `hostChainExhausted`. A second walk does not start. Call count equals the local steps, not two full passes.
- Desktop local plus iOS remote: the step list from `hostChain` has no `wifiDirect`. The orchestrator does not call `startWifiDirect`.
- Visible foreground calls `startAdvert` and `startScan`. `onBackground` calls `stopScan` and does not call `stopAdvert`. `setVisible(false)` calls `stopAdvert` and does not call `stopHotspot`.
- After a successful local hotspot, `checkIdle` before the idle duration does not stop. `checkIdle` after it, with both counts 0, calls `stopHotspot`. The same timestamp with `associatedClients == 1` or `transfersInFlight == 1` does not. `disband()` calls `stopHotspot` even when a client is associated.
- Scan hit with `AdvertRole.owner` and a non-zero `groupId` calls `connect` and does not call `startHotspot`.
- `connect` that throws `StateError('rfcomm unavailable')` is followed by one GATT `connect`.
- `startAdvert` throwing once sets `advertError`. `retryAdvert` tries once more. A second throw does not schedule another call.
- Encoded frames are the codec maps. No test frame contains a raw file byte or a logged passphrase. A secret encoded before accept throws.
- Queue: waiter promoted at the timeout is still active at that same timestamp (step 1 test).

### Verify commands

```bash
test -f Makefile && grep -q '^verify:' Makefile
test -f lefthook.yml
test -f analysis_options.yaml
flutter test test/proximity_orchestrator_test.dart test/proximity_session_test.dart
make verify
```

### Risks / pitfalls

- `walkHostChain` with the full `hostChain` list and only the local port throws on the first remote id. Filter to the local id.
- `InviteQueue.tick` ages from `enqueuedAt`. Without the promote reset, a waiter dies on the next tick.
- `AppService(db)` in widget tests must not call `production()`. Linux `production()` opens the system bus.
- Android `readCurrentPersonalPsk` skips the ask-once gate. Use `ShizukuPskGate.read` and `nearbyShizukuChoice`.
- Windows and iOS `startHotspot` throw `PrivateNetworkException`. That is a failed step, not a crash and not a retry loop.
- iOS scans will not appear in an Android manufacturer scan. Do not paper over that in this class.
- `result->Error` on desktop hotspot is already handled inside the radio classes. The orchestrator only catches `PrivateNetworkException`.
- Do not log `HotspotCredentials.passphrase` or `ControlSecretBody.psk`.

### Out of scope

- T13 link sheet, accept dialog, badge list, and settings switches.
- A new Drift table for fingerprints.
- Retargeting an in-flight download onto the private-network address.
- Changing `hostChain` device order or adding Wi-Fi Direct for desktop or iOS.
- A real BLE stack on Windows, or an iOS manufacturer advert.
- Nearby Connections, WPA-Enterprise, a second HTTP client, a second isolate.

### Execute model recommendation

- **medium** — the policy and the ports already exist. The work is one state machine that must call them as specified. A lesser agent that redesigns host order or constructs `production()` in tests will fail the gate.

## Test Plan

- Orchestrator tests with fakes
- Commands: `make verify`

## Acceptance Criteria

- [x] No file bytes on the control channel
- [x] All-fail stops without a retry loop
- [x] `make verify` green
- [x] No secrets committed

## Verification

- Tooling presence: `Makefile` `verify`, `lefthook.yml`, `analysis_options.yaml` — present.
- `flutter test test/proximity_orchestrator_test.dart test/proximity_session_test.dart test/widget_test.dart`: passed. Same-LAN does not start a hotspot. Decline and sheet cancel skip the chain. Password miss on Android-to-Android is one local hotspot and one local Wi-Fi Direct, then `hostChainExhausted`. Desktop-to-iOS does not call Wi-Fi Direct. Switch off does not stop the hotspot. Idle waits out clients and transfers. Disband stops. Grouped scan connects. RFCOMM `StateError` retries GATT once. Advert retries once. Secret before accept throws.
- First `make verify` hit two unrelated `/tmp` flakes and then hung in `transfer_client_test`. Killed and re-ran.
- Close-out execute `make verify` (2026-10-05): exit 0. Analyze clean, 306 tests, debug apk built. Gradle/AGP/Kotlin warnings only. Versions not bumped.
- Review follow-up (same day), before close-out: idle now calls `_stopPrivate`. `passwordMiss` does not read the PSK. A step owner sends `secret` after accept, or `hostFailed` when the secret cannot be sealed, before `runHostPlan` returns. `hostChain` order unchanged. The invitee hosts its own steps on accept instead of waiting first. `onInbound` drains the link. Decline and idle promote and present the next code. Grouped scan keeps the link and listens. Android `showInvite` gets the real nick and code; `inviteResults` hit the queue. `refreshLoad` refreshes download counts before `stopRadios`. Joining or delivering a secret sets `associatedClients`.
- Re-verify after that follow-up: `flutter test test/proximity_orchestrator_test.dart test/proximity_session_test.dart` passed. `make verify` exit 0. Analyze clean, 308 tests, debug apk built. Gradle/AGP/Kotlin warnings only. Versions not bumped.
- Close-out `make verify` (2026-10-05): exit 0. Analyze clean, 308 tests, debug apk built. Same Gradle/AGP/Kotlin warnings. Versions not bumped.

## Files Modified

- `lib/core/proximity/proximity_orchestrator.dart` — policy wired to fakes; `production()` builds platform radios
- `lib/core/proximity/proximity_invite_queue.dart` — promote resets `enqueuedAt`
- `lib/core/services/app_service.dart` — optional orchestrator, null in tests
- `lib/app/app.dart` — live app passes `production()`
- `test/proximity_orchestrator_test.dart`
- `test/proximity_session_test.dart` — waiter survives the promote instant
- `planning/phases/T12-proximity-orchestrator.md`, `planning/phases/INDEX.md`
- `.cursor/rules/proximity.mdc` — host-wait, fallthrough, drain, idle teardown
- `README.md` — nearby status
- `planning/phases/T13-nearby-ui.md`, `planning/phases/T14-e2e.md` — reality notes

## Manual test (for humans)

`flutter run -d linux`. Nearby visible defaults on, so the live app opens the Linux radios. Success is the shell coming up. There is no Accept dialog yet. A missing BlueZ adapter can log a radio error and must not crash the shell.

## Learnings

- Do not reorder the host chain. The owner of a step sends a sealed secret after accept, or a failure frame when the secret cannot be sealed, before returning. The invitee hosts only its own steps when it accepts.
- A passphrase-consent throw belongs on the password decision. Awaiting it on the fallthrough skips the private network.
- Drain the control link. Hello installs keys. The invite after it is the one to queue. Present again when a waiter is promoted.
- Idle uses the same teardown as disband. Refresh in-use counts before idle or shutdown.
- `production()` stays on the live app. Widget tests keep a null orchestrator so Linux does not open the system bus.

## Reality notes

- T02 shipped `lib/core/proximity/` (pure policy + `InviteQueue`). Call it; do not re-decide badges/sheets/host order.
- `InviteQueue.tick` expires from `enqueuedAt`, not promote time. After a 60s active dialog, a waiter can decline on the next tick unless you reset the clock on promote or only tick the active window.
- Host chain already skips Wi-Fi Direct when any non-host is desktop/iOS. Do not re-add those steps in the orchestrator.
- T03: use `ControlFrameCodec`. `encode(accept)` and `decode(accept)` both set `session.accepted`. Secrets before that throw. Hello `x25519` is inside the signature.
- T06 (2026-10-03): Android radios live in `lib/platform/android/android_proximity_radios.dart` + `android/.../proximity/`. Two surfaced gaps are yours: (1) BLE advertise failures land in Kotlin `advertiseError` and are never pushed — orchestrator should re-advert on a timer or surface advert health; (2) link death is only detectable via a failed `send` (no closed event on the T05 ports) — treat send errors as link-down. Server-side GATT links are receive-only; RFCOMM is the primary bidirectional path.
- T07 plan: Android PSK ask-once is `ShizukuPskGate.read`, not raw `OsPassphrasePort.readCurrentPersonalPsk`. Raw read skips consent. Null from the gate means type the password or fall through. A consent channel error (no resumed activity) must not be persisted as No.
- T08 (2026-10-04): Linux ports are `LinuxProximityRadios.production()` in `lib/platform/desktop/linux_proximity_radios.dart`. That factory is the only D-Bus constructor and is not wired into `DesktopPlatformServices` yet — construct it on Linux. `readCurrentPersonalPsk` returns null (no throw, no log) for a missing `nmcli`, enterprise, or empty secret. `startWifiDirect` throws `PrivateNetworkException(wifiDirect)` and runs no command. RFCOMM `connect` throws `StateError` so the GATT retry runs. Server writes arrive on `inbound`, one link per device. `LinuxInvitePresenter.present()` only raises the window on `com.brukb.blan/linux` method `presentWindow`. Accept UI stays T13.
- T10 (2026-10-04): Windows ports are `WindowsProximityRadios.production()` on `com.brukb.blan/windows`. Not wired into `DesktopPlatformServices`. Construct it on Windows. Hotspot and Wi-Fi Direct throw `PrivateNetworkException` from a success envelope (`hotspotFailed`, `wifiDirectFailed`). BLE methods return `bleUnavailable`, which becomes `StateError`. `currentWifi` is null. RFCOMM throws `StateError('rfcomm unavailable')` before the channel so GATT is the retry. `WindowsInvitePresenter.present()` only calls `presentWindow`. Event channels `scans`, `inbound`, and `frames` accept listen and send nothing. mDNS advertise is on: `MdnsDiscovery.start` uses Bonsoir on Windows. Do not treat Windows as browse-only.
- T11 (2026-10-05): iOS ports are `IosProximityRadios.production()` in `lib/platform/ios/ios_proximity_radios.dart` on `com.brukb.blan/ios`. Not wired into the shell. `readCurrentPersonalPsk` returns null and does not call the channel. Hotspot and Wi-Fi Direct throw `PrivateNetworkException`. RFCOMM throws `StateError('rfcomm unavailable')` before the channel. The iPhone advert is a service UUID plus a local name; the 31-byte payload is a GATT read, so Android and macOS manufacturer scans will not list it. Do not invent that payload in the orchestrator. `IosInvitePresenter.present()` calls `presentInvite` and swallows `notifyFailed` only.
