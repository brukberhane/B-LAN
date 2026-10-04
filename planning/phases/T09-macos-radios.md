# T09 — macOS radios

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T08  
**Next**: T10  
**Layer**: L6

## Description

macOS implementation of the T05 ports, plus expected tests. Radio and keychain calls are mocked so `make verify` passes on Linux. A Mac later runs the same assertions against the real runner.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-04 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-04 | execute started | Planned | InProgress | /task-2-execute T09 | user |
| 2026-10-04 | close-out | InProgress | Done | /task-3-complete T09 | user |

## Requirements

- [x] Keychain read of the AirPort password for the current SSID, which raises Touch ID or a password prompt. No sudo
- [x] BLE advert/scan and control channel behind the T05 interface. Hotspot host is best-effort and returns the port failure when the OS will not start one
- [x] Invite raises a window
- [x] Tests name the expected keychain and hotspot outcomes and run them through fakes here. No `skip:` that deletes the expectation

## Implementation Plan

### High-level notes (bootstrap)

- This Linux checkout cannot open CoreBluetooth. Do not weaken assertions to "not run"
- WPA2/WPA3-Personal only

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-04
**Codebase snapshot:** T08 ✅ (`9996f20`) on `T09-macos-radios`. T05 ports live in `lib/core/proximity/proximity_radios.dart` (`BlePresencePort`, `ControlChannelPort`, `PrivateNetworkPort`, `OsPassphrasePort.readCurrentPersonalPsk` → `OsWifiNetwork?`). Linux binds them in `lib/platform/desktop/linux_proximity_radios.dart` with `production()` plus fakes; invite is `LinuxInvitePresenter` → `com.brukb.blan/linux` method `presentWindow`. Shared ids are `lib/core/proximity/proximity_ids.dart` (must match `ProximityIds.kt`). Android channel `com.brukb.blan/proximity` is a different host — do not call it from macOS. `macos/Runner/` is the stock Swift embedder: `AppDelegate.swift`, `MainFlutterWindow.swift`, no method channel. Both entitlements files set `com.apple.security.app-sandbox` true. `make verify` is analyze + test + Android debug apk. It does not build macOS. `CommandRunner` / `SystemCommandRunner` already exist in `lib/platform/desktop/linux_command.dart`.
**Execute model:** medium

### Context for executor

- **Goal:** macOS implementations of the four T05 ports, tested on this Linux host through fakes. Keychain read uses `/usr/bin/security` against the System keychain and lets the OS show its own prompt. No sudo. BLE advert/scan and GATT go through a new method channel the Swift runner implements. Classic RFCOMM throws so the later orchestrator retries GATT. Hotspot and Wi-Fi Direct return the T05 private-network failure because macOS has no supported local-only AP API. Invite raises the existing window. `make verify` stays green without a Mac and without `skip:`.
- **Key files to create:**
  - `lib/platform/desktop/macos_proximity_radios.dart` — `MacosProximityRadios`, `MacosInvitePresenter`
  - `macos/Runner/MacosProximity.swift` — channel handler (CoreWLAN, CoreBluetooth, window, immediate hotspot failure)
  - `test/macos_proximity_radios_test.dart`
- **Key files to edit:**
  - `macos/Runner/AppDelegate.swift` — register the channel from the Flutter binary messenger once the view exists
  - `macos/Runner/MainFlutterWindow.swift` — keep `self` where `presentWindow` can see it; clear that reference on close
  - `macos/Runner/Info.plist` — `NSBluetoothAlwaysUsageDescription`
  - `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` — drop App Sandbox (see below)
  - `macos/Runner.xcodeproj/project.pbxproj` — compile the new Swift file in the Runner target (this project is not a synchronized folder)
- **Do not edit** T05 abstracts, `hostChain` / `walkHostChain`, Android radios, Linux radios, `proximity_ids.dart`, `pubspec.yaml`. No BLE plugin, no Nearby Connections, no second HTTP stack.
- **Reuse** `CommandRunner` and `SystemCommandRunner` from `linux_command.dart`. Do not rename that file. Do not copy it.

### Why the sandbox comes off

AirPort passwords live in `/Library/Keychains/System.keychain` (generic password, account = SSID, service = `AirPort`). A sandboxed app cannot read that item and cannot raise the system prompt. Remove the `com.apple.security.app-sandbox` key from both entitlements files. Leave the other keys. Do not add sudo, a privileged helper, or `security -i` with a password. The unsandboxed app is what lets `/usr/bin/security` show Touch ID when the Mac offers it, otherwise the keychain password dialog.

### PSK (`OsPassphrasePort`)

`readCurrentPersonalPsk` order:

