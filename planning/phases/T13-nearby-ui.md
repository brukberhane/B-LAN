# T13 — Nearby UI

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T12  
**Next**: T14  
**Layer**: L7

## Description

Peers shows a Nearby section above the mDNS list with same-LAN, other-LAN, and BLE-only badges. Settings holds the visible switch, idle minutes, members-can-invite, and Shizuku. While this device hosts, Peers shows status and Disband (one confirm). The link sheet and short-code dialog use the orchestrator. No new rail destination.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-05 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-05 | execute started | Planned | InProgress | /task-2-execute T13 | user |
| 2026-10-05 | completed | InProgress | Done | /task-3-complete T13. make verify 321 tests, apk | user |

## Requirements

- [x] Nearby rows are separate from mDNS rows and show the badge
- [x] Tap runs the T02 outcomes: immediate open, sheet, or auto host
- [x] Target dialog shows nick, code, host plan, and link plan
- [x] Settings: visible default on, idle default 3, members can invite default on, Shizuku row matches the dead / missing / needs-permission copy
- [x] Remember checkbox on the type-password sheet, default off
- [x] Permission denial banner on Peers while the switch stays on
- [x] Widget tests for badge text, sheet actions, and Disband confirm

## Implementation Plan

### High-level notes (bootstrap)

- Extend `lib/features/peers/peers_page.dart` and `lib/features/settings/`. Rail stays in `lib/app/shell.dart`
- Do not replace the existing peer menu (trust, forget, re-authenticate)

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-05
**Codebase snapshot:** T12 ✅. Branch `T13-nearby-ui`. Peers is an mDNS `ListView` in `lib/features/peers/peers_page.dart`. Settings is `lib/features/settings/settings_page.dart` with one switch (subnet filter). No Nearby widgets. `AppService.proximity` is null in widget tests. Live `lib/app/app.dart` passes `ProximityOrchestrator.production()`. The working tree also has uncommitted post-T12 fixes (inbound listen, failure frame continues the chain, timeout sends `hostFailed`, teardown calls `leaveJoined`). Do not revert those.
**Execute model:** medium

### Context for executor

Peers gets a Nearby section above the mDNS rows. Settings gets the nearby switch, idle minutes, members-can-invite, and a Shizuku row. Taps and the target dialog call `ProximityOrchestrator`. Do not re-decide badges, sheet options, or host order. Do not construct platform radios. Do not call `production()` from a test.

Rail labels stay Shares, Peers, Search, Uploads, Downloads, Settings (`lib/app/shell.dart`). Do not add a destination. Do not replace the mDNS popup menu (trust, forget, re-authenticate, revoke, remove). Row tap on an mDNS peer still opens Browse.

Orchestrator surface (`lib/core/proximity/proximity_orchestrator.dart`): `badgeForHit`, `actionFor`, `openSameLan`, `abort`, `passwordMiss`, `onScan`, `applyInviteResult`, `disband`, `setVisible`, `checkIdle`, `readPersonalPsk`, `presentInvite`, `advertError`, `membersCanInvite`, `idle`, `ble.scans`. Policy stays in `proximity_policy.dart`: `badgeFor`, `tapAction`, `sheetOptions`, `hostChain`, `mintSixDigitCode`. `ble.scans` is not subscribed anywhere yet. `checkIdle` has no timer. `presentInvite` is `(String nick, String code)` and does not carry the host plan. Android `showInvite` plus `inviteResults` already call `applyInviteResult`. Desktop and iOS `present()` only raise a window or post "Nearby invite".

Badge labels: `sameLan` → `Same LAN`, `otherLan` → `Other LAN`, `bleOnly` → `BLE only`.

`TapFacts`: `trusted`, `badge`, `localHasWifi`, `remoteHasWifi`. `LinkSheetOptions`: `showUseLanMine`, `showUseLanTheirs`, `showPrivateNetwork`, `showShortCode`. `sheetOptions` throws unless the action is a sheet. `UserAbort.sheetCancel` and `UserAbort.codeDecline` abort. `passwordMiss` walks the host chain and must not read the PSK.

Nearby DB (`lib/core/persistence/database.dart`): `nearbyVisible` default true, `nearbyIdleMinutes` default 3, `nearbyMembersCanInvite` default true, `nearbyShizukuChoice` null until asked. Remembered Wi-Fi: `RememberedWifiStore.save(..., {bool remember = false})` in `lib/core/security/remembered_wifi.dart`. SSID and security go to Drift. The passphrase goes to the secret store only when `remember` is true. Never log a passphrase.

Shizuku states from `AndroidShizukuConsent.state()`: `dead`, `notInstalled`, `tooOld`, `ready`, `noPermission`, `unknown`. Settings copy, and no other wording:

