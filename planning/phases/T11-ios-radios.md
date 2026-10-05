# T11 — iOS radios

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T10  
**Next**: T12  
**Layer**: L6

## Description

iOS platform code for the T05 ports, and tests that assert the expected behavior. There is no `ios/` runner today. This task adds it. `flutter test` uses mocks. This Mac also builds and launches the iOS simulator. Bluetooth still needs a device; that stays in Manual test.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-04 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-04 | started | Planned | InProgress | /task-2-execute | user |
| 2026-10-05 | completed | InProgress | Done | verify green, dialectic, INDEX ✅ | user |

## Requirements

- [x] Add the iOS runner without removing Linux, Android, macOS, or Windows
- [x] BLE presence, control channel, and hotspot-or-failure behind the T05 interface. Wi-Fi Direct is not an iOS host mode
- [x] Expected tests exist and pass under mock. They are not skipped and not reduced to a TODO
- [x] `flutter build ios --simulator --debug` succeeds on this Mac, and the app launches in a simulator
- [x] Manual test section lists what a physical iPhone must still prove

## Implementation Plan

### High-level notes (bootstrap)

- `flutter create --platforms=ios .` is the likely way to add the runner. Do not let it rewrite unrelated platforms
- Info.plist needs Bluetooth and local-network usage strings when those APIs are called

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-04
**Codebase snapshot:** T10 ✅ on `T11-ios-radios`. No `ios/` directory. `.metadata` lists android, linux, macos, web, windows. Bundle id is `com.brukb.blan`. T05 ports are `lib/core/proximity/proximity_radios.dart`. Shared ids are `lib/core/proximity/proximity_ids.dart`. macOS binds the ports on `com.brukb.blan/macos` (`lib/platform/desktop/macos_proximity_radios.dart`, `macos/Runner/MacosProximity.swift`). Windows is a stub that returns `hotspotFailed` / `wifiDirectFailed` as success maps, not `FlutterError`. This Mac is Xcode 26.6 with 10 available iPhone/iPad simulators and no phone in `flutter devices`. iOS will not appear there until the runner exists.
**Execute model:** medium

### Context for executor

- **Goal:** Add the iOS runner and a real CoreBluetooth binding for the four T05 ports. Hotspot and Wi-Fi Direct return the typed port failure. The personal PSK read returns null. Unit tests mock the channel. This Mac must compile a simulator build and launch it. A physical iPhone is still required for Bluetooth; do not pretend the simulator found a peer.
- **Key files to create:**
  - `ios/` from `flutter create` (do not hand-write the runner)
  - `lib/platform/ios/ios_proximity_radios.dart` — `IosProximityRadios`, `IosInvitePresenter`
  - `ios/Runner/IosProximity.swift` — CoreBluetooth, join, invite notification, immediate hotspot failure
  - `test/ios_proximity_radios_test.dart`
- **Key files to edit after create:**
  - `ios/Runner/AppDelegate.swift` — register the plugin once the `FlutterViewController` exists
  - `ios/Runner/Info.plist` — Bluetooth, Bonjour, local network, background modes
  - `ios/Runner/Runner.entitlements` (create if the template has none) — Hotspot Configuration only
  - The Xcode project only if Runner is not a synchronized folder
- **Do not edit** T05 abstracts, Android, Linux, macOS, Windows, `hostChain` / `walkHostChain`, `proximity_ids.dart`, `Makefile`, `pubspec.yaml` dependencies. No BLE plugin. No Nearby Connections. Do not `flutter upgrade`.
- **Do not** pass `--platforms` that includes linux, macos, windows, android, or web. That rewrites those runners.

### Why iOS cannot copy the macOS advert

`CBPeripheralManager.startAdvertising` on iOS accepts only `CBAdvertisementDataLocalNameKey` and `CBAdvertisementDataServiceUUIDsKey` (iPhoneOS 26.5 SDK `CBPeripheralManager.h`). Manufacturer data and service data are not advertised. Android and macOS still discover peers by a 31-byte `0xFDA9` manufacturer payload.

So:

- Advertise the service UUID `0000fda9-0000-1000-8000-00805f9b34fb` plus a local name taken from the nick bytes, lossy-decoded as UTF-8, truncated to 20 Unicode scalars. Do not put the 31-byte payload in the local name. Do not pass manufacturer data. If `didStartAdvertising` reports an error, reply `{"error": "advertFailed"}`.
- Keep the 31-byte payload and answer a GATT read of `9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c` with those bytes. Android will still not see this phone in a manufacturer-data scan. That limitation stays. Do not change the Android or macOS scanners in this task.
- Scan like macOS: a hit counts only when manufacturer data is 33 bytes and starts with `D9 FD`. Emit the remaining 31 bytes as `advert`. Drop everything else, including a peer that only shows the service UUID. Do not invent a 31-byte advert.