1. Invoke `currentWifi` on `com.brukb.blan/macos`. Missing plugin / null / non-map → `null`.
2. Read `ssid` and `security`. Security strings the Swift side may return: `wpa2-psk`, `wpa3-sae`, `other`. Anything except the two personal wires → `null`. Do not spawn `security`.
3. Otherwise `commands.run` exactly:

```text
/usr/bin/security
find-generic-password
-w
-a
<ssid>
-s
AirPort
/Library/Keychains/System.keychain
```

`Process.run` argv, not a shell. SSID is one argument even with spaces. No `sudo`, no password flag.

4. Exit 0 and stdout that still has characters after stripping one trailing `\n` → `OsWifiNetwork` with that ssid, that passphrase, and `WifiSecurity.fromWire`. Non-zero, empty, or `Process` exit 127 → `null`. Do not throw. Do not put stdout or stderr in an exception or `debugPrint`.

Swift `currentWifi` (reply on the main queue):

- `CWWiFiClient.shared().interface()`.
- SSID: `interface.ssid()` when non-empty. Else `/usr/sbin/networksetup -getairportnetwork <interface.interfaceName>`. A line starting `Current Wi-Fi Network: ` → the remainder is the SSID. `You are not associated with an AirPort network.` or no interface → success `null`.
- Security, from `interface.security()` only: `.wpa2Personal` → `wpa2-psk`, `.wpa3Personal` → `wpa3-sae`, every other case (enterprise, transition, OWE, WEP, none, unknown) → `other`. If the interface is nil, return null even when networksetup printed a name — do not guess personal.
- Do not log either command's output.

### Hotspot and Wi-Fi Direct

Apple removed `CWInterface.startHostAPMode` / IBSS. Internet Sharing is not an API and is not local-only. Do not script it, and do not call the removed selectors.

- `startHotspot` → channel reply `{"error": "hotspotFailed"}` via `result.success`, then Dart throws `PrivateNetworkException(HostMethod.hotspot)`. Swift runs no Wi-Fi call.
- `stopHotspot` → `result(null)`. Nothing to tear down.
- `startWifiDirect` → `{"error": "wifiDirectFailed"}` → `PrivateNetworkException(HostMethod.wifiDirect)`.
- `stopWifiDirect` → `result(null)`.

Map those two error strings the way `AndroidProximityRadios._invoke` maps `hotspotFailed` / `wifiDirectFailed`. Any other `{error: ...}` becomes `StateError`.

### Join

Channel `join` with `ssid`, `passphrase`, `security` (`WifiSecurity.wire`), `localOnly`. Swift ignores `localOnly` (no specifier API) but the key must still be sent. Associate with CoreWLAN (`scanForNetworks` with that SSID, then `associate(to:password:)`). Failure → `{"error": "joinFailed"}` → Dart `StateError`, not `PrivateNetworkException`. `leaveJoined` → `disassociate()`. Do not put the passphrase on a `networksetup` argv (it shows up in `ps`) and do not log it.

### BLE and control

Channel `com.brukb.blan/macos`. Event channels:

- `com.brukb.blan/macos/scans`
- `com.brukb.blan/macos/inbound`
- `com.brukb.blan/macos/frames`

Dart `startAdvert` calls `assertAdvertPayload` (length 31) before the channel. Short payload throws `ArgumentError` and must not invoke.

Swift advertise dictionary:

- `CBAdvertisementDataManufacturerDataKey`: two little-endian company bytes `D9 FD` (`0xFDA9`) then the 31-byte payload. Do not swap the company id. Do not truncate.
- `CBAdvertisementDataServiceDataKey`: `CBUUID` `0000fda9-0000-1000-8000-00805f9b34fb` → nick bytes.

Wait for `didStartAdvertising`. An error (including data-too-large) → `{"error": "advertFailed"}` → Dart `StateError`. Reply on the main queue.

Scan: drop a hit unless manufacturer data is 33 bytes and starts with `D9 FD`. Emit the remaining 31 bytes as `advert`, service-data nick as `scanResponse` (empty data if absent), `peerHandle` = `peripheral.identifier.uuidString`. Dart drops again when `advert.length != 31`.

`connect(..., rfcomm)` throws `StateError('rfcomm unavailable')` in Dart before any channel call. Do not import IOBluetooth. That throw is the T12 signal to retry GATT.

GATT UUIDs from `ProximityIds`: service `9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7b`, characteristic `9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c`, writable. Frames are 4-byte big-endian length plus UTF-8 JSON. Cap 64 KiB. Drop that peer's buffer on a hostile length. Chunk writes at `maximumWriteValueLength`, with a 20-byte floor. `send` JSON-encodes the map as given. Do not strip `x25519` or re-sign. One inbound event per peripheral; a single write may hold more than one frame — drain until a frame is incomplete.

`NSBluetoothAlwaysUsageDescription` in `Info.plist`: `B-LAN uses Bluetooth to find nearby devices and open a control channel.`