| State | Copy |
| ----- | ---- |
| `dead` | Start it in Shevery |
| `notInstalled`, `unknown` | Install Shevery or Shizuku |
| `noPermission`, `tooOld` | Needs permission |
| `ready` | Ready |

### Steps

1. Add `InvitePrompt` in `lib/core/proximity/proximity_types.dart`: `nick`, `code`, `hostPlan` (`List<HostStep>`), `useLanMine`, `useLanTheirs`, `usePrivateNetwork`. Change `presentInvite` to `Future<void> Function(InvitePrompt prompt)?`. Every current call site passes that object. Android `showInvite` still gets `prompt.nick` and `prompt.code`. Update `test/proximity_orchestrator_test.dart` call sites. Add `bool get isPrivateNetworkUp => _privateUpSince != null`. Add `Future<void> bindPeer({required AttemptDevice remote, required String peerHandle})` that sets `remoteDevice`, sets `link` from the existing RFCOMM-then-GATT `_connect`, and throws `StateError('local device unset')` when `localDevice` is null. Add `Future<AttemptEndReason> startPrivateAttempt({required AttemptDevice remote, required String peerHandle})` that calls `bindPeer` then `runHostPlan` with `localDevice`, that remote, `extraMembers`, the link, and `session`. Add `Future<AttemptEndReason> skipPassword({required AttemptDevice remote, required String peerHandle})` that calls `bindPeer` then `passwordMiss`. `skipPassword` does not call `readPersonalPsk`. → verify: `flutter test test/proximity_orchestrator_test.dart`

2. `AppService` methods, no UI yet. `setNearbyVisible(bool)` writes `db.setNearbyVisible` and calls `proximity?.setVisible(value, foreground: true)` when the orchestrator exists. `setNearbyIdleMinutes(int)` writes the DB and sets `proximity?.idle`. `setNearbyMembersCanInvite(bool)` writes the DB and sets `proximity?.membersCanInvite`. `disbandNearby()` calls `proximity?.disband()`. After `_startProximity`, if `proximity` is non-null, start `Timer.periodic(const Duration(seconds: 30))` that awaits `refreshLoad` then `checkIdle(DateTime.now())`. Cancel that timer in `shutdownSharing`. Replace `presentInvite` after `production()` builds the orchestrator: assign a callback that sets `pendingInvite` (`ValueNotifier<InvitePrompt?>` on `AppService`). If `Platform.isAndroid` and the app is paused, also call `AndroidInvitePresenter.showInvite(nick: prompt.nick, code: prompt.code)` on the same presenter instance `production()` already listens to — do not construct a second presenter. On Linux, macOS, Windows, and iOS, also call that platform `present()`. Do not drop the Android `inviteResults` → `applyInviteResult` subscription. → verify: `dart analyze lib/core/services/app_service.dart lib/core/proximity/proximity_orchestrator.dart`

3. `lib/features/settings/nearby_settings_section.dart`. Pure `String shizukuSettingsCopy(String state)` with the table above. Section watches the database through `databaseProvider` and calls the new `AppService` setters. Rows: visible `Switch` default from `nearbyVisible`; idle minutes integer field default 3, reject `< 1` the same way `setNearbyIdleMinutes` does; members-can-invite `Switch` default on; Shizuku `ListTile` whose subtitle is `shizukuSettingsCopy`. On Android the state comes from `AndroidShizukuConsent().state()`. Off Android the subtitle is `Install Shevery or Shizuku` and the tile is disabled. Add the section to `SettingsPage`'s `ListView`. Do not add a rail destination. → verify: `flutter test test/widget_features_test.dart`