### Channel

Name: `com.brukb.blan/ios`. Events: `…/scans`, `…/inbound`, `…/frames`.

Reply failures as `result(["error": "<code>"])`, never `FlutterError`, for hotspot, Wi-Fi Direct, scan, advert, listen, connect, and join. `FlutterError` becomes `PlatformException` and skips `PrivateNetworkException`. `presentInvite` uses `FlutterError` code `notifyFailed` only when notification authorization is denied; the Dart presenter catches that and returns. A missing window is not a concept here.

Every parked `FlutterResult` is invoked before it is cleared. If Bluetooth is already `.poweredOff`, `.unauthorized`, or `.unsupported`, reply `{"error": "scanFailed"}` or `{"error": "advertFailed"}` immediately. Do not wait for a later state callback. Stop of an in-flight start completes that parked result with `nil`, then bumps the token so the timeout cannot answer again.

Integers from Dart arrive as `NSNumber`. Read them with `intValue`.

Method results that hop off the main queue are posted back to main before `result` is called.

### Ports

`IosProximityRadios` implements the four ports. `production()` uses `MethodChannel('com.brukb.blan/ios')`.

- `startAdvert` calls `assertAdvertPayload` (length 31) before the channel. Short payload throws `ArgumentError` and must not invoke.
- `connect(..., rfcomm)` throws `StateError('rfcomm unavailable')` before the channel. iOS has no public RFCOMM. That throw is the T12 signal to retry GATT.
- GATT UUIDs from `ProximityIds`. Characteristic is readable and writable (write and write-without-response). Frames are 4-byte big-endian length plus UTF-8 JSON. Cap 64 KiB. Drop that peer buffer on a hostile length. Chunk writes at `maximumWriteValueLength(for: .withResponse)`, floor 20. `send` JSON-encodes the map as given. Do not strip `x25519` or re-sign. One inbound event per central. Drain until a frame is incomplete.
- `startHotspot` → `{"error": "hotspotFailed"}` → `PrivateNetworkException(HostMethod.hotspot)`. No Personal Hotspot API, no `NEHotspotHelper`.
- `stopHotspot` → `nil`.
- `startWifiDirect` → `{"error": "wifiDirectFailed"}` → `PrivateNetworkException(HostMethod.wifiDirect)`. No command.
- `stopWifiDirect` → `nil`.
- `readCurrentPersonalPsk` returns `null` in Dart and does not invoke the channel. iOS will not give a third-party app the current Wi-Fi passphrase.
- `join` sends `ssid`, `passphrase`, `security` (`WifiSecurity.wire`), `localOnly`. Swift ignores `localOnly`. The iPhoneOS 26.5 header `NEHotspotConfiguration.h` (inside `NEHotspotConfigurationManager.h`) has one personal initializer: `initWithSSID:passphrase:isWEP:`. It covers WPA/WPA2 Personal. There is no SAE initializer. Use `NEHotspotConfiguration(ssid:passphrase:isWEP: false)` for both `wpa2-psk` and `wpa3-sae`. `isWEP` stays false. Any other security string, or an `apply` error, replies `{"error": "joinFailed"}`. Do not use the enterprise, Hotspot 2.0, or `joinAccessoryHotspot` APIs. Set `joinOnce = true`. Apply with `NEHotspotConfigurationManager.shared.apply`. Dart maps `joinFailed` to `StateError`, not `PrivateNetworkException`. Do not log the passphrase, including inside `NSError` text. `leaveJoined` calls `removeConfiguration(forSSID:)` for the last SSID this object applied.
- `IosInvitePresenter.present()` invokes `presentInvite` and returns. Swift requests notification authorization if needed and adds a local notification whose title is `B-LAN` and body is `Nearby invite`. No Accept action (T13). Denied permission → `FlutterError` `notifyFailed`, and Dart swallows it.

### Runner

```bash
flutter create --platforms=ios --org com.brukb .
```

Run from the repo root. Confirm afterwards that `android/`, `linux/`, `macos/`, `windows/`, and `web/` have no diff except `.metadata` gaining an `ios` platform entry. If anything else under those trees changed, restore it.

Then set:

