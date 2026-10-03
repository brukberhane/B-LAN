# T01 — Verify gate on the existing app

**Status**: Done  
**Parent INDEX**: [INDEX.md](./INDEX.md)  
**Depends-on**: —  
**Next**: T02  
**Layer**: L0

## Description

The Flutter app already lives in `lib/`. This task does not recreate it and does not add nearby behavior. It makes `make verify` pass: `flutter analyze`, `flutter test`, and `flutter build apk --debug`. Linux desktop is `make build-linux` and is not part of the gate.

## Status History

| Timestamp | Event | From | To | Details | User |
| --------- | ----- | ---- | -- | ------- | ---- |
| 2026-10-03 | created | — | Pending | stub seeded by bootstrap | user |
| 2026-10-03 | planned | Pending | Planned | execution plan written by /task-1-plan | user |
| 2026-10-03 | execute started | Planned | InProgress | /task-2-execute T01 | user |
| 2026-10-03 | execute blocked | InProgress | Blocked | lint ✓, apk build ✓, 6 behavior test failures (pre-existing transfer/queue WIP, not gate breakage) | agent |
| 2026-10-03 | tests fixed | Blocked | InProgress | user approved fixing the 6 failures (transfer/queue WIP): 152/152 pass, lint ✓, apk ✓ | user |
| 2026-10-03 | complete | InProgress | Done | /task-3-complete T01 | agent |

## Requirements

- [ ] `make verify` runs analyze, the existing test suite, and `flutter build apk --debug`
- [ ] Failures fixed only when they are gate breakage (analyzer, test compile, apk build). No feature work. A genuine product bug in an existing test is `Blocked`, not a fix here
- [ ] `analysis_options.yaml` and `lefthook.yml` stay the lint and pre-commit inputs

## Implementation Plan

*(Filled by `/task-1-plan` — do not invent during bootstrap beyond high-level notes.)*

### High-level notes (bootstrap)

- App, Drift database, mDNS, and transfer tests already exist
- Host SDK at bootstrap: Flutter 3.47.2 / Dart 3.13.2. Do not `flutter upgrade` the shared SDK here
- A newer stable was advertised and left untouched on purpose

## Execution plan (filled by /task-1-plan)

**Date:** 2026-10-03
**Codebase snapshot:** post-bootstrap. `Makefile` (`verify: lint test build`, `quick-verify: lint test`, `build: flutter build apk --debug`, plus optional `build-linux`), `lefthook.yml` (pre-commit → `make quick-verify`, installed), `analysis_options.yaml` (`package:flutter_lints`, excludes `build/`, `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`). 32 test files under `test/`. Android SDK 36.1.0 at `/opt/android-sdk` (`ANDROID_HOME` set); `flutter doctor` shows Android toolchain `[!]` (minor) and Linux desktop toolchain `[✗]` — apk, not linux, is the gate.
**Execute model:** small (default)

### Context for executor
- Goal: make `make verify` exit 0 on this tree without adding any feature. Verify = `flutter analyze` + `flutter test` + `flutter build apk --debug`.
- Key files: root `Makefile`, `lefthook.yml`, `analysis_options.yaml`, `pubspec.yaml`, `test/*`, `lib/**`.
- Host SDK is Flutter 3.47.2 / Dart 3.13.2 stable. Do not `flutter upgrade` and do not edit SDK-managed files under `flutter/`.
- "Gate breakage" = analyzer errors on existing code, test compilation failures, apk build failures, and environment wiring. An existing behavior test that fails because the product logic is wrong is **not** gate breakage: mark Status `Blocked`, record the failing test and output, stop.
- Do not disable a lint or delete a test to make the gate green. Suppressions need a one-line comment naming why, only for deprecated-API noise from the SDK pin.

### Steps
1. `flutter pub get` → verify: exit 0, `pubspec.lock` refreshed without version churn (diff should be empty or SDK-hash-only).
2. `make lint` (`flutter analyze`) → verify: exit 0. If it fails, fix each issue at the reported file:line with the smallest change. No refactors, no renames, no style sweeps. → verify: re-run exits 0.
3. `make test` (`flutter test`) → verify: "All tests passed!" with 0 failures. If a test fails to **compile**, fix the compile error minimally. If a compiled test fails on **behavior**, re-run it alone (`flutter test test/<file>.dart --name "<case>"`) to confirm, then mark `Blocked` and record output — do not change product code.
4. `make build` (`flutter build apk --debug`) → verify: exit 0 and `build/app/outputs/flutter-apk/app-debug.apk` exists. First run downloads Gradle deps; let it finish. If Gradle fails on missing SDK pieces, accept the `flutter doctor`-named fix only (e.g. licenses via `flutter --version`-level commands), nothing broader.
5. `make verify` (full gate: lint + test + build in order) → verify: single command exits 0 end to end.
6. Confirm hook wiring is untouched: `test -f lefthook.yml && git -C . config core.hooksPath || true` — lefthook manages `.git/hooks`; do not edit `lefthook.yml` unless the run shows it is broken. → verify: `lefthook run pre-commit` is a no-op pass or is left alone.
7. Record results in **Verification** (commands + exit codes + test count + apk path) and list every touched file in **Files Modified**.

