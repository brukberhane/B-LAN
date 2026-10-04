# T08 — Linux radios

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T07  
**Next**: T09  
**Layer**: L6

## Description

Linux bindings for the T05 ports: BlueZ BLE advert/scan and a GATT fallback, classic Bluetooth when available, NetworkManager hotspot, `nmcli --show-secrets` for the current personal PSK, and a window for an invite while the UI is paused. No Wi-Fi Direct group owner.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-04 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-04 | execute started | Planned | InProgress | /task-2-execute T08 | user |
| 2026-10-04 | close-out | InProgress | Done | reviewer fixes folded, /task-3-complete T08 | user |

## Requirements

- [x] Current PSK read uses NetworkManager secrets for a user-owned WPA2/WPA3-Personal profile. No sudo. Polkit may prompt. iwd-only returns empty and the caller types or falls through
- [x] Hosting starts a local-only hotspot and stops it on idle or Disband. Failure returns the T05 error so the orchestrator tries the next device
- [x] Desktop invite raises the app window
- [x] Tests fake NetworkManager and BlueZ. A live adapter is not required for `make verify`

## Implementation Plan

### High-level notes (bootstrap)

- Do not implement Wi-Fi Direct as a Linux host mode
- Joining an Android Wi-Fi Direct group is out of scope. The session layer skips that fallback when a desktop must join

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-04
**Codebase snapshot:** T07 ✅ (`c1c4623`) on `T08-linux-radios`. T05 ports are in `lib/core/proximity/proximity_radios.dart`. Android binds them through `com.brukb.blan/proximity`. Linux runner is the stock GTK embedder (`linux/runner/my_application.cc`); the window is a local in `my_application_activate` and there is no method channel. Desktop code shells out only for `xdg-open` and `systemctl is-active avahi-daemon`. No `dbus` dependency. Kotlin ids that Dart must copy, not change: manufacturer `0xFDA9`, BLE service `0000fda9-0000-1000-8000-00805f9b34fb`, GATT service `9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7b`, GATT characteristic `9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c` (`ProximityIds.kt`).
**Execute model:** medium

### Context for executor

- **Goal:** Linux implementations of the four T05 ports, tested against fakes. NetworkManager reads the current personal PSK and starts a local AP. BlueZ advertises and scans, and GATT carries control frames. Classic RFCOMM is not available, so that connect throws and the later orchestrator retries GATT. An invite while the window is unfocused calls `gtk_window_present`. No Wi-Fi Direct group, no sudo, no live adapter in `make verify`.
- **Dependency:** `flutter pub add dbus` (package `dbus` on pub.dev). Do not add `flutter_blue` or a second HTTP stack. Record the resolved version for `/task-3-complete` (README row + a short `proximity.mdc` docs line).
- **Key files to create:**
  - `lib/core/proximity/proximity_ids.dart` — the UUID constants above. Comment: must match `ProximityIds.kt`.
  - `lib/platform/desktop/linux_command.dart` — `CommandRunner` / `CommandResult` / `SystemCommandRunner` (`Process.run`, no stdin password).
  - `lib/platform/desktop/linux_nm.dart` — parsers + `LinuxNm` (hotspot, stop, join, PSK).
  - `lib/platform/desktop/linux_bluez.dart` — `BluezSession` and `BluezGatt` abstracts, `DBusBluezSession` / `DBusBluezGatt` real types, `FakeBluezSession` / `FakeBluezGatt` for tests.
  - `lib/platform/desktop/linux_proximity_radios.dart` — `LinuxProximityRadios` implementing the four ports. `LinuxInvitePresenter`.
  - `test/linux_nm_test.dart`, `test/linux_proximity_radios_test.dart`
- **Key files to edit:**
  - `linux/runner/my_application.h` — add `GtkWindow* window` on `MyApplication`.
  - `linux/runner/my_application.cc` — keep that window; register `MethodChannel` name `com.brukb.blan/linux`, method `presentWindow`.
- **Do not edit** T05 abstracts, Android radios, or `hostChain()` / `walkHostChain`.

### nmcli (no sudo)

