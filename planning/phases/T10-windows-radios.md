# T10 — Windows radios

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T09  
**Next**: T11  
**Layer**: L6

## Description

Windows implementation of the T05 ports at best effort: BLE presence, control channel, and a hotspot when the OS API allows it. Failures surface on the port so the host chain moves on. Tests are mocked and still assert the expected calls.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-04 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-04 | execute started | Planned | InProgress | /task-2-execute T10 | user |
| 2026-10-04 | completed | InProgress | Done | /task-3-complete T10. Windows radios stub plus Bonsoir mDNS advertise | user |

## Requirements

- [x] Implements the same Dart interface as Android and Linux
- [x] Windows mDNS advertise uses the same Bonsoir path as the other desktops (`DnsServiceRegister` in bonsoir_windows 7.3.0). The browse-only early return is gone.
- [x] No Wi-Fi Direct host mode
- [x] Tests lock the fallback: hotspot failure is a port error, not a thrown UI string

## Implementation Plan

### High-level notes (bootstrap)

- Keep Windows-specific code in the windows runner and a Dart binding. Policy stays in T02

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-04
**Codebase snapshot:** T09 ✅ on `T10-windows-radios`. Windows runner is stock Win32 (`windows/runner/flutter_window.cpp` calls `RegisterPlugins` only). No `com.brukb.blan` channel. `analysis_options.yaml` excludes `windows/**`. `make verify` does not compile Windows. At plan time mDNS advertise was off on Windows. Close-out turned it on: `MdnsDiscovery.start` uses Bonsoir there too. macOS radios (`lib/platform/desktop/macos_proximity_radios.dart`) are the Dart shape to copy. Shared ids stay in `lib/core/proximity/proximity_ids.dart`.
**Execute model:** medium

### Context for executor

Windows gets the same four T05 ports as macOS, behind `com.brukb.blan/windows`. This Linux checkout cannot compile the Win32 runner, so the native side is a small method-channel stub and the tests mock that channel. Do not add C++/WinRT, `netsh`, or a hosted-network API.

Hotspot and Wi-Fi Direct have no supported local-only API on this path. The native handler replies **success** with a map `{"error": "hotspotFailed"}` or `{"error": "wifiDirectFailed"}`. Dart turns those into `PrivateNetworkException`. A `PlatformException` or a thrown `String` is the wrong failure. BLE and GATT reply success `{"error": "bleUnavailable"}`, which Dart turns into `StateError`. `startAdvert` still calls `assertAdvertPayload` before the channel. RFCOMM throws `StateError('rfcomm unavailable')` before the channel so T12 retries GATT.

Personal PSK: reply success `null`. Dart returns null. Do not run `netsh wlan show profile`, and do not log a passphrase.

`Win32Window::GetHandle()` (`windows/runner/win32_window.h`) is already cleared on `WM_DESTROY`. `presentWindow` uses that handle. Null handle → `result->Error("noWindow", "window missing")`. Otherwise `ShowWindow(hwnd, SW_RESTORE)` and `SetForegroundWindow(hwnd)`.

Do not edit `lib/core/discovery/mdns_discovery.dart`, `lib/core/platform/platform_capabilities.dart`, or `DesktopPlatformServices`. T12 constructs `WindowsProximityRadios.production()`.

### Invariants

- No Wi-Fi Direct command and no `netsh`.
- No PSK in logs, SQLite, BLE, or mDNS.
- Advert payload is 31 bytes before any channel call (`assertAdvertPayload`).
- Scan events with `advert` length other than 31 are dropped.
- GATT `send` JSON-encodes the map and keeps `x25519`.
- Channel name `com.brukb.blan/windows`. Event channels `…/scans`, `…/inbound`, `…/frames`.
- Native hotspot/WFD/BLE failures are **success envelopes** with an `error` string, matching `MacosProximityRadios._invoke`. Do not use `result->Error` for hotspot or Wi-Fi Direct.

### Steps

1. Add `lib/platform/desktop/windows_proximity_radios.dart`. Copy the macOS class shape. `WindowsProximityRadios` implements `BlePresencePort`, `ControlChannelPort`, `PrivateNetworkPort`, `OsPassphrasePort`. Constructor: `WindowsProximityRadios({MethodChannel? channel})` defaulting to `MethodChannel('com.brukb.blan/windows')`. `factory production()` uses that default. No `CommandRunner` and no process launch. Event channels use the `/windows/` prefix. `startAdvert` calls `assertAdvertPayload` then `_invoke('startAdvert', {'payload': payload, 'scanResponse': scanResponse})`. `scans` listens to the scans event channel, keeps a map whose `advert` length is 31 and whose `peerHandle` is a `String`, and drops the rest. `connect` with `ControlTransport.rfcomm` throws `StateError('rfcomm unavailable')` before `_invoke`. GATT calls `_invoke('connectControl', {'peerHandle': peerHandle, 'transport': 'gatt'})` and returns a link whose `send` calls `_invoke('sendFrame', {'linkId': id, 'frameJson': jsonEncode(frame)})`. `readCurrentPersonalPsk` invokes `currentWifi`. Null, a non-map, an empty passphrase, or an `error` value returns null and does not throw. `startHotspot` / `startWifiDirect` use `_invoke` and then `_credentials`. `_invoke` maps `hotspotFailed` → `PrivateNetworkException(HostMethod.hotspot)` and `wifiDirectFailed` → `PrivateNetworkException(HostMethod.wifiDirect)`. Any other `error` string → `StateError('proximity radio failed: $code')`. A missing credential map from hotspot or Wi-Fi Direct → `PrivateNetworkException` for that method. `join` / `leaveJoined` / `stopHotspot` / `stopWifiDirect` / `startListening` / `stopListening` only `_invoke` the same method names as macOS. `WindowsInvitePresenter.present()` invokes `presentWindow` and nothing else. → verify: `flutter analyze lib/platform/desktop/windows_proximity_radios.dart`