- `NSBluetoothAlwaysUsageDescription`: `B-LAN uses Bluetooth to find nearby devices and open a control channel.`
- `NSLocalNetworkUsageDescription`: `B-LAN discovers and shares files with peers on your local network.`
- `NSBonjourServices`: `_blan._tcp`
- `UIBackgroundModes`: `bluetooth-central`, `bluetooth-peripheral`
- Entitlement `com.apple.developer.networking.HotspotConfiguration` = true. Do not add `NEHotspotHelper`, location, or Access WiFi Information.

Register `IosProximity` from `AppDelegate` with `controller.binaryMessenger` (iOS `FlutterViewController` exposes `binaryMessenger` directly). After `flutter create`, if `project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup` for Runner, a new Swift file in `ios/Runner/` is compiled automatically. If sources are listed by hand, add `IosProximity.swift` the same way `macos/Runner.xcodeproj` lists `MacosProximity.swift`.

`didFinishLaunching` must call `super` and return the same `Bool` the template returned. Do not replace the Flutter app delegate.

### Steps

1. `flutter create --platforms=ios --org com.brukb .` Restore any accidental edits outside `ios/` and `.metadata`. → verify: `git status` shows `ios/` plus `.metadata` only, and `android/`, `linux/`, `macos/`, `windows/`, `web/` are clean.
2. Info.plist keys, hotspot entitlement, `ios_proximity_radios.dart`, and `test/ios_proximity_radios_test.dart`. → verify: `flutter test test/ios_proximity_radios_test.dart`
3. `IosProximity.swift` and AppDelegate registration. → verify: `flutter analyze`
4. Simulator compile and launch. Pick the first available iPhone from `xcrun simctl list devices available`. → verify: `flutter build ios --simulator --debug` exits 0, then `flutter run -d <that simulator id>` reaches a running app. Stop the run after the first frame. Do not claim a BLE peer appeared.
5. If step 4 fails because `IDESimulatorFoundation` will not load, run `xcodebuild -runFirstLaunch` once and repeat step 4. If it still fails, stop. Do not delete the iOS code to make `make verify` the only gate.
6. → verify: `export GRADLE_USER_HOME="$HOME/.gradle"; make verify`

### Tests to add

`test/ios_proximity_radios_test.dart`. `TestWidgetsFlutterBinding.ensureInitialized()`. Clear method and stream handlers in `tearDown`. No `skip:`.

1. `readCurrentPersonalPsk` is null and the mock channel records no calls.
2. `startHotspot` mock `{"error": "hotspotFailed"}` → `PrivateNetworkException(HostMethod.hotspot)`.
3. `startWifiDirect` mock `{"error": "wifiDirectFailed"}` → `PrivateNetworkException(HostMethod.wifiDirect)`.
4. `startAdvert` with 3 bytes throws `ArgumentError` and the channel records no call. `startAdvert` with 31 bytes invokes `startAdvert`.
5. A scans event whose `advert` is 31 bytes becomes a `BleScanHit`. A 4-byte `advert` is dropped.
6. `connect(..., rfcomm)` throws `StateError` and does not invoke the channel. `connect(..., gatt)` then `send({x25519: peer-key})` invokes `sendFrame` with that field still in `frameJson`.
7. `IosInvitePresenter.present` invokes `presentInvite` and no other method.

Install empty mock stream handlers for `…/inbound` and `…/frames` before `connect`, or the GATT listen throws a missing plugin.

### Verify commands

```bash
flutter test test/ios_proximity_radios_test.dart
flutter analyze
flutter build ios --simulator --debug
export GRADLE_USER_HOME="$HOME/.gradle"
make verify
```

Do not add the iOS build to `Makefile`. `make verify` stays analyze + test + Android debug apk.

### Risks / pitfalls

- **`flutter create` without `--platforms=ios` rewrites the other runners.** Pass only `ios`.
- **Manufacturer data in `startAdvertising` is ignored or errors.** Service UUID plus local name only. The 31-byte payload is the GATT read value.
- **Android will not list this phone** until a later task teaches that scanner to read the GATT payload. Do not change Android here.
- **Simulator Bluetooth is not a radio.** `startScan` on a simulator should return `scanFailed` (unsupported), not hang. A launched simulator is a build proof, not a peer proof.
- **`FlutterError` on hotspot** skips `PrivateNetworkException`. Use a success map.
- **Parked results.** Stop and radio-off must invoke them. See `flutter.mdc` "Parked channel result is dropped".
- **Passphrase.** Never log it. Never put it in an error string. The PSK read does not exist on iOS; returning null is the fall-through.
- **Do not bump** Flutter, Gradle, AGP, or Kotlin.

### Out of scope