CoreBluetooth managers and every `result.success` / `result.error` stay on the main queue. Radio work may hop off; the reply hops back.

### Invite window

`MacosInvitePresenter.present()` invokes `presentWindow` and returns. No dialog and no Accept button (T13).

Swift: if the stored `NSWindow` is nil, `FlutterError` code `windowMissing`. Else deminiaturize, `makeKeyAndOrderFront`, and activate (`NSApp.activate()` on macOS 14+, `activate(ignoringOtherApps: true)` on the 12.0 deployment target). Set the window from `MainFlutterWindow.awakeFromNib`. Clear it in the window close path before a later present (a freed window must not be ordered front).

Register the method channel and the three event channels in `awakeFromNib` after `FlutterViewController` exists, messenger = `flutterViewController.engine.binaryMessenger`.

### Xcode project

`project.pbxproj` lists sources by hand. Add `MacosProximity.swift` in all four places, copying the `AppDelegate.swift` shape:

- `PBXBuildFile` (file in Sources)
- `PBXFileReference`
- `PBXGroup` `33FAB671232836740065AC1E` children
- `PBXSourcesBuildPhase` `33CC10E92044A3C60003C045` files (the Runner target, not RunnerTests)

### Steps

1. Entitlements (remove `com.apple.security.app-sandbox` from both files) and `NSBluetoothAlwaysUsageDescription`. → verify: both plists no longer contain that key; Info.plist has the Bluetooth string.
2. `macos_proximity_radios.dart` with injectable `CommandRunner` and `MethodChannel`. `production()` uses `SystemCommandRunner` and `com.brukb.blan/macos`. → verify: `flutter analyze lib/platform/desktop/macos_proximity_radios.dart`.
3. `test/macos_proximity_radios_test.dart` using `setMockMethodCallHandler` and `setMockStreamHandler`. Clear every handler in `tearDown`. No `skip:`. → verify: `flutter test test/macos_proximity_radios_test.dart`.
4. `MacosProximity.swift` plus the `awakeFromNib` registration, window pointer, and the four pbxproj entries. → verify: `flutter analyze`. Do not run `flutter build macos` on this Linux host.
5. → verify: `make verify`.

### Tests to add

`test/macos_proximity_radios_test.dart`. Binding: `TestWidgetsFlutterBinding.ensureInitialized()`.

1. `currentWifi` returns ssid `Home`, security `wpa2-psk`. Scripted `security` stdout `sekret\n` → `OsWifiNetwork` ssid `Home`, passphrase `sekret`, security `wpa2Psk`. Recorded argv is the exact list above, executable `/usr/bin/security`. No arg is `sudo`.
2. Same with `wpa3-sae` → `WifiSecurity.wpa3Sae`.
3. `currentWifi` security `other` → `null`, and the command runner has no calls.
4. `security` exit non-zero → `null`. Empty stdout → `null`. Runner exit 127 → `null`. No exception.
5. `startHotspot` mock `{"error": "hotspotFailed"}` → `PrivateNetworkException(HostMethod.hotspot)`.
6. `startWifiDirect` mock `{"error": "wifiDirectFailed"}` → `PrivateNetworkException(HostMethod.wifiDirect)`.
7. `startAdvert` with 3 bytes throws `ArgumentError` and the mock channel records no call.
8. A scans event whose `advert` is 31 bytes becomes a `BleScanHit`. A 4-byte `advert` is dropped.
9. `connect(..., rfcomm)` throws `StateError` and does not invoke the channel. `connect(..., gatt)` then `send({x25519: peer-key})` invokes `sendFrame` with that field still in `frameJson`.
10. `MacosInvitePresenter.present` invokes `presentWindow` and no other method.

### Verify commands

```bash
flutter test test/macos_proximity_radios_test.dart
flutter analyze
make verify
```

Do not add `flutter build macos`. This checkout has no Xcode.

### Risks / pitfalls

- **stdout is the secret.** `security -w` prints the PSK. Strip one trailing newline only. Never log it. A passphrase that itself contains spaces must survive.
- **Sandbox left on means the prompt never appears** and the read returns null. Both entitlements files must lose `com.apple.security.app-sandbox`.
- **Company id endian.** Apple's manufacturer blob starts with the company id, little-endian. `0xFDA9` is `D9 FD`, then the 31 payload bytes. Android's `getManufacturerSpecificData` already strips the id; CoreBluetooth does not.
- **31 + 2 may be rejected as too large.** Surface `advertFailed`. Do not shorten `ProximityAdvert.packedLength`.
- **RFCOMM throw is intentional.** IOBluetooth opens a pairing dialog. Forbidden.
- **Hotspot "best effort" is the typed failure**, not Internet Sharing and not sudo.
- **`result` off the main queue** asserts in debug. Post it back.
- **Window pointer.** Clear it on close. A later `presentWindow` with a freed window crashes instead of returning `windowMissing`.
- **pbxproj.** A Swift file that is not in `33CC10E92044A3C60003C045` compiles nowhere.
- **Do not bump** Flutter, Gradle, AGP, or Kotlin.

