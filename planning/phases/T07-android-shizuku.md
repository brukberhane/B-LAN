# T07 — Android Shizuku passphrase read

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T06  
**Next**: T08  
**Layer**: L6

## Description

Read the current WPA2/WPA3-Personal passphrase through Shizuku or Shevery, using the same provider detection as SecureSettingsManager. If that cannot run, the caller types a password or the attempt falls through. This task does not grant overlay permissions via Shizuku.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-04 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-04 | execute started | Planned | InProgress | /task-2-execute T07 | user |
| 2026-10-04 | close-out | InProgress | Done | reviewer fixes folded, /task-3-complete T07 | user |

## Requirements

- [ ] Detect `com.hamondev.shevery`, `moe.shizuku.privileged.api`, `moe.shizuku.manager`, then the permission / provider / receiver scan from `ShizukuManager.kt`
- [ ] States: unknown, ready, no permission, dead, not installed. Sticky binder listeners. Pre-v11 reported too old
- [ ] One-time ask when a password is needed and the binder is up. Persisted in the T04 Shizuku-allowed setting
- [ ] Privileged `WifiManager` read of the connected or saved personal network. Not `WRITE_SECURE_SETTINGS`. Not the SecureSettingsManager "start after unlock" flow
- [ ] Tests with a fake binder: found Shevery package, permission denied, dead, and a returned PSK that never touches Drift

## Implementation Plan

### High-level notes (bootstrap)

- Reference file: `/home/brukb/projects/Android/SecureSettingsManager/app/src/main/java/com/secure/settings/manager/core/shizuku/ShizukuManager.kt`
- Spoke: `shizuku.mdc`

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-04
**Codebase snapshot:** T06 ✅ (`c2a6030`) on `T07-android-shizuku`. `OsPassphrasePort.readCurrentPersonalPsk` is implemented on `AndroidProximityRadios` as `async => null` (no channel hop). Setting `nearby_shizuku_allowed` is a string in the existing key-value `settings` table: `nearbyShizukuAllowed()` calls `getSetting(..., defaultValue: '0')`, so a missing row and an explicit No both read as false. `getSetting(key)` with the default `''` distinguishes them. No Shizuku dependency in Gradle yet. `mavenCentral()` is already in `android/settings.gradle.kts`. minSdk 24 / compileSdk 36. Reference detector (read, do not copy the settings-writer): SecureSettingsManager `ShizukuManager.kt` — packages, permission names, provider/receiver scan, `ShizukuState`, sticky listeners, `Shizuku.isPreV11()`. That file does **not** read a Wi-Fi PSK. Its Gradle coords: `dev.rikka.shizuku:api:13.1.5` and `dev.rikka.shizuku:provider:13.1.5`.
**Execute model:** medium

### Context for executor

- **Goal:** Ask once (persisted in `nearby_shizuku_allowed`), then read the connected WPA2/WPA3-Personal passphrase through a Shizuku user-service running as shell. Detection must accept Shevery, not only official Shizuku. Failure, enterprise, pre-v11, dead binder, or user No → `null` so the caller types a password or falls through. Do not grant overlay. Do not call `WRITE_SECURE_SETTINGS` or `pm grant`. Do not start Shizuku on unlock.
- **Key files to create:**
  - `lib/core/security/shizuku_detect.dart` — pure package matcher (the only copy of the scan rules)
  - `lib/core/security/shizuku_psk_gate.dart` — ask-once gate over the port
  - `android/app/src/main/kotlin/com/brukb/blan/proximity/ShizukuBridge.kt` — binder listeners, state, package facts, user-service bind, consent dialog
  - `android/app/src/main/kotlin/com/brukb/blan/proximity/WifiPskService.kt` — Shizuku user service; the **only** place that calls hidden WifiManager methods
  - `android/app/src/main/aidl/com/brukb/blan/proximity/IWifiPsk.aidl`
  - `test/shizuku_detect_test.dart`, `test/shizuku_psk_gate_test.dart`