- Changing Android or macOS scan filters so they discover an iPhone
- Orchestrator wiring (`IosProximityRadios.production()` into the shell is T12)
- Invite Accept / Decline UI (T13)
- Personal Hotspot, `NEHotspotHelper`, Wi-Fi Direct, reading the current Wi-Fi passphrase
- A paid Apple Developer enrollment. If no signing team is already in Xcode, the simulator build is the compile gate. Device install stays in Manual test.

### Execute model recommendation

- **medium** — the runner add and the iOS advert limit are fixed above. A small model will either stuff manufacturer data into `startAdvertising` or copy the Windows stub and skip the simulator build.

## Manual test (for humans)

Simulator (this task runs it):

```bash
flutter build ios --simulator --debug
flutter devices
flutter run -d <iphone simulator id>
```

Success: the app opens. Bluetooth calls return the failure envelope. No peer row is required. The simulator has no BLE radio.

Physical iPhone, when one is plugged in and a development team is already selected in Xcode:

```bash
flutter run -d <device id>
```

Success:

- The phone sees an Android or macOS peer that advertises the `FDA9` manufacturer payload. That other device does not need to see this phone for the check to pass.
- Starting a hotspot returns the hotspot failure. No Personal Hotspot toggle flips.
- An invite posts a local notification titled `B-LAN` with body `Nearby invite`. No Accept button.
- GATT: one JSON frame that contains `x25519` arrives intact. No Bluetooth pairing dialog.
- A passphrase read returns empty. The attempt continues.

## Test Plan

- Mocked iOS tests in `flutter test`
- Commands: `make verify`

## Acceptance Criteria

- [x] iOS binding compiles as Dart and is asserted
- [x] iOS simulator debug build succeeds and the app launches
- [x] `make verify` still green
- [x] Device BLE checks are written in Manual test, not treated as done
- [x] No secrets committed

## Verification

- `flutter test test/ios_proximity_radios_test.dart`: 7 passed
- `flutter analyze`: no issues
- `xcrun --sdk iphonesimulator swiftc -typecheck` of `ios/Runner/IosProximity.swift`: exit 0
- `make verify`: analyze clean, 296 tests passed, debug apk built
- `xcodebuild -downloadPlatform iOS`: iOS 26.5 Simulator (23F77) installed. Created and booted simulator `iPhone 17` `8FC59593-C8A1-47B3-BF3E-1FD8BD4AA2B5`.
- `flutter build ios --simulator --debug`: exit 0. `build/ios/iphonesimulator/Runner.app`.
- Launch: `xcrun simctl launch` started `com.brukb.blan` pid 97732 on that simulator. `flutter run` was stopped before it printed a first frame. No BLE peer was expected.
- `flutter create` rewrote `.metadata` to channel main and dropped the other platforms, and `pub get` rewrote `pubspec.lock`. Both were restored. `.metadata` keeps the original revision and adds an `ios` platform entry for the template that was generated (`9aeebc3616`).
- Close-out `make verify` (2026-10-05): analyze clean, 296 tests passed, debug apk built.

## Files Modified

- `.metadata` — ios platform entry only
- `ios/` — runner from `flutter create --platforms=ios`, plus `IosProximity.swift`, entitlements, Info.plist, AppDelegate registration
- `lib/platform/ios/ios_proximity_radios.dart`
- `test/ios_proximity_radios_test.dart`
- `planning/phases/T11-ios-radios.md`, `planning/phases/INDEX.md`

## Manual test (for humans)

## Learnings

- iOS `startAdvertising` accepts only a local name and service UUIDs. The 31-byte payload is the GATT read value. Android and macOS manufacturer scans will not list this phone.
- `flutter create --platforms=ios` replaces the metadata platform list and runs pub get. Restore the other platforms and the lockfile.
- A listed iOS SDK is not a simulator runtime. Download the matching runtime, then create a simulator on it.
- Current iOS templates register plugins on the implicit-engine callback. The messenger is `applicationRegistrar.messenger()`.
- A `FlutterEventSink` stored from a stream handler must be an `@escaping` parameter or the simulator SDK will not compile.
- Hotspot and Wi-Fi Direct are success maps, not `FlutterError`. The personal PSK read returns null and does not call the channel. RFCOMM throws before the channel.
- Stop and a second start must invoke a parked channel result. A late advert callback must match the token that started it.

## Reality notes

- T10 (2026-10-04): Windows mDNS advertise is Bonsoir, same as the other desktops. Do not copy a browse-only early return. Windows radios are a Win32 success-envelope stub (`bleUnavailable`, `hotspotFailed`, `wifiDirectFailed`), not a real BLE stack.