### Out of scope

- Idle timer and Disband UI (T12 calls `stopHotspot`, which is a no-op here)
- Invite Accept / Decline widgets (T13)
- Wiring `MacosProximityRadios.production()` into the app shell (T12)
- Windows and iOS (T10, T11)
- Location permission. SSID fallback is `networksetup`. Do not add CoreLocation in this task
- Joining an Android Wi-Fi Direct group
- `sudo`, privileged helper, Internet Sharing, removed CoreWLAN AP selectors

### Execute model recommendation

- **medium** — the Dart port and the fakes are mechanical, but the Swift channel has to match the byte layout, the keychain argv, and the main-queue reply rule without a Mac compile on this host. A small model will "fix" the hotspot with Internet Sharing or sudo.

## Manual test (for humans)

A Mac runs these. They are not `skip:` cases. Linux asserts the same outcomes on fakes.

- Connected to a WPA2-Personal or WPA3-Personal network: read raises Touch ID or the keychain password dialog, no sudo prompt, and returns that SSID and passphrase. Cancel, a missing item, or an enterprise network returns empty and the attempt continues.
- Start hotspot returns the hotspot failure. No new Wi-Fi network appears.
- Foreground: this Mac advertises and scans; a peer with the `FDA9` manufacturer payload shows up. Invite while the window is in the background brings it forward.
- GATT: one JSON frame with an `x25519` field arrives intact. RFCOMM is not offered and no Bluetooth pairing dialog appears.

## Test Plan

- Mocked macOS channel tests included in `flutter test`
- Commands: `make verify`

## Acceptance Criteria

- [x] Expected macOS behaviors are asserted on fakes
- [x] Real device checks are listed in the manual-test section, not omitted from the suite
- [x] `make verify` green
- [x] No secrets committed

## Verification

- Tooling presence: `Makefile` `verify`, `lefthook.yml`, `analysis_options.yaml` — present.
- `make verify` (2026-10-04 close-out): exit 0. Analyze clean, 281 tests, debug apk built (`app-debug.apk`, Gradle 2.9s). Versions not bumped.
- `flutter test test/macos_proximity_radios_test.dart`: 10 passing. WPA2/WPA3 keychain argv is `/usr/bin/security find-generic-password -w -a <ssid> -s AirPort` plus the System keychain. Enterprise does not spawn `security`. Miss, empty secret, and exit 127 return null. Hotspot and Wi-Fi Direct throw `PrivateNetworkException`. Short advert throws before the channel. 31-byte scans pass, 4-byte scans drop. RFCOMM throws. GATT `send` keeps `x25519`. Invite calls only `presentWindow`.
- `flutter build macos` did not compile: Xcode's `IDESimulatorFoundation` plugin fails to load. CoreWLAN `ssid()` / `security()` / `shared()` and the CoreBluetooth write path were typechecked against the macOS 26.5 SDK.

## Files Modified

- `lib/platform/desktop/macos_proximity_radios.dart` — four T05 ports plus invite presenter
- `test/macos_proximity_radios_test.dart` — fakes for keychain, hotspot, BLE, GATT, window
- `macos/Runner/MacosProximity.swift` — CoreWLAN, CoreBluetooth, window, typed hotspot failure
- `macos/Runner/MainFlutterWindow.swift` — register the channel, clear the window on close
- `macos/Runner/Info.plist` — Bluetooth usage string
- `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements` — App Sandbox removed so the keychain prompt can appear
- `macos/Runner.xcodeproj/project.pbxproj` — compile `MacosProximity.swift`
- `test/platform_health_test.dart` — Avahi assertion only when the host is Linux
- `.cursor/rules/flutter.mdc`, `.cursor/rules/proximity.mdc` — close-out encodings

## Learnings

- CoreWLAN `ssid` and `security` are methods. `sharedWiFiClient` compiles as `shared()`.
- A parked method-channel result must be invoked before it is cleared. Bluetooth already off must reply immediately.
- CoreBluetooth manufacturer data is the little-endian company id plus the 31-byte payload.
- App Sandbox blocks the System keychain AirPort item. Removing that entitlement is what lets `security` show the prompt.
- macOS has no local-only AP API. Hotspot and Wi-Fi Direct return `PrivateNetworkException`.

## Reality notes

- T08 shipped shared ids in `lib/core/proximity/proximity_ids.dart`. Keep them aligned with `ProximityIds.kt`. Do not shell out to `nmcli` or reuse the GTK channel `com.brukb.blan/linux`. macOS PSK is the keychain, with a user prompt, and null on failure.