- **Key files to edit:**
  - `android/app/build.gradle.kts` — the two Shizuku dependencies (pin `13.1.5`)
  - `AndroidManifest.xml` — exported user-service `<service android:name=".proximity.WifiPskService" android:exported="true" />`. Do **not** add a hand-written Shizuku provider; the `provider` AAR merges `rikka.shizuku.ShizukuProvider`. Do **not** add `WRITE_SECURE_SETTINGS`.
  - `ProximityPlugin.kt` — new methods on the existing `com.brukb.blan/proximity` channel (no second channel)
  - `lib/platform/android/android_proximity_radios.dart` — `readCurrentPersonalPsk` performs the raw read (channel). Add `AndroidShizukuConsent` for state + permission + ask. Do not import Drift / `RememberedWifiStore` into the read path.
  - `lib/core/persistence/database.dart` — add `nearbyShizukuChoice()` (below). Do not change `nearbyShizukuAllowed()`'s default-false behavior.
  - `test/android_proximity_radios_test.dart` — replace the "returns null without a channel hop" test (that was the T06 stub).
- **Channel methods** (replies are maps or strings; never log the passphrase):
  - `shizukuFacts` → `{ known: [ {name, installed, permissions: [String]} ], candidates: [ {name, permissions, authorities, providerNames, receiverNames} ] }`. `known` is exactly the three packages below, in that order, via `getPackageInfo` (`GET_PERMISSIONS`). Missing package → `{installed: false, permissions: []}`. `candidates` is the slow path: installed apps (skip the three known names) whose requested permissions contain `moe.shizuku.manager.permission`, **or** a provider authority/name contains `shizuku` (ignore case), **or** a receiver name contains `ShizukuReceiver`. Cap candidates at 20. This prefilter is a superset; Dart decides.
  - `shizukuStartListening` / `shizukuStopListening` — `Shizuku.addBinderReceivedListenerSticky`, `addBinderDeadListener`, `addRequestPermissionResultListener`. Remove all three in `stop` and in `ProximityPlugin.dispose`.
  - `shizukuState` → one of `unknown`, `ready`, `noPermission`, `dead`, `notInstalled`, `tooOld`.
  - `shizukuRequestPermission` → `{result: requested|alreadyGranted|error, message?}`. Request code `7001`.
  - `readPersonalPsk` → `{ssid, passphrase, security}` or `null`. `security` is `wpa2-psk` or `wpa3-sae`.
  - `confirmShizukuUse` → `bool` from a main-thread `AlertDialog`: title `Read Wi-Fi password?`, body `Allow B-LAN to read the current Wi-Fi password using Shevery or Shizuku?`, buttons `Allow` / `Not now`.
- **State machine** (Kotlin `shizukuState`, mirror `ShizukuManager.checkState` plus pre-v11):
  1. `Shizuku.pingBinder()` throws or returns false → `isKnownOrCandidateInstalled()` ? `dead` : `notInstalled`. "Installed" = Dart is not available here; use the same package probe: any of the three known packages installed, or `candidates` non-empty after the slow prefilter. Cache the probe for the process.
  2. Binder alive and `Shizuku.isPreV11()` → `tooOld` (do not request permission).
  3. Binder alive and `checkSelfPermission() == PERMISSION_GRANTED` → `ready`.
  4. Else → `noPermission`.
  5. Initial value before the sticky listener fires: `unknown`.
- **Detect (Dart only)** — `detectShizukuPackage` in `shizuku_detect.dart`:
  - Constants, this order: `com.hamondev.shevery`, `moe.shizuku.privileged.api`, `moe.shizuku.manager`.
  - Permissions: `moe.shizuku.manager.permission.MANAGER`, `moe.shizuku.manager.permission.API_V23`.
  - Fast path: first **known** package that is installed and requests either permission.
  - A known package that is installed but lacks both permissions does **not** match (fall through).
  - Slow path: first candidate whose permissions contain either constant, else whose provider authority contains `shizuku` or provider class name contains `ShizukuConnector`, else whose receiver class name contains `ShizukuReceiver` (all ignore case). Same order as `ShizukuManager.findShizukuPackage`.