2. Add `test/windows_proximity_radios_test.dart`. Copy the messenger setup from `test/macos_proximity_radios_test.dart` (`TestDefaultBinaryMessengerBinding`, mock the method channel, `MockStreamHandler` on the three event channels, clear them in `tearDown`). Cases:
   - `startAdvert` with 3 bytes throws `ArgumentError` and the mock records no `startAdvert` call.
   - `startAdvert` with a 31-byte payload invokes `startAdvert` and the arguments contain that payload.
   - A scans event with 31 advert bytes becomes one `BleScanHit` with that `peerHandle`. A 4-byte advert is dropped.
   - `connect` RFCOMM throws `StateError` with message `rfcomm unavailable` and records no `connectControl`.
   - GATT `connect` then `send({'x25519': 'peer-key'})` records `sendFrame` whose `frameJson` contains `x25519` and `peer-key`.
   - Method reply `{error: hotspotFailed}` makes `startHotspot` throw `PrivateNetworkException` with `HostMethod.hotspot`, not a `String` and not a `PlatformException`.
   - Method reply `{error: wifiDirectFailed}` makes `startWifiDirect` throw `PrivateNetworkException` with `HostMethod.wifiDirect`.
   - `currentWifi` replies `null`, then a map with an empty `passphrase`: both `readCurrentPersonalPsk` calls return null and do not throw.
   - `WindowsInvitePresenter.present()` records only `presentWindow`.
   → verify: `flutter test test/windows_proximity_radios_test.dart`

3. Add `windows/runner/windows_proximity.h` and `windows/runner/windows_proximity.cpp`. Declare `void RegisterWindowsProximity(flutter::BinaryMessenger* messenger, Win32Window* window)`. In the cpp file include `flutter/method_channel.h`, `flutter/standard_method_codec.h`, and `win32_window.h`. Keep the `MethodChannel` in a function-local `static` `unique_ptr` so it outlives the handler registration. Handler methods, all replying exactly once:
   - `presentWindow`: `HWND hwnd = window->GetHandle()`. If null, `result->Error("noWindow", "window missing")`. Else `ShowWindow(hwnd, SW_RESTORE)`, `SetForegroundWindow(hwnd)`, `result->Success()`.
   - `startHotspot`: `Success` map `error` = `hotspotFailed`.
   - `startWifiDirect`: `Success` map `error` = `wifiDirectFailed`.
   - `stopHotspot`, `stopWifiDirect`, `leaveJoined`: `Success()`.
   - `join`: `Success` map `error` = `joinFailed`.
   - `currentWifi`: `Success(nullptr)`.
   - `startAdvert`, `stopAdvert`, `startScan`, `stopScan`, `connectControl`, `startListening`, `stopListening`, `sendFrame`, `closeLink`: `Success` map `error` = `bleUnavailable`.
   - Anything else: `result->NotImplemented()`.
   Add `windows_proximity.cpp` to the `add_executable` list in `windows/runner/CMakeLists.txt`. From `FlutterWindow::OnCreate`, after `RegisterPlugins`, call `RegisterWindowsProximity(flutter_controller_->engine()->messenger(), this)`. → verify: the new cpp is listed in `CMakeLists.txt` and `OnCreate` calls it. Do not run `flutter build windows` on Linux.

4. Confirm mDNS was not edited. `test/platform_services_mock_test.dart` still expects `windowsAdvertiseLimitation` to contain `manual connect`. → verify: `flutter test test/platform_services_mock_test.dart test/windows_proximity_radios_test.dart`

5. Presence check, then the full gate. → verify:

```bash
test -f Makefile && grep -q '^verify:' Makefile
test -f lefthook.yml
test -f analysis_options.yaml
make verify
```

### Tests to add

File: `test/windows_proximity_radios_test.dart`. Cases are step 2. No live WLAN, no live BLE, no `netsh`.

### Verify commands

- `flutter test test/windows_proximity_radios_test.dart`
- `flutter test test/platform_services_mock_test.dart`
- `make verify` (analyze + test + debug apk). Windows C++ is not in that gate.

### Risks / pitfalls