### Tests to add
- None. This task adds no behavior. The existing 32-file suite is the proof.

### Verify commands
- `flutter pub get`
- `make lint`
- `make test`
- `make build`
- `make verify` (the gate; must exit 0)

### Risks / pitfalls
- Gradle first-run can exceed 10 minutes on cold cache; run `make build` standalone (step 4) before the combined gate so a timeout is not mistaken for a build failure.
- `flutter doctor` Linux toolchain `[✗]` is expected — `make build-linux` is not in the gate and must not be "fixed" here.
- The Android `[!]` warning must be read before assuming build failure; a warning is not a failure.
- Analyzer may flag deprecated Flutter 3.47 APIs. Suppress with the narrowest `// ignore:` plus a comment, or use the non-deprecated call if it is a one-line change.
- Do not commit `pubspec.lock` churn that upgrades dependencies beyond what `pub get` needs.

### Out of scope
- Any nearby/proximity code (T02+)
- `flutter upgrade`, dependency upgrades, `build-linux` repair
- New tests, refactors, style cleanup beyond gate breakage

### Execute model recommendation
- small — rationale: mechanical gate bring-up; every fix is bounded by an analyzer/test/build message.

## Test Plan

- `make verify` exits 0
- Commands: `make verify` (lint + tests + build)

## Acceptance Criteria

- [x] `make verify` passes on this tree
- [x] No nearby/proximity product code added in this task
- [x] No secrets committed

## Verification

*(Filled by `/task-2-execute`; re-confirmed by `/task-3-complete`)*

**Date:** 2026-10-03 (execute)

| Command | Result | Notes |
| ------- | ------ | ----- |
| `flutter pub get` | exit 0 | `pubspec.lock` changed: SDK-hash-only entries (4), no version churn |
| `make lint` | exit 0 | "No issues found!" — initial run had 54 issues; `dart fix --apply` (44 fixes, 25 files) + 6 manual fixes |
| `make test` | **FAIL** | 146 passed / **6 failed** (behavior, see below) → `Blocked` |
| `make build` (verbose log: `tmp/apk-build.log`) | exit 0 | `BUILD SUCCESSFUL in 50s`; apk at `build/app/outputs/flutter-apk/app-debug.apk` (169 MB) |
| `make verify` (single run) | not run | redundant — gate already fails at `test` step |

**Build toolchain fixes required (all gate breakage):**

- `android/gradle/wrapper/gradle-wrapper.properties`: Gradle 8.11.1 → **8.14** (Flutter 3.47 min)
- `android/settings.gradle.kts`: AGP 8.7.2 → **8.11.1** (Flutter 3.47 min)
- `android/settings.gradle.kts`: Kotlin 2.1.0 → **2.2.20** (Flutter 3.47 min)