- **Ask-once gate** — `ShizukuPskGate.read` in `shizuku_psk_gate.dart`. Inputs are functions so tests inject fakes (no Flutter binding required except the channel test):
  - `choice()` → `bool?` (`null` never asked, `false` explicit No, `true` Yes)
  - `persist(bool)` → writes the setting
  - `state()` → the enum string
  - `requestPermission()` → the channel permission call
  - `ask()` → the dialog bool
  - `read()` → raw `OsWifiNetwork?`
  - Rules: if `choice == false` → `null` (no dialog, no read). If `state` is not `ready` and not `noPermission` → `null`. If `choice == null` → `ask()`; persist the answer; No → `null`. If `state == noPermission` → `requestPermission()` then `state()` again; still not `ready` → `null` (leave the setting true — permission denied is not a retract). If `ready` → `read()`.
  - `AppDatabase.nearbyShizukuChoice()`: `final raw = await getSetting('nearby_shizuku_allowed');` (default `''`). `raw.isEmpty` → `null`, `'1'` → `true`, else `false`.
- **Privileged read** (inside `WifiPskService` only, after `Shizuku.bindUserService`):
  - AIDL:
    ```
    interface IWifiPsk {
        String readPersonal();
        void destroy();
    }
    ```
    `readPersonal` returns JSON or `""`.
  - Bind from the bridge (not the main-thread channel handler — worker + `main.post` for `result.success`, same rule as T06):
    ```
    Shizuku.UserServiceArgs(ComponentName(context, WifiPskService::class.java))
        .daemon(false).processNameSuffix("psk").debuggable(BuildConfig.DEBUG).version(1)
    ```
    `ServiceConnection.onServiceConnected` → `IWifiPsk.Stub.asInterface`. Unbind in `dispose`. 8s timeout → Dart `null`.
  - Context inside the service: `android.app.ActivityThread.currentApplication()`.
  - API ≥ 31: reflect `WifiManager.getPrivilegedConnectedNetwork()` → `WifiConfiguration?`.
  - If that is null and API ≥ 30: reflect `getPrivilegedConfiguredNetworks()`, pick the entry whose SSID matches `WifiManager.connectionInfo.ssid` (strip quotes). No match → `null`.
  - API < 30: return `""` (methods are not the shell-visible PSK path).
  - `WifiConfiguration.KeyMgmt` ints: personal = bit 1 (`WPA_PSK`) or bit 8 (`SAE`). If any of bits 2 (`WPA_EAP`), 3 (`IEEE8021X`), 10 (`SUITE_B_192`) are set → treat as enterprise → `""` even if `preSharedKey` is non-null. SAE wins over PSK when both bits are set (`wpa3-sae`, else `wpa2-psk`).
  - Strip surrounding `"` from SSID and `preSharedKey`. Empty, null, or `*` passphrase → `""`.
  - Kotlin must not `Log` the JSON, SSID, or passphrase. Catch reflection failures and return `""`.
- **Dart mapping:** non-empty JSON → `OsWifiNetwork` via `WifiSecurity.fromWire`. Empty / null channel reply → `null`. This path must not call `RememberedWifiStore` or `AppDatabase.insert`.
- **T12 note (do not implement T12):** orchestrator calls `ShizukuPskGate.read`, not the raw port, so the ask happens once. Raw `readCurrentPersonalPsk` is the privileged read only.

### Steps

1. Gradle deps `dev.rikka.shizuku:api:13.1.5` and `:provider:13.1.5` on `implementation`. Manifest: `WifiPskService` exported, no process attribute, no `WRITE_SECURE_SETTINGS`. → verify: `flutter build apk --debug` still green (merger pulls `ShizukuProvider`; if the build fails on the provider authority, stop and report — do not invent a second provider).
2. `shizuku_detect.dart` + `test/shizuku_detect_test.dart` (cases below). → verify: `flutter test test/shizuku_detect_test.dart`.
3. `ShizukuBridge.kt` package probe (`shizukuFacts`) + listeners + `shizukuState` + `shizukuRequestPermission` + `confirmShizukuUse`. Wire methods in `ProximityPlugin` with `main.post` for every reply that leaves a worker thread. `dispose` unregisters listeners. → verify: apk builds.
4. AIDL + `WifiPskService` + `readPersonalPsk` on the bridge. → verify: apk builds.
5. `nearbyShizukuChoice()` + `shizuku_psk_gate.dart` + tests. `AndroidProximityRadios.readCurrentPersonalPsk` calls `readPersonalPsk` and maps the JSON. `AndroidShizukuConsent` exposes `state`, `requestPermission`, `confirm`. Update the old null-without-hop test. → verify: `flutter test test/shizuku_psk_gate_test.dart test/android_proximity_radios_test.dart`.
6. → verify: `make verify`.