4. `lib/features/peers/nearby_section.dart`, inserted above the mDNS `ListView` children in `PeersPage`. If `appService.proximity` is null, the section is empty. Otherwise listen to `proximity.ble.scans` and keep the latest `BleScanHit` per `peerHandle`. Nick is the scan-response UTF-8, or `Nearby` when empty. Badge: `badgeForHit(hit, onLocalSubnet: hostSharesLocalSubnet(dotted ipv4, lan subnets), helloSucceeded: a trusted or any peer row already exists for that host and port)`. `localHasWifi` is `lanIpv4Addresses().isNotEmpty`. `remoteHasWifi` is `ProximityAdvert.hasWifi`. `trusted` is true only when a peer row with `trusted == true` has `shortPeerIdFromUuid(peer.id)` equal to the advert short id. Do not hello the peer just to paint the badge. Do not extend the 31-byte advert. Remote `AttemptDevice.kind` is `ProximityDeviceKind.android` (kind is not in the advert; the chain already drops Wi-Fi Direct when this device cannot join). Local kind matches `localDevice.kind`.

   Tap: if `role` is owner or member and `groupId` is not four zeros, call `onScan(hit)` and do not open a sheet. Otherwise `actionFor`:
   - `openLan` → `openSameLan(host: dotted ipv4, port: advert.port)`. No hotspot.
   - `showSheetWithCode` or `showSheetWithoutCode` → dialog from `sheetOptions`. Show the short code from `mintSixDigitCode` only when `showShortCode`. Show host plan as `hostChain(local: localDevice, remote: remote).map((s) => s.toString())`. Show the link flags that are true. Cancel calls `abort(UserAbort.sheetCancel)`. Short-code Decline calls `abort(UserAbort.codeDecline)`. Private network calls `startPrivateAttempt`. Use-my-LAN calls `readPersonalPsk`. Null opens a type-password sheet: SSID, passphrase, security `wpa2Psk` or `wpa3Sae`, Remember checkbox default off, Skip, Cancel. Remember true calls `RememberedWifiStore.save` with that flag. Skip calls `skipPassword`. Cancel calls `abort(UserAbort.sheetCancel)`. Do not log the passphrase. Do not write it to SQLite yourself.
   - `skipSheetStartHostChain` → `startPrivateAttempt` with no sheet.

   When `advertError != null`, show a banner `Nearby is blocked` plus `advertError`. Do not turn the visible switch off.

   When `isPrivateNetworkUp`, show `Hosting a private network` and a Disband button. One confirm dialog. Confirm calls `disbandNearby()`. Dismiss calls nothing.

   Target dialog: watch `AppService.pendingInvite`. Show nick, code, each host step, and the three link flags. Accept calls `applyInviteResult('accept')` and clears the notifier. Decline calls `applyInviteResult('decline')` and clears it. → verify: `flutter test test/nearby_ui_test.dart test/widget_test.dart`

5. Presence gate. → verify: `test -f Makefile && grep -q '^verify:' Makefile && test -f lefthook.yml && test -f analysis_options.yaml && make verify`

### Tests to add

`test/nearby_ui_test.dart`. Build `ProximityOrchestrator` with `FakeBlePresencePort`, `FakeControlChannelPort`, `FakePrivateNetworkPort`. Pass it as `AppService(..., proximity: orch)`. Never call `production()`.

- Three rows from three hits. Expect text `Same LAN`, `Other LAN`, `BLE only`. `sameLan` hit has a non-zero ipv4, `onLocalSubnet` true, and a peer row already at that host:port so `helloSucceeded` is true. `otherLan` has a non-zero ipv4 and no such row. `bleOnly` has ipv4 `0.0.0.0`.
- mDNS popup menu still has `Trust peer`. Rail still has no seventh destination. Pump `AppShell` the way `test/widget_test.dart` does, with `proximity` null, and expect no `Nearby is blocked` crash.
- Password skip: sheet for an untrusted other-LAN hit, tap the private-network path only if that is not the skip under test. The skip under test is the type-password sheet's Skip. Preconditions on the orchestrator are whatever `skipPassword` needs so it does not throw before `passwordMiss`. Desktop local device plus iOS remote, codec null. Expect one `startHotspot` and zero `startWifiDirect`. Expect no frame string containing `t05-psk-token`.
- Disband: `isPrivateNetworkUp` true (run a codec-null desktop→iOS `runHostPlan`, which leaves the network up). Tap Disband, dismiss the confirm, expect `stopHotspot` count unchanged. Tap Disband, confirm, expect `stopHotspot` increased by one.
- `shizukuSettingsCopy('dead')` is `Start it in Shevery`. `shizukuSettingsCopy('notInstalled')` is `Install Shevery or Shizuku`. `shizukuSettingsCopy('noPermission')` is `Needs permission`. A settings widget pump shows the visible switch on and idle `3`.

### Verify commands

```bash
flutter test test/nearby_ui_test.dart test/proximity_orchestrator_test.dart test/widget_test.dart test/widget_features_test.dart
test -f Makefile && grep -q '^verify:' Makefile && test -f lefthook.yml && test -f analysis_options.yaml && make verify
```

### Risks / pitfalls

- `production()` on Linux opens the system bus. Widget tests that call it hang or fail. Use fakes.
- `presentInvite` today ignores the host plan. The target dialog cannot show the plan until step 1 widens the callback. Do not keep a second nick-only dialog.
- Replacing `presentInvite` must keep one Android presenter. A second `AndroidInvitePresenter()` drops Accept on the floor.
- `passwordMiss` before `bindPeer` throws `StateError('password miss without an attempt')`.
- An android-to-android `runHostPlan` waits for the remote frame. Widget tests that need the chain to finish use desktop local plus iOS remote, or they hang.
- `sheetOptions` throws when the action is `openLan` or `skipSheetStartHostChain`.
- Do not put the passphrase in a log, a BLE advert, mDNS TXT, or a Drift column other than the secret-store path inside `RememberedWifiStore`.
- Do not revert the uncommitted orchestrator fixes already in this working tree.
- Grouped hits (`owner` or `member`, non-zero `groupId`) call `onScan` only. A new hotspot on that tap is the wrong path.
- Idle timer must `refreshLoad` before `checkIdle`. Clients or in-flight transfers keep the network up.

