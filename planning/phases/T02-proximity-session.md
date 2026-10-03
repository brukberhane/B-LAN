# T02 — Proximity session rules

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: T01  
**Next**: T03  
**Layer**: L3

## Description

Pure Dart model of a nearby attempt: badges, link sheet, host choice, password fallthrough, invite queue, and trust outcomes. No radio, no UI. Later tasks call this instead of re-deciding policy.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub from setup-tasks | user |
| 2026-10-03 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-03 | execute started | Planned | InProgress | /task-2-execute T02 | user |
| 2026-10-03 | complete | InProgress | Done | /task-3-complete T02; verify re-confirmed 194 tests | agent |

## Requirements

- [x] Badges: Same LAN only after local-subnet IPv4 and `/hello` success; Other LAN when an address is advertised but that check fails; BLE only otherwise
- [x] Untrusted non-LAN tap yields a sheet: Use a Wi-Fi LAN (mine or theirs, hide a side with no Wi-Fi; if neither has Wi-Fi the action is absent) or Private network
- [x] Host pick defaults to the other device. Android failure order per device: hotspot, then Wi-Fi Direct, then the next device already in the attempt. Desktop: hotspot only. Desktop joiner skips Wi-Fi Direct. Every candidate failing ends the attempt
- [x] Missing or refused LAN password falls through to that chain. Short-code decline and leaving the sheet before a choice abort and store nothing
- [x] Trusted same-LAN opens immediately. Trusted different-LAN shows the sheet without a code. Trusted and neither on Wi-Fi skips the sheet
- [x] One invite at a time, others wait, 60s timeout declines. Six-digit code is minted by the initiator
- [x] Member invite trusts only the admitter and the new fingerprint. Wi-Fi Direct admit is owner-only. Hotspot invite may forward credentials only after accept and only when members-can-invite is on
- [x] Table-driven tests cover each row above. No platform plugins

## Implementation Plan

### High-level notes (bootstrap)

- Rules: `.cursor/rules/proximity.mdc`
- Do not import Flutter bindings or `dart:io` sockets here if a pure library file can hold the types

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-03
**Codebase snapshot:** T01 ✅ on `T02-proximity-session`. `lib/core/proximity/` does not exist. No Dart symbol matches nearby/invite/proximity. Trust lives on Drift `Peer.trusted` via `AppDatabase.trustPeer` (`lib/core/persistence/database.dart:1422`) — this task must **not** call it. Subnet check is `hostSharesLocalSubnet` in `lib/core/platform/lan_addresses.dart` (uses `dart:io`) — this task takes **booleans**, does not import that file. Hello success is `TransferClient.helloAndRegisterPin` — again a boolean in. No `DeviceKind` enum exists; do not import `PlatformCapabilities` (it pulls `dart:io` + Flutter). Existing tests import `package:flutter_test/flutter_test.dart` and `package:blan/...`.
**Execute model:** medium

### Context for executor

- **Goal:** Pure Dart policy for a nearby attempt. Later tasks (T12 orchestrator, T13 UI) call these functions instead of re-deciding badges, sheets, host order, password fallthrough, invite queue, or trust outcomes. No radio, no UI, no Drift, no HTTP.
- **Key files to create** (filenames must contain `proximity` so `.cursor/rules/proximity.mdc` matches):
  - `lib/core/proximity/proximity_types.dart` — enums + input/output records
  - `lib/core/proximity/proximity_policy.dart` — badge, tap, sheet options, abort vs fallthrough, host chain, member-admit, trust decision
  - `lib/core/proximity/proximity_invite_queue.dart` — one-active invite + waiters + 60s timeout
  - `test/proximity_session_test.dart` — table-driven coverage of every Requirements row