`LinuxNm` takes a `CommandRunner`. Parsers are pure and take the stdout string. Never `debugPrint` stdout or the passphrase. A non-zero exit or an empty secret returns `null` from the PSK read. It does not throw. Hotspot add/up failure throws `PrivateNetworkException(HostMethod.hotspot)` after deleting a half-created `blan-hotspot` connection.

PSK read, in order:

1. `nmcli -t -f NAME,UUID,TYPE,DEVICE connection show --active`
2. Pick the first line whose TYPE is `802-11-wireless` and whose NAME is not `blan-hotspot`. No line → `null` (this is also the iwd-only / NM-absent path when `nmcli` is missing: `SystemCommandRunner` catches `ProcessException` and returns exit code 127, empty stdout).
3. `nmcli --show-secrets -t -f 802-11-wireless-security.key-mgmt,802-11-wireless-security.psk connection show <uuid>`
4. `key-mgmt` `wpa-psk` → `WifiSecurity.wpa2Psk`. `sae` → `wpa3Sae`. `wpa-eap`, `wpa-eap-suite-b-192`, `ieee8021x`, anything else, or an empty psk → `null`.
5. SSID is the connection NAME. Return `OsWifiNetwork`. Polkit may show its own prompt; do not pass `--ask` or a password on the command line.

Hotspot:

1. `nmcli -t -f DEVICE,TYPE device` — first TYPE `wifi`. None → hotspot failure.
2. SSID `BLAN-` plus 4 hex chars from `Random.secure`. Passphrase 16 chars from the same, alphabet `abcdefghijkmnopqrstuvwxyz23456789`. Security `wpa2Psk`.
3. One `nmcli connection add type wifi ifname <dev> con-name blan-hotspot autoconnect no ssid <ssid> 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk <psk>`
4. `nmcli connection up blan-hotspot`. Non-zero → delete `blan-hotspot`, throw `PrivateNetworkException(HostMethod.hotspot)`.
5. Return `HotspotCredentials` with that ssid, passphrase, and `wpa2Psk`.

Stop: `nmcli connection down blan-hotspot` then `nmcli connection delete blan-hotspot`. Ignore non-zero (already gone). Idle and Disband are T12; they will call `stopHotspot`.

`startWifiDirect`: throw `PrivateNetworkException(HostMethod.wifiDirect)` and run no command.

Join: `nmcli device wifi connect <ssid> password <psk>`. Non-zero → `StateError`, not `PrivateNetworkException`. `localOnly` does not change the argv (Linux has no specifier API). `leaveJoined` runs `nmcli connection down id <ssid>` for the last ssid this object connected.

### BlueZ

`LinuxProximityRadios.startAdvert` calls `assertAdvertPayload` before the session. Manufacturer id is `0xFDA9`. Service-data UUID is `ProximityIds.bleServiceUuid`. Scan hits with a payload length other than 31 are dropped.

`BluezSession` (real: system bus via `package:dbus`):

- Find the first `org.bluez.Adapter1`.
- Export `org.bluez.LEAdvertisement1` at a path under `/com/brukb/blan`: `Type=peripheral`, `Discoverable=true`, `ManufacturerData` key `0xFDA9` = the 31 bytes, `ServiceData` key `0000fda9-0000-1000-8000-00805f9b34fb` = the nick bytes.
- `LEAdvertisingManager1.RegisterAdvertisement`. `stopAdvert` unregisters and releases.
- Scan: `Adapter1.SetDiscoveryFilter` (transport `le`) then `StartDiscovery`. Emit a hit when a device's `ManufacturerData` for `0xFDA9` is 31 bytes. `peerHandle` is the device path. `stopScan` calls `StopDiscovery`.
- Bus or adapter failure throws `StateError`. Do not catch it inside the port and return success.

`BluezGatt`:

- `connect(rfcomm)` on the radios throws `StateError('rfcomm unavailable')` before touching BlueZ. T12 retries GATT. Do not register a BlueZ `Profile1`.
- `connect(gatt)` and `startListening` use the Android GATT UUIDs. Listening exports `org.bluez.GattService1` (`9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7b`, primary) and a writable `org.bluez.GattCharacteristic1` (`9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c`), then `GattManager1.RegisterApplication`.
- Frames are 4-byte big-endian length plus UTF-8 JSON, same as Android. Cap a frame at 64 KiB; drop the buffer on a hostile length. `send` writes that blob through `WriteValue` in 20-byte chunks (ATT default). Incoming `WriteValue` calls reassemble and `jsonDecode` onto `ControlLink.incoming`. Kotlin/Dart must not re-sign or strip `x25519`.
- `FakeBluezGatt.connect` returns a link whose `send` records the map and whose `incoming` is a controller the test fills.