**Failing tests (behavior — pre-existing uncommitted transfer/queue WIP, not this session's changes):**

1. `test/download_queue_test.dart` — "cancel marks download cancelled"
2. `test/download_queue_test.dart` — "pause and resume keep partial progress"
3. `test/in_flight_progress_test.dart` — "pause clears inFlightBytes while keeping verified chunks"
4. `test/transfer_client_test.dart` — "resume skips already verified chunks" (expected 1 chunk request, got 2)
5. `test/transfer_client_test.dart` — "existing complete file is detected without download" (expected 0, got 1)
6. `test/transfer_client_test.dart` — "cancel leaves download cancelled in db" (expected throws, emitted null)

Root symptom across failures: drift `Bad state: Can't re-open a database after closing` — `DownloadQueue._loop` keeps polling `AppDatabase.nextQueuedDownload` after tests close the DB; queue loop not stopped on close. Confirmed pre-existing via `git diff` (these files were already modified before T01 started). Per plan rules: no product code changes → `Blocked`.

**Resolution (user-approved, same session):** fixed the 6 failures. Root causes and fixes:

| Failure | Root cause | Fix |
| ------- | --------- | --- |
| db-closed error cascading into next tests | `DownloadQueue.stop()` did not await loop exit | `stop()` awaits a `_loopDone` completer; `start()` registers it |
| "pause clears inFlightBytes", "cancel leaves download cancelled in db" — cancel raced manifest/availability-probe phase before the download row existed | WIP added pre-download HTTP phase (manifest resolve + `/chunks/availability` probe) before row creation; tests used fixed 40–50 ms delays + `getSingle` | tests poll for the download row before cancelling |
| "pause and resume keep partial progress" — no `.partial` at fixed 80 ms | same: partial file created only after probe | test polls for `.partial` existence before pause |
| "resume skips already verified chunks" (expected 1 chunk request, got 2), "existing complete file is detected without download" (expected 0, got 1) | availability probe URL `/chunks/availability` matched the tests' `_isChunkRequest` heuristic (`contains '/chunks/'`); probe is metadata, not a chunk byte fetch | test helpers exclude `/chunks/availability`; manifest-count expectation loosened to ≥ 1 (probe best-effort re-caches the same manifest) |
| cancel before chunk loop exited silently → "Download incomplete" instead of `DownloadCancelled` | `_downloadPendingChunks` used `while (!_isCancelled)` — cancel arriving before the first iteration skipped the in-loop throw | loop head checks `_isCancelled` and throws `DownloadCancelled` |
| cancel window: `_activeDownloadId` registered only after prepare/reconcile | active download registered right after `upsertDownloadChunks` (and cleared on the zero-byte early return) | widens `cancelActiveDownload` window to the whole byte phase |

**Final gate:** `make lint` exit 0 ("No issues found!"), `make test` exit 0 (**152/152 passed**), `make build` exit 0 (`BUILD SUCCESSFUL in 21.1s`, warm cache; apk 169 MB).

## Files Modified

*(Filled by `/task-2-execute`)*

- `pubspec.lock` — SDK-hash-only refresh
- 25 files via `dart fix --apply` — mechanical analyzer fixes (44 total), behavior-neutral
- `lib/core/network/pinned_http_client.dart` — removed unused `_expected` field
- `lib/core/transfers/transfer_client.dart` — removed unused `_maxConcurrentChunkDownloads` field + ctor param + unused `constants.dart` import
- `test/transfer_client_test.dart` — dropped removed `maxConcurrentChunkDownloads: 3` arg (compile fix)
- `lib/features/browse/browse_page.dart` — `if (!mounted) return false;` guards in `_ensureDownloadAllowed` (3 spots)
- `lib/features/downloads/downloads_page.dart` — `context.mounted` guards (clear-completed, open-folder, set-directory); removed unused local `progress`
- `android/gradle/wrapper/gradle-wrapper.properties` — Gradle 8.14
- `android/settings.gradle.kts` — AGP 8.11.1, Kotlin 2.2.20
- `lib/core/transfers/download_queue.dart` — `stop()` awaits loop exit (`_loopDone` completer)
- `lib/core/transfers/transfer_client.dart` — active-download registration moved earlier; chunk loop head throws `DownloadCancelled`
- `test/transfer_client_test.dart` — `_isChunkRequest` excludes availability probe; cancel test polls for row; manifest count ≥ 1
- `test/in_flight_progress_test.dart` — `_isChunkLikeRequest` excludes availability probe; pause test polls for row
- `test/download_queue_test.dart` — pause test polls for `.partial`
- `tmp/apk-build.log` — full verbose build log (gitignored)

## Manual test (for humans)

*(Filled by `/task-3-complete`)*

## Learnings

*(Filled by `/task-3-complete` / dialectic)*

- Flutter stable bumps raise minimums for Gradle wrapper, AGP, and Kotlin simultaneously; read the `DependencyValidationException` line and bump all three in one pass. Encoded in `flutter.mdc`.
- Fixed-delay test waits break when a new async pre-work phase (manifest resolve + availability probe) is inserted; poll for the observable instead. Encoded in `flutter.mdc`.
- Background worker `stop()` must await loop exit, else teardown's closed resources produce unhandled errors that the runner attributes to the *next* test. Encoded in `flutter.mdc`.
- HTTP counting wrappers keyed on path prefixes need explicit metadata-endpoint exclusions (`/chunks/availability` vs chunk byte route). Encoded in `flutter.mdc`.

## Reality notes

*(Amended by upstream `/task-3-complete` if prior tasks changed assumptions)*