- **Invariants** (from `proximity.mdc` + `security.mdc`; do not invent extras):
  1. Badges: Same LAN = advertised IPv4 on a local subnet **and** `/hello` success. Other LAN = an address is advertised but that conjunction fails. BLE only = no advertised address.
  2. Untrusted non-LAN tap → link sheet (with 6-digit code). Trusted same-LAN → open LAN, no sheet. Trusted Other LAN → sheet **without** code. Trusted and neither on Wi-Fi → skip sheet, start host chain.
  3. Missing/refused LAN password → fall through to host chain. Short-code decline and leaving the sheet before a choice → abort, store nothing.
  4. Default host = the **other** device. Android host methods: hotspot then Wi-Fi Direct. Desktop host: hotspot only. Desktop/iOS joiner skips Wi-Fi Direct. Next device already in the attempt. All fail → end.
  5. Accept → mutual trust of the two Ed25519 fingerprints even if Wi-Fi later fails. Decline/timeout/abort → nothing. This layer **returns** a `TrustDecision`; it does not write SQLite.
  6. One invite dialog; others wait; 60s timeout = decline. Code minted by initiator.
  7. Member invite trusts only admitter + new fingerprint. Wi-Fi Direct admit is owner-only. Hotspot credentials forwarded only after Accept and only when the admit is allowed.
- **Allowed Dart:** `dart:math` (`Random`) for the code. No `dart:io`, no `package:flutter/…`, no `database.dart`, no `lan_addresses.dart`, no `transfer_client.dart`. Tests may use `flutter_test`.
- **iOS (locked here, do not ask):** `ProximityDeviceKind.ios` cannot host (empty method list). As joiner it can join hotspot and skips Wi-Fi Direct (same as desktop). T11 may amend Reality notes if iOS hotspot is added.

### Types (`proximity_types.dart`)

Keep these names. Do not add unused fields.

```dart
enum ProximityBadge { sameLan, otherLan, bleOnly }

enum ProximityDeviceKind { android, desktop, ios }

enum ProximityRole { owner, member }

enum PrivateNetworkKind { hotspot, wifiDirect }

enum HostMethod { hotspot, wifiDirect }

enum TapAction {
  openLan,                 // same-LAN: existing browse path, no nearby sheet
  showSheetWithCode,       // untrusted and not same-LAN
  showSheetWithoutCode,    // trusted Other LAN
  skipSheetStartHostChain, // trusted, neither on Wi-Fi
}

enum AttemptEndReason {
  running,
  abortedSheetCancel,
  abortedCodeDecline,
  abortedInviteTimeout,
  hostChainExhausted,
}

class BadgeFacts {
  const BadgeFacts({
    required this.hasAdvertisedIpv4,
    required this.onLocalSubnet,
    required this.helloSucceeded,
  });
  final bool hasAdvertisedIpv4;
  final bool onLocalSubnet;
  final bool helloSucceeded;
}

class TapFacts {
  const TapFacts({
    required this.trusted,
    required this.badge,
    required this.localHasWifi,
    required this.remoteHasWifi,
  });
  final bool trusted;
  final ProximityBadge badge;
  final bool localHasWifi;
  final bool remoteHasWifi;
}

class LinkSheetOptions {
  const LinkSheetOptions({
    required this.showUseLanMine,
    required this.showUseLanTheirs,
    required this.showPrivateNetwork,
    required this.showShortCode,
  });
  final bool showUseLanMine;
  final bool showUseLanTheirs;
  final bool showPrivateNetwork;
  final bool showShortCode;
}

class AttemptDevice {
  const AttemptDevice({
    required this.id,
    required this.kind,
    this.fingerprint = '',
  });
  final String id;
  final ProximityDeviceKind kind;
  final String fingerprint;
}

class HostStep {
  const HostStep({required this.hostId, required this.method});
  final String hostId;
  final HostMethod method;
}

class TrustDecision {
  const TrustDecision.none() : localFingerprint = null, remoteFingerprint = null;
  const TrustDecision.mutual({
    required this.localFingerprint,
    required this.remoteFingerprint,
  });
  final String? localFingerprint;
  final String? remoteFingerprint;
  bool get storesTrust => localFingerprint != null && remoteFingerprint != null;
}
```