### Out of scope

- A new `NavigationRail` destination.
- Reordering `hostChain` or adding Wi-Fi Direct for desktop or iOS.
- A new byte in the 31-byte advert.
- `ProximityOrchestrator.production()` inside a test.
- E2E on two handsets (T14).
- A second HTTP client, Nearby Connections, WPA-Enterprise.

### Execute model recommendation

- medium — the policy and the orchestrator already exist. The work is widgets plus three orchestrator entry points (`InvitePrompt`, `bindPeer`, `skipPassword` / `startPrivateAttempt`). A lesser agent that builds a second radio stack or calls `production()` from a widget test will fail the gate.

## Test Plan

- Widget tests
- Commands: `flutter test` widget files and `make verify`

## Acceptance Criteria

- [x] No new `NavigationRail` destination
- [x] Widget tests cover the three badges and the password-skip path's call into the orchestrator
- [x] `make verify` green
- [x] No secrets committed

## Verification

- presence: `Makefile` `verify:` target, `lefthook.yml`, `analysis_options.yaml` present
- lint: `flutter analyze` — no issues
- tests: `flutter test` — 321 passed
- build: `flutter build apk --debug` — `app-debug.apk` (Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 deprecation warnings only; versions not bumped)
- command: `make verify` exit 0 (2026-10-05), re-run at close-out. 321 tests, apk. Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 warnings only; versions not bumped.

## Files Modified

- `lib/core/proximity/proximity_types.dart` — `InvitePrompt`
- `lib/core/proximity/proximity_orchestrator.dart` — `presentInvite(InvitePrompt)`, `isPrivateNetworkUp`, `bindPeer`, `startPrivateAttempt`, `skipPassword`; `idle` assignable
- `lib/core/services/app_service.dart` — nearby setters, 30s idle timer, `pendingInvite`, `presentInvite` wrap
- `lib/app/providers.dart` — `nearbyOrchestratorProvider` and `pendingInviteProvider` default null
- `lib/app/app.dart` — live overrides for those providers
- `lib/features/settings/nearby_settings_section.dart` — new
- `lib/features/settings/settings_page.dart` — section wired
- `lib/features/peers/nearby_section.dart` — new
- `lib/features/peers/peers_page.dart` — Nearby above mDNS, including the empty list
- `test/nearby_ui_test.dart` — new
- `test/proximity_orchestrator_test.dart` — `presentInvite` takes `InvitePrompt`; failed accept host continues
- `lib/core/proximity/proximity_radio_fakes.dart` — hotspot-up hook for that test
- `planning/phases/T13-nearby-ui.md`, `planning/phases/INDEX.md`
- `.cursor/rules/proximity.mdc`, `.cursor/rules/flutter.mdc`, `README.md`
- Uncommitted T12 follow-up kept in the same commit: failure frame continues, inbound listen, `leaveJoined`

## Manual test (for humans)

```bash
flutter run -d linux
```

Open Peers. Nearby sits above the mDNS list (empty is fine without a second device). Open Settings and scroll to Nearby visible (on), Idle minutes 3, Members can invite (on), Shizuku disabled with "Install Shevery or Shizuku". The rail is still Shares, Peers, Search, Uploads, Downloads, Settings. A missing BlueZ adapter may log a radio error and must not crash the shell. This machine does not prove a phone-to-phone invite.

## Learnings

- An idle app does not draw a frame by itself. A callback registered for the end of the frame needs an explicit frame request, or it waits until something else dirties the tree.
- A widget test `pump()` with no duration can skip a rebuild that was scheduled from a stream. Elapse time.
- Clearing the prompt slot after the handler that promotes the queue erases the next invite. Clear first, and only if the slot still holds the prompt just answered.
- The accept-owned host loop must release a step whose secret was not sent and continue, same as the initiator loop.

## Reality notes

- T12 (2026-10-05): `ProximityOrchestrator` is live. `lib/app/app.dart` passes `production()` except on web. `providers.dart` stays `AppService(db)`. Widget tests must not call `production()` — Linux opens the system bus.
- Call the orchestrator. Do not construct platform radios from the UI, and do not reorder `hostChain`.
- `presentInvite` is `InvitePrompt` after T13. Android `showInvite` still gets nick and code. Desktop and iOS `present()` only raise the window. The Flutter target dialog shows nick, code, host plan, and link flags when the app is resumed.
- `checkIdle` is not on a timer. A Disband control calls `disband()`. If a timer is added, refresh in-use counts first. Clients and in-flight transfers keep the network up.