### Invite window

In `my_application_activate`, after the `FlView` exists:

- Save `window` on `MyApplication`.
- `fl_view_get_engine` → `fl_engine_get_binary_messenger`.
- `fl_method_channel_new(..., "com.brukb.blan/linux", ...)`.
- Method `presentWindow`: `gtk_window_deiconify` then `gtk_window_present`. Missing window → `fl_method_call_respond_error`.

`LinuxInvitePresenter.present()` invokes `presentWindow` and returns. No dialog, no Accept button (that UI is T13). Tests use `setMockMethodCallHandler` on `com.brukb.blan/linux` and expect that single method.

### Steps

1. `flutter pub add dbus`. `proximity_ids.dart` plus a one-assertion test that the four constants equal the literals above. → verify: `flutter test` on that file.
2. `CommandRunner` and `linux_nm.dart` parsers + hotspot/PSK/join. `test/linux_nm_test.dart`. → verify: `flutter test test/linux_nm_test.dart`.
3. `BluezSession` / `BluezGatt` fakes and `LinuxProximityRadios` over them. Real `DBusBluezSession` and `DBusBluezGatt` in the same library, constructed only by `LinuxProximityRadios.production()` (not by tests). → verify: `flutter analyze`.
4. `presentWindow` in the GTK runner and `LinuxInvitePresenter`. → verify: `flutter test test/linux_proximity_radios_test.dart`. The C code is compiled by the existing `flutter build` linux path inside `make verify` if that target builds linux; if `make verify` is apk-only, still compile-check with `flutter build linux --debug` once.
5. → verify: `make verify`.

### Tests to add

`test/linux_nm_test.dart` with a `CommandRunner` that returns scripted stdout and records argv:

1. Active wifi `Home` / uuid `abc` / `wpa-psk` / psk `sekret` → `OsWifiNetwork` ssid `Home`, security `wpa2Psk`. A second active row named `blan-hotspot` is ignored.
2. `sae` → `wpa3Sae`.
3. `wpa-eap` → `null`. Empty psk → `null`.
4. Runner exit 127 → `null`, no exception.
5. `startHotspot` argv contains `blan-hotspot`, `mode`, `ap`, `wpa-psk`, and the passphrase it returns. No argv contains `wifi-direct` or `p2p`.
6. Scripted non-zero `connection up` → `PrivateNetworkException(HostMethod.hotspot)`, and a later argv is `connection delete blan-hotspot`.
7. `startWifiDirect` throws `PrivateNetworkException(HostMethod.wifiDirect)` with an empty argv log.
8. `stopHotspot` argv includes `connection down` and `connection delete`.

`test/linux_proximity_radios_test.dart`:

9. `startAdvert` with 3 bytes throws `ArgumentError` and the fake session records no call.
10. A fake scan event with 31 manufacturer bytes becomes a `BleScanHit`. A 4-byte payload is dropped.
11. `connect(..., transport: rfcomm)` throws `StateError`. `connect(..., gatt)` then `send({x25519: peer-key})` records that field on the fake.
12. `LinuxInvitePresenter.present` invokes `presentWindow` and no other method.

### Verify commands

```bash
flutter test test/linux_nm_test.dart test/linux_proximity_radios_test.dart
flutter build linux --debug
make verify
```

### Risks / pitfalls

- **stdout is the secret.** `nmcli --show-secrets` prints the PSK. Do not log it, and do not put it in an exception message.
- **`blan-hotspot` is not the user's LAN.** The PSK reader must skip that connection name or it will return the hotspot passphrase as the home PSK.
- **RFCOMM throw is intentional.** Do not shell out to `rfcomm` or `bluetoothctl` connect, which opens a pairing agent.
- **D-Bus on the test isolate.** Tests must not construct `DBusBluezSession`. `production()` is the only caller.
- **`gtk_window_present` needs the stored window.** A local `GtkWindow*` in `activate` is gone after that function returns unless it lives on `MyApplication`.
- **Do not bump** Flutter, Gradle, AGP, or Kotlin.