Equality on `HostStep` (`==` / `hashCode` on `hostId`+`method`) so tests can `expect(steps, [...])`.

### Policy functions (`proximity_policy.dart`)

All **pure** (no I/O). Exact signatures:

```dart
ProximityBadge badgeFor(BadgeFacts facts);

TapAction tapAction(TapFacts facts);

LinkSheetOptions sheetOptions(TapFacts facts);
// Call only when tapAction is showSheetWithCode or showSheetWithoutCode.
// showPrivateNetwork is always true on a shown sheet.
// showUseLanMine iff localHasWifi; showUseLanTheirs iff remoteHasWifi.
// If neither has Wi-Fi, both LAN flags false (the "Use a Wi-Fi LAN" action is absent).
// showShortCode iff tapAction == showSheetWithCode.

String mintSixDigitCode(Random random);
// Inclusive 0..999999, left-padded to 6 chars. Initiator calls this, not the queue.

List<HostStep> hostChain({
  required AttemptDevice local,
  required AttemptDevice remote,
  List<AttemptDevice> extraMembers = const [],
});
// Default host = remote (the other device), then local, then extraMembers in list order.
// Per host, methods:
//   android → [hotspot, wifiDirect]
//   desktop → [hotspot]
//   ios     → []  (candidate contributes no steps)
// Skip a wifiDirect step when the joiner (the other of {local, remote} that is not the host;
// if extraMembers exist, a step is skipped if *any* non-host device in the attempt cannot
// join WFD). Cannot join WFD: kind != android.
// Empty list means hostChainExhausted — caller maps that to AttemptEndReason.hostChainExhausted.

bool passwordMissingFallsThrough(); // always true; still test it so a future abort cannot hide here.

TrustDecision onInviteAccepted({
  required String localFingerprint,
  required String remoteFingerprint,
});
// always TrustDecision.mutual of those two strings, even if a later host step will fail.

TrustDecision onInviteRejected(); // TrustDecision.none()

bool canAdmit({
  required ProximityRole admitterRole,
  required PrivateNetworkKind network,
  bool membersCanInvite = true,
});
// hotspot + owner → true
// hotspot + member → membersCanInvite
// wifiDirect + owner → true
// wifiDirect + member → false (relay only; owner admits)

bool mayForwardHotspotCredentials({
  required bool accepted,
  required PrivateNetworkKind network,
  required bool canAdmit,
});
// true only when accepted && network == hotspot && canAdmit.
// Never true for wifiDirect. Never true before Accept.

TrustDecision memberInviteTrust({
  required String admitterFingerprint,
  required String newFingerprint,
});
// mutual of those two only — no group-wide fps.
```

`hostChain` joiner rule, concrete: for a 2-device attempt `{local, remote}`, when evaluating a step hosted by A, joiner is B. Skip `wifiDirect` if B.kind is desktop or ios.

Worked examples (put these in tests):

1. remote=android, local=desktop → `[HostStep(remote, hotspot)]` then skip remote WFD (desktop joiner) then `[HostStep(local, hotspot)]`.
2. both android → remote hotspot, remote WFD, local hotspot, local WFD.
3. remote=ios, local=android → ios contributes nothing, then local hotspot, local WFD.
4. both desktop → remote hotspot, local hotspot.

### Invite queue (`proximity_invite_queue.dart`)

No `Timer`. Tests drive time.