### Tests to add

`test/shizuku_detect_test.dart`:

1. Facts list Shevery (installed, permission `API_V23`) before an installed official package → detect returns `com.hamondev.shevery`.
2. Shevery installed but permissions empty, official package has `MANAGER` → official wins (known name alone is not enough).
3. No known package installed; candidate provider authority `com.example.shizuku` → that candidate.
4. Candidate receiver class `com.example.ShizukuReceiver` matches; unrelated packages do not.
5. Empty facts → null.

`test/shizuku_psk_gate_test.dart` (fake functions, no channel):

1. `choice == false` → null, `ask` not called, `read` not called.
2. `state == dead` or `notInstalled` or `tooOld` → null, no ask.
3. `choice == null`, `state == ready`, `ask` returns false → `persist(false)`, null, no read.
4. `choice == null`, `ask` returns true, `state == noPermission`, second `state` is `ready` → `requestPermission` called, then `read`.
5. `choice == true`, `read` returns `OsWifiNetwork(ssid: Home, passphrase: sekret, security: wpa2Psk)` → that value. Assert the gate file does not import `database.dart` / `remembered_wifi.dart` (the test can `expect` the returned passphrase and a `reads` counter of 1 — Drift is never in the call list because the fakes have no database).
6. `read` returns null (enterprise / empty) → null, choice stays true.

`test/android_proximity_radios_test.dart`:

7. Mock `readPersonalPsk` → `{ssid, passphrase: sekret, security: wpa3-sae}` maps to `OsWifiNetwork` / `WifiSecurity.wpa3Sae`. Mock `{error: ...}` is not used; a null reply stays null.
8. Delete the test that expects zero channel calls. Replace with: `readCurrentPersonalPsk` invokes `readPersonalPsk` and no other method (no `setSetting`, no `save`).

### Verify commands

```bash
flutter test test/shizuku_detect_test.dart test/shizuku_psk_gate_test.dart test/android_proximity_radios_test.dart
make verify
```

### Risks / pitfalls

- **Hidden API only works inside the user service.** Calling `getPrivilegedConfiguredNetworks` in the app process returns null or throws. Shell uid (Shizuku) is the subject `shizuku.mdc` names.
- **`nearbyShizukuAllowed()` cannot drive ask-once.** It substitutes `'0'` for a missing row. Use `nearbyShizukuChoice()` / raw `getSetting`.
- **Do not copy** `ensureWriteSecureSettingsGranted`, `executeShellCommand`, `startOrLaunchManager`, or the unlock bootstrap in `refreshState`. Those are SecureSettingsManager's settings writer.
- **Pre-v11:** `Shizuku.isPreV11()` can throw when the binder is dead — catch and keep `dead` / `notInstalled`.
- **`MethodChannel.Result` off the main thread** fails the debug assert (T06). User-service bind callbacks are not the main thread.
- **Passphrase in logs.** `result.success(map)` is fine; `Log` / `println` of that map is not. Tests may hold `sekret` in memory.
- **Enterprise BitSet.** Reflect `allowedKeyManagement` as `java.util.BitSet`. Do not treat "has a preSharedKey" as personal.
- **Provider AAR merger.** If Gradle cannot resolve `13.1.5`, stop. Do not vendor Shizuku sources.
- **T06 test lock.** Replacing the no-hop test is required; leaving it fails `make verify`.
- **Do not bump** Gradle / AGP / Kotlin / Flutter.

### Out of scope

- Settings UI copy ("start it in Shevery", "install Shevery/Shizuku") — T13 reads `shizukuState`
- Orchestrator wiring of the gate — T12 (call `ShizukuPskGate`, not the raw port)
- Linux NetworkManager / macOS keychain / Windows (T08–T10)
- Overlay or full-screen-intent grants via Shizuku
- Remembering the PSK (`RememberedWifiStore`) — a later task may store it; this task only returns it
- `WRITE_SECURE_SETTINGS`, starting Shizuku after unlock, WPA-Enterprise

### Execute model recommendation