### Out of scope

- Wi-Fi Direct group owner, and joining an Android Wi-Fi Direct group (session policy already skips that when a desktop must join)
- Idle timer and Disband UI (T12 calls `stopHotspot`)
- Invite Accept / Decline widgets (T13). This task only raises the window
- macOS keychain, Windows, iOS (T09–T11)
- iwd passphrase read
- sudo / pkexec

### Execute model recommendation

- **medium** — nmcli and the fakes are mechanical. The BlueZ advertisement and GATT registration are one D-Bus client with the interface names and UUIDs fixed above, not a second radio stack.

## Reality notes

- T05 `connect` documents that RFCOMM failure is the signal to retry GATT. Linux uses that signal on purpose.
- `make verify` builds an Android debug apk, not the Linux binary. Step 4 still runs `flutter build linux --debug` once so the GTK channel compiles.

## Test Plan

- Fake NM/BlueZ tests
- Commands: `make verify`

## Acceptance Criteria

- [x] Secret read failure is empty, not an exception that aborts the attempt
- [x] Hotspot failure is observable on the port
- [x] `make verify` green
- [x] No secrets committed

## Verification

- Tooling presence: `Makefile` `verify`, `lefthook.yml`, `analysis_options.yaml` — present.
- `make verify` (2026-10-04 close-out): exit 0. Analyze clean, 271 tests, debug apk built. Gradle/AGP/Kotlin deprecation warnings only. Versions not bumped.
- `flutter test test/linux_nm_test.dart test/linux_proximity_radios_test.dart`: 15 passing. PSK miss, enterprise, empty secret, and exit 127 return null. Failed hotspot `up` throws `PrivateNetworkException(hotspot)` and deletes `blan-hotspot`. `startWifiDirect` throws `wifiDirect` with an empty argv log.
- `flutter build linux --debug` (2026-10-04, cmake 4.4.3): `build/linux/x64/debug/bundle/blan`. First attempt failed before cmake was installed.
- dbus 0.7.15 (already transitive via `flutter_secure_storage_linux`; now direct). README row and `proximity.mdc` docs added at close-out.
- Reviewer ([Review T08 Linux radios](4718bc18-2570-4b8e-a07e-694a69bef1e5)): 4 red, 3 yellow, all fixed. Secret lines are `property:value` with `\:` / `\\` unescaped. GATT `connect` calls `Device1.Connect` and waits for `ServicesResolved`. Server `WriteValue` drains every complete frame onto one inbound link per device. Failed advert registration drops the exported object. Window `destroy` clears the pointer before `presentWindow`.

## Files Modified

- `lib/core/proximity/proximity_ids.dart` — shared BLE/GATT ids
- `lib/platform/desktop/linux_command.dart` — `CommandRunner`
- `lib/platform/desktop/linux_nm.dart` — nmcli PSK, hotspot, join
- `lib/platform/desktop/linux_bluez.dart` — BlueZ session, GATT, fakes
- `lib/platform/desktop/linux_proximity_radios.dart` — T05 ports, `LinuxInvitePresenter`
- `linux/runner/my_application.cc` — `presentWindow`
- `test/linux_nm_test.dart`, `test/linux_proximity_radios_test.dart`
- `pubspec.yaml`, `pubspec.lock` — dbus 0.7.15
- `planning/phases/T08-linux-radios.md`, `planning/phases/INDEX.md`

## Manual test (for humans)

No Peers control yet. `LinuxProximityRadios` is not called from the shell until T12, and the invite screen is T13.

```bash
flutter run -d linux
```

Success: the window opens and the process stays up. Closing it and launching again still opens. A personal-PSK or hotspot check waits until the orchestrator calls the ports.

## Learnings

- `nmcli -t` list rows escape colons. `connection show -f` is one `property:value` line, so a fixture of `wpa-psk:secret` does not match a live network.
- A scan device path has no GATT children until `Device1.Connect` and `ServicesResolved`.
- One ATT write can hold two length-prefixed frames. Drain them onto one inbound link per device, or the second frame sits until another write.
- `flutter build linux` needs CMake. `make verify` does not build the Linux binary.

## Reality notes