```dart
class InviteRequest {
  InviteRequest({
    required this.id,
    required this.initiatorFingerprint,
    required this.targetFingerprint,
    required this.code, // already minted
    required this.enqueuedAt,
  });
  final String id;
  final String initiatorFingerprint;
  final String targetFingerprint;
  final String code;
  final DateTime enqueuedAt;
}

class InviteQueue {
  InviteQueue({this.timeout = const Duration(seconds: 60)});
  final Duration timeout;

  InviteRequest? get active;
  List<InviteRequest> get waiting; // FIFO, unmodifiable view

  void enqueue(InviteRequest request);
  // If active == null, it becomes active. Else append waiting.

  TrustDecision acceptActive();
  // mutual(initiator, target) of the active pair, then promote waiting.head to active.
  // Throw StateError if no active.

  TrustDecision declineActive();
  // TrustDecision.none(), then promote waiting.head.

  TrustDecision? tick(DateTime now);
  // If active != null && now >= active.enqueuedAt + timeout:
  //   treat as decline (none), promote next, return that TrustDecision.none().
  // Else return null.
  // Only expires the current active, once per call. Tests may tick twice to drain two timeouts.
}
```

Default timeout **60 seconds**. Do not change the default to make tests faster — pass a short `timeout:` in tests or use `tick(enqueuedAt.add(timeout))`.

### Steps