- **medium** — one binder client, one user-service, one pure matcher. The plan names the AIDL, the reflection methods, the KeyMgmt bits, and the ask-once table. Not five radios (that was T06 / large).

## Reality notes

- T06 left `readCurrentPersonalPsk` as `async => null` on purpose. T07 replaces that body and the test that pinned the no-hop behavior.
- `getSetting('nearby_shizuku_allowed')` without a default returns `''` when the row is absent. `nearbyShizukuAllowed()` still returns false in that case; do not "fix" it.

## Test Plan

- Fake-binder tests on the Linux host
- Commands: `flutter test` and `make verify`

## Acceptance Criteria

- [x] Shevery package is recognized, not only official Shizuku
- [x] PSK from the fake never appears in a Drift insert
- [x] `make verify` green
- [x] No secrets committed

## Verification

- Tooling presence: `Makefile` `verify`, `lefthook.yml`, `analysis_options.yaml` — present.
- `make verify` (2026-10-04 close-out, `tmp/t07-complete-verify.log`): exit 0. Analyze clean, 254 tests, debug apk built.
- `flutter analyze`: no issues.
- `flutter test`: 254 passing.
- `flutter build apk --debug`: green. Shizuku `api` + `provider` 13.1.5 resolved. AIDL required `buildFeatures.aidl = true` (AGP 8 default off).
- Reviewer ([T07 Shizuku diff](17b74b49-410d-403e-9ef7-26be3228f07e)): 1 red, 3 yellow, all fixed. PSK bind and permission wait run on `radioPool` (main only delivers the reply). User-service unbound after read and on dispose even if listeners were never started. Missing activity is a channel error, not a stored No. Permission reply waits for the grant result.
- Gradle/AGP/Kotlin deprecation warnings only. Versions not bumped.

## Files Modified

- `lib/core/security/shizuku_detect.dart` — package matcher
- `lib/core/security/shizuku_psk_gate.dart` — ask-once
- `lib/core/persistence/database.dart` — `nearbyShizukuChoice()`
- `lib/platform/android/android_proximity_radios.dart` — raw `readPersonalPsk`, `AndroidShizukuConsent`
- `android/app/build.gradle.kts` — Shizuku 13.1.5, `aidl = true`
- `android/app/src/main/AndroidManifest.xml` — `WifiPskService`
- `android/app/src/main/aidl/com/brukb/blan/proximity/IWifiPsk.aidl`
- `android/app/src/main/kotlin/com/brukb/blan/proximity/WifiPskService.kt`
- `android/app/src/main/kotlin/com/brukb/blan/proximity/ShizukuBridge.kt`
- `android/app/src/main/kotlin/com/brukb/blan/proximity/ProximityPlugin.kt`
- `android/app/src/main/kotlin/com/brukb/blan/MainActivity.kt` — resumed activity for the consent dialog
- `test/shizuku_detect_test.dart`, `test/shizuku_psk_gate_test.dart`, `test/android_proximity_radios_test.dart`
- `planning/phases/T07-android-shizuku.md`, `planning/phases/INDEX.md`, `planning/phases/T12-proximity-orchestrator.md`

## Manual test (for humans)

No in-app control yet. `ShizukuPskGate` is not called from a screen until T12, and the state copy is T13. On a handset later: start Shevery, grant B-LAN, join a WPA2/WPA3-Personal network, then a gate read returns that SSID and passphrase and does not insert a Drift row. Enterprise and a missing activity do not stick a No into `nearby_shizuku_allowed`.

## Learnings

- Do not wait on the main looper for a callback that looper must deliver. The PSK bind and the permission result both wait on the radio pool. Only `result.success` / `result.error` hop back to the main thread. Encoded in `flutter.mdc`.
- Hidden WifiManager getters run only inside the Shizuku user service. Unbind after the read and on dispose. Encoded in `shizuku.mdc`.
- A consent dialog that was not shown is a channel error. The gate persists only Allow and Not now. Encoded in `shizuku.mdc`.
- AGP 8 leaves AIDL off. `buildFeatures.aidl = true` was required before `IWifiPsk` existed.
- `nearbyShizukuAllowed()` still treats a missing row as false. Ask-once uses `nearbyShizukuChoice()`.

## Reality notes