- `result->Error("hotspotFailed")` becomes a `PlatformException` in Dart. The host chain wants `PrivateNetworkException`. Reply success with the `error` field.
- Reply exactly once. A missing `Success` hangs the Dart call.
- The `MethodChannel` must stay alive after `SetMethodCallHandler`. A temporary that dies at the end of `OnCreate` drops the handler.
- `GetHandle()` is already null after `WM_DESTROY`. Do not cache a separate `HWND`.
- `windows/**` is analyzer-excluded. A C++ typo will not fail `flutter analyze`. Match the Flutter Windows embedding headers already used by this runner (`flutter::MethodChannel`, `flutter::EncodableValue`, `flutter::StandardMethodCodec`).
- Do not log method arguments. A future PSK reply must not be printed.

### Out of scope

- C++/WinRT, `Windows.Devices.Bluetooth`, and a real GATT server.
- `netsh`, WLAN hosted network, Mobile Hotspot settings, Wi-Fi Direct.
- Wiring the radios into `DesktopPlatformServices` (T12).
- Invite Accept UI (T13). `presentWindow` only.
- A second mDNS stack. Windows advertise is the existing Bonsoir broadcast, not a new responder.
- `flutter build windows` on this machine.

### Execute model recommendation

- **medium** — Dart mirrors the macOS channel, but the Win32 handler has to reply with a success envelope and stay registered. Do not grow that into a WinRT stack.

## Test Plan

- Mocked Windows binding tests
- Commands: `make verify`

## Acceptance Criteria

- [x] Port methods exist and are covered by fakes
- [x] mDNS advertise is on for Windows via Bonsoir, same as Linux and macOS
- [x] `make verify` green
- [x] No secrets committed

## Verification

- Tooling presence: `Makefile` `verify`, `lefthook.yml`, `analysis_options.yaml` — present.
- `flutter test test/windows_proximity_radios_test.dart test/platform_services_mock_test.dart`: radios tests plus advertise-supported assertion. Short advert throws before the channel. Hotspot and Wi-Fi Direct throw `PrivateNetworkException`. Null and empty `currentWifi` return null. GATT `sendFrame` keeps `x25519`. Invite calls only `presentWindow`.
- User override after execute: Windows no longer skips Bonsoir. `MdnsDiscovery.start` advertises and browses on Windows. `supportsAdvertising` and `supportsMdnsAdvertising` are true off the web.
- `make verify` (2026-10-04, after Windows Bonsoir advertise): exit 0. Analyze clean, 289 tests, debug apk built. Gradle/AGP/Kotlin warnings only. Versions not bumped.
- Close-out `make verify` (2026-10-04): exit 0. Analyze clean, 289 tests, debug apk built.
- `flutter build windows` was not run. This machine is Linux. The Win32 channel is in `windows/runner/windows_proximity.cpp`.
- Review follow-up: `scans`, `inbound`, and `frames` are registered as idle event channels. `listen` returns success and no events are sent, so the first Dart listen is not a missing plugin.
- Second review (radios plus Windows Bonsoir advertise): no issues.

## Files Modified

- `lib/core/discovery/mdns_discovery.dart` — Windows uses Bonsoir advertise and browse
- `lib/core/platform/platform_capabilities.dart` — advertise capability on for Windows
- `lib/platform/desktop/windows_proximity_radios.dart` — four T05 ports plus invite presenter
- `test/windows_proximity_radios_test.dart` — mocked channel
- `windows/runner/windows_proximity.h`, `windows/runner/windows_proximity.cpp` — success envelopes, `presentWindow`
- `windows/runner/flutter_window.cpp` — register the channel, clear the window on destroy
- `windows/runner/CMakeLists.txt` — compile the new cpp
- `planning/phases/T10-windows-radios.md`, `planning/phases/INDEX.md`

## Manual test (for humans)

This Linux machine cannot `flutter run -d windows`. On a Windows 10 or 11 machine:

```text
flutter run -d windows
```

Success: the window opens. Settings → Network health shows LAN advertise as visible, not "not supported". Another LAN peer running B-LAN sees this machine without manual connect. First launch may prompt the firewall; allow private networks. Radios are not called until T12, so Nearby BLE, hotspot, and invite do nothing yet.

## Learnings

- bonsoir_windows 7.3.0 already advertises with `DnsServiceRegister`. The browse-only path was an early return in `MdnsDiscovery`, not a missing OS API.
- A Dart event `listen` reports a missing plugin when the runner registers only the method channel. Idle event channels must accept `listen`.
- Hotspot and Wi-Fi Direct failures must be success envelopes. `result->Error` becomes `PlatformException` and skips `PrivateNetworkException`.
- `make verify` does not compile `windows/`. A C++ typo stays invisible on this host.

## Reality notes

- T09 binds the same four ports on `com.brukb.blan/macos`. Hotspot and Wi-Fi Direct return `PrivateNetworkException` when the OS has no API. Do that again here. Do not copy the macOS keychain CLI or the sandbox removal. Shared ids stay in `lib/core/proximity/proximity_ids.dart`.