1. Create the three `lib/core/proximity/` files with the types and functions above. Empty/incorrect bodies are fine until tests exist; prefer writing tests in the same step as each function. → verify: `dart analyze lib/core/proximity` (or `make lint`) reports the new files with no issues.
2. Implement `badgeFor` + table in `test/proximity_session_test.dart` group `'badge'`. → verify: `flutter test test/proximity_session_test.dart --name badge`
3. Implement `tapAction` + `sheetOptions` + table group `'tap and sheet'`. → verify: same file `--name "tap and sheet"`
4. Implement `mintSixDigitCode`, abort vs fallthrough helpers used by tests (`passwordMissingFallsThrough`, `onInviteAccepted`, `onInviteRejected`). Group `'abort vs fallthrough'`. → verify: `--name "abort vs fallthrough"`
5. Implement `hostChain` + worked examples group `'host chain'`. → verify: `--name "host chain"`
6. Implement `canAdmit` / `mayForwardHotspotCredentials` / `memberInviteTrust` group `'member invite'`. → verify: `--name "member invite"`
7. Implement `InviteQueue` group `'invite queue'`. → verify: `--name "invite queue"`
8. `flutter test test/proximity_session_test.dart` then `make lint` then `make test`. Do **not** skip `make test` — T01 regressions live in transfer tests. Apk build is required only as part of `make verify` at the end if you have time; `/task-3-complete` re-runs the full gate. For execute close-out of this task, run `make verify` once green tests exist. → verify: `make verify` exit 0.
9. Fill **Files Modified** and **Verification** on this stub. Do not commit (that's `/task-3-complete`). Do not implement T03 frames.

### Tests to add

One file: `test/proximity_session_test.dart`. Use a `for (final c in cases)` loop with a small `_Case` class or records. Each Requirements bullet must have at least one row that would fail if that branch were deleted.

**badge** (`badgeFor`):

| hasAdvertisedIpv4 | onLocalSubnet | helloSucceeded | want |
| ----------------- | ------------- | -------------- | ---- |
| true | true | true | sameLan |
| true | true | false | otherLan |
| true | false | true | otherLan |
| true | false | false | otherLan |
| false | true | true | bleOnly |
| false | false | false | bleOnly |

**tap and sheet**:

| trusted | badge | localHasWifi | remoteHasWifi | tapAction | showCode | showMine | showTheirs | showPrivate |
| ------- | ----- | ------------ | ------------- | --------- | -------- | -------- | ---------- | ----------- |
| true | sameLan | true | true | openLan | n/a (do not call sheetOptions) | | | |
| false | sameLan | true | true | openLan | n/a | | | |
| false | otherLan | true | true | showSheetWithCode | true | true | true | true |
| false | bleOnly | true | false | showSheetWithCode | true | true | false | true |
| false | bleOnly | false | false | showSheetWithCode | true | false | false | true |
| true | otherLan | true | false | showSheetWithoutCode | false | true | false | true |
| true | bleOnly | false | false | skipSheetStartHostChain | n/a | | | |

Calling `sheetOptions` when `tapAction` is `openLan` or `skipSheetStartHostChain` should throw `StateError` (one test).

**abort vs fallthrough**:

- `passwordMissingFallsThrough()` is true (LAN password missing).
- Same for a named `passwordRefusedFallsThrough()` if you keep one function — do **not** add a second function; one test that missing and refused are both modeled as "not an abort" via a tiny enum `LanPasswordEvent { missing, refused }` mapped through `isAbort(LanPasswordEvent.missing) == false` and `isAbort(LanPasswordEvent.refused) == false`. Add:

```dart
enum UserAbort { sheetCancel, codeDecline, inviteTimeout }
bool isAbort(Object event) {
  if (event is UserAbort) return true;
  if (event is LanPasswordEvent) return false;
  throw ArgumentError(event);
}
```

Put `LanPasswordEvent` + `UserAbort` + `isAbort` in `proximity_types.dart` / `proximity_policy.dart`. Tests: each `UserAbort` → true; each `LanPasswordEvent` → false.

- `onInviteAccepted(local:'L', remote:'R').storesTrust == true` and fps match L/R.
- `onInviteRejected().storesTrust == false`.

**host chain** — the four worked examples in Context, plus: android host + ios joiner skips WFD (same as desktop joiner).

**member invite**:

| role | network | membersCanInvite | canAdmit | mayForward after accept |
| ---- | ------- | ---------------- | -------- | ----------------------- |
| owner | hotspot | true | true | true |
| owner | hotspot | false | true | true |
| member | hotspot | true | true | true |
| member | hotspot | false | false | false |
| owner | wifiDirect | true | true | false |
| member | wifiDirect | true | false | false |

- `mayForwardHotspotCredentials(accepted: false, …)` is false even when canAdmit.
- `memberInviteTrust(admitter:'A', new:'N')` fps are A and N only.

**invite queue**:

- First enqueue is active; second is waiting (length 1).
- `acceptActive` stores mutual fps of active pair; waiting promotes to active.
- `declineActive` stores nothing; waiting promotes.
- `tick(enqueuedAt + 59s)` returns null, active unchanged.
- `tick(enqueuedAt + 60s)` returns `TrustDecision.none()`, waiting promotes.
- Empty `acceptActive`/`declineActive` throws `StateError`.
- `mintSixDigitCode`: 100 draws, each matches `RegExp(r'^\d{6}$')`; inject `Random(1)` and `Random(2)` and assert the two sequences differ.

Do not sleep. Do not hit the network.

### Verify commands

```bash
flutter test test/proximity_session_test.dart
make lint
make test
make verify
```

### Risks / pitfalls

- Importing `lan_addresses.dart` or `PlatformCapabilities` pulls `dart:io` / Flutter and fails the "no platform plugins" AC. Pass booleans.
- Calling `db.trustPeer` here couples policy to Drift and makes tests need a database. Return `TrustDecision` only.
- `while (!_isCancelled)`-style silent exits (T01 lesson) — if you add a loop, throw or return an explicit `AttemptEndReason`. Prefer no loops except `hostChain`'s two `for`s.
- Counting "Wi-Fi Direct steps" without applying the joiner skip will fail the desktop-joiner example.
- A 60s `Future.delayed` in tests will be treated as a bug. Use `tick`.
- Do not put a passphrase, even a fake `"password"`, in a test name, assertion string that looks like a secret, or a committed fixture. Codes are 6 digits, not PSK.
- Do not add BLE advert packing (T03) or settings persistence for `membersCanInvite` (T04/T13). Default `true` as a function argument is enough.
- `flutter.mdc` glob vs this spoke: keep `proximity` in the **filename**.

### Out of scope

- Control frames, Ed25519 sealing, 31-byte advert (T03)
- SecretStore / Drift Wi-Fi rows (T04)
- Radio ports, Android/Linux/macOS/Windows/iOS plugins (T05–T11)
- Orchestrator Timer, UI sheet widgets, Peers page badges (T12–T13)
- Wiring `hostSharesLocalSubnet` or `helloAndRegisterPin` into this library
- Changing `trustPeer` / purge-untrusted behavior

### Execute model recommendation

- **medium** — many branches; a dropped row is a silent product bug. Not large: no platforms, no I/O, signatures are fully specified.

## Test Plan

- Package tests for the matrix, host chain, queue, and abort vs fallthrough
- Commands: `flutter test` on the new file, then `make lint` at least

## Acceptance Criteria

- [x] Requirements covered by tests that fail if a branch is dropped
- [x] No Android/Linux/BLE calls in this layer
- [x] Full `make verify` green
- [x] No secrets committed

## Verification

*(Filled by `/task-2-execute`; re-confirmed by `/task-3-complete`)*

**Date:** 2026-10-03 (execute)

| Command | Result | Notes |
| ------- | ------ | ----- |
| `flutter test test/proximity_session_test.dart` | exit 0 | 42 tests in `badge` / `tap and sheet` / `abort vs fallthrough` / `host chain` / `member invite` / `invite queue` |
| `make lint` | exit 0 | "No issues found!" (0.9s) |
| `make test` | exit 0 | **194 passed** (152 prior + 42 new) |
| `make verify` | exit 0 | apk `build/app/outputs/flutter-apk/app-debug.apk`; log `tmp/t02-verify.log`. Gradle warns Kotlin 2.2.20 will soon be below min 2.3.20 — not a failure; do not bump in T02 |
| `make verify` (close-out re-run) | exit 0 | lint 0 issues; **194** tests; apk built (`tmp/t02-complete-verify.log`) |

**Policy notes:**

- Host chain skip-WFD if any non-host cannot join WFD. Plan worked-example 3 (ios remote → android local hotspot+WFD) loses to that rule: ios joiner cannot join WFD, so android local is hotspot only. Tests assert the skip.
- Invite timeout clocks from `enqueuedAt` (plan L277), not promote time. Waiters can expire on the next `tick` after a 60s active dialog. T12 must either tick only the active window or reset `enqueuedAt` on promote — do not change T02 without a re-plan.
- No `dart:io` / Flutter / Drift / HTTP in `lib/core/proximity/`.

## Files Modified

*(Filled by `/task-2-execute`)*

- `lib/core/proximity/proximity_types.dart` — enums + facts/decisions (`HostStep` equality)
- `lib/core/proximity/proximity_policy.dart` — badge, tap, sheet, host chain, abort vs fallthrough, member admit, trust decisions
- `lib/core/proximity/proximity_invite_queue.dart` — one-active invite, FIFO waiters, `tick` timeout
- `test/proximity_session_test.dart` — table-driven coverage
- `planning/phases/T02-proximity-session.md` — InProgress + verification
- `planning/phases/INDEX.md` — T02 InProgress

## Manual test (for humans)

Nothing to test — pure policy library with no UI or radio wiring until T12/T13. Unit proof:

```bash
flutter test test/proximity_session_test.dart
```

Expect 42 passing cases across badge, tap/sheet, host chain, invite queue, member admit.

## Learnings

*(Filled by `/task-3-complete` / dialectic)*

- Host-method lists alone are wrong when a non-Android must join: skip Wi-Fi Direct if any non-host cannot join. Encoded in `proximity.mdc`.
- Invite timeout from enqueue time (not promote) can cascade-decline waiters; orchestrator must reset or window ticks. Encoded in `proximity.mdc`.
- Plan worked examples can disagree with a stronger invariant; the join-capability skip wins — document in Verification when that happens.

## Reality notes

T02 shipped `lib/core/proximity/` (types, policy, invite queue). Subnet and `/hello` stay outside (booleans in). iOS host methods empty until T11. iOS/desktop as joiner skips WFD.
