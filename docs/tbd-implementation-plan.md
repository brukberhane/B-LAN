# B-LAN TBD Implementation Plan

Last reviewed: 2026-07-01

## Implementation Status

| Phase | Status | Notes |
|-------|--------|-------|
| 1 Transfer protocol contract | **complete** | Manifest DTOs, `/manifest/files/<id>`, chunk route tightened, client `fetchFileManifest`, tests pass |
| 2 Verified resumable downloads | **complete** | Schema v4, `download_chunks` wired, manifest-based verify/resume; hash format is base64 SHA-256 (matches indexer, not hex per plan) |
| 3 Parallel chunk downloads | **complete** | Pool up to `maxConcurrentDownloads`; per-chunk open/write/close behind serial lock; fetch retry x3; `cancelActiveDownload()` groundwork |
| 3.5 Transfer alignment cleanup | **complete** | `GET /chunks?hash=`; `path_safety.dart`; `download_states.dart`; relative-path targets; `sourcePeerId`; cancel → `cancelled`; sync `queueDownload` TODO |
| 4 Folder downloads | **complete** | `listEntriesRecursive`, `downloadFolder`, browse folder download button, one DB row per file |
| 5 Desktop indexing hardening | **complete** | `ShareWatcher` (desktop), `scanShareIncremental`, DB helpers, schema v5 indexes, 30m reconcile fallback |
| 6 Platform validation and UI polish | **complete** | UI surfacing pass, platform capabilities in Settings, README + test matrix, token rotate |
| 7 Security UX | **complete** | Ed25519 device identity, trust/identity_changed workflow, session expiry, token rotate/revoke |
| 8 Multi-source downloads | pending | — |
| 9 libSQL benchmark | pending | — |
| 10 Tests / stress / release | pending | — |

This document replaces the loose TBD list with an implementation order and detailed work plan. It assumes the current app state:

- Drift + bundled SQLite schema v4 is the active persistence layer.
- Share scanning, SHA-256 chunk hashing, HTTP server, mDNS, Android SAF prototype, and core UI exist.
- Downloads are currently single-peer manifest-based chunk transfers with verification, resume, and bounded parallel fetch.
- Preserve current external changes: `bonsoir: ^7.1.4`, no `bonsoir_linux_dbus`, no `configureBonsoirPlatform()` call, current `setSetting()` behavior, and peer delete confirmation.

## Recommended Priority Order

Original suggested order was useful, but transfer work should be split and pulled forward because many later features depend on the same protocol and DB contract.

1. **Transfer protocol contract**
   - Add manifest and chunk metadata DTOs/endpoints.
   - Reason: resume, verification, folder downloads, web polish, and multi-source need stable chunk metadata.

2. **Verified resumable downloads**
   - Wire `downloads` + `download_chunks`, resume existing partial files, verify each chunk, and finalize atomically.
   - Reason: core promise of D-LAN-like sharing; highest user-facing correctness risk.

3. **Parallel chunk downloads and queue control**
   - Use configured concurrency, retry chunks, and persist per-chunk state.
   - Reason: performance work is safer after verified chunk state exists.

3.5. **Transfer alignment cleanup**
   - Close implementation shortcuts from Phases 1-3 before building folder downloads on top.
   - Reason: relative paths, URL-safe chunk hashes, and state consistency get harder to retrofit after recursive queues.

4. **Folder downloads**
   - Recursively queue remote folders with path-safe target creation.
   - Reason: uses hardened single-file queue and exposes real app value.

5. **Desktop indexing hardening**
   - Wire file watcher, incremental rescan, and periodic fallback.
   - Reason: shared indexes must stay valid before relying on chunk routes long term.

6. **Platform validation and polish**
   - Verify Bonsoir 7/Linux, Android real-device behavior, Windows discovery limits, web manual client, and surface all implemented backend features in UI.
   - Reason: implementation exists but needs hardware/network proof and current UI lags behind core capability.

7. **Security UX**
   - Add real identity keypair, trust workflow, token rotation/revoke, and TLS design.
   - Reason: trust gates should sit on stable peer/session flows.

8. **Multi-source downloads**
   - Fetch chunks from multiple peers exposing matching hashes.
   - Reason: depends on verified chunk downloads plus remote manifest/cache.

9. **Persistence engine benchmark**
   - Compare current SQLite/Drift against local-only libSQL if packages are viable.
   - Reason: benchmark after representative transfer/indexing workloads exist.

10. **Stress, integration, and device tests**
    - Add continuously as features land; final pass validates MVP readiness.
    - Reason: tests should lock behavior after each implementation slice, then broaden.

## Phase 1: Transfer Protocol Contract

### Goals

- Expose enough remote file metadata for clients to verify and resume downloads.
- Keep v1 JSON readable and backwards-compatible inside this in-progress branch only where cheap.
- Avoid exposing local filesystem paths.

### Current State

- `TransferServer` exposes `/hello`, `/session`, `/shares`, `/entries`, `/files/<fileId>`, `/chunks/<hash>`.
- `EntryDto` only contains entry metadata and `hashReady`.
- `chunks` table stores offsets, lengths, SHA-256 hashes, and status.
- `/chunks/<hash>` exists but client never uses it.
- `/manifest` is planned but missing.

### Implementation

1. Add DTOs in `lib/core/protocol/models.dart`:
   - `ChunkDto`: `index`, `offset`, `length`, `hash`, `hashAlgorithm`.
   - `FileManifestDto`: `entry`, `chunkSize`, `totalBytes`, `chunks`, `protocolVersion`.
   - `ShareManifestPageDto`: optional later for share-wide browse/search; include `shareId`, `entries`, `nextPageToken`.

2. Add DB helpers in `lib/core/persistence/database.dart`:
   - `Future<Entry?> entryById(String id)`.
   - `Future<List<Chunk>> chunksForEntry(String entryId)`.
   - `Future<FileManifestData> fileManifest(String entryId)`.
   - Optional `entriesForSharePage(shareId, pageSize, pageToken)` only when share-wide manifest lands.

3. Add server routes in `lib/core/transfers/transfer_server.dart`:
   - `GET /manifest/files/<fileId>` returns `FileManifestDto`.
   - Optional later: `GET /manifest?shareId=...&pageSize=...&pageToken=...`.
   - Return `409` if file exists but `hashReady == false`.
   - Return `404` if entry missing, directory, disabled share, or local source missing.

4. Tighten existing `/chunks/<hash>`:
   - Confirm chunk still maps to a current entry with `hashStatus == complete`.
   - Read exact `offset/length` from the source file.
   - Hash bytes before serving only if cheap enough for MVP, otherwise rely on current index and client verification.
   - Return clear `404` when stale.

5. Update `TransferClient`:
   - Add `fetchFileManifest(peer, entry, token)`.
   - Keep `/files/<id>` path for web/simple fallback.
   - Prefer manifest path for native downloads.

### Tests

- Protocol JSON round-trip tests for new DTOs.
- Server integration: manifest success, un-hashed file `409`, directory `404`, stale chunk `404`.
- Ensure manifest never contains absolute `localPath` or `localUri`.

### Acceptance

- Client can fetch a file manifest with ordered chunk metadata.
- Existing browse UI still works.
- `flutter test` passes.

## Phase 2: Verified Resumable Downloads

### Goals

- Resume interrupted downloads from existing `*.partial`.
- Verify every completed chunk against manifest hash before marking complete.
- Use `download_chunks` as source of truth for progress and recovery.

### Current State

- `TransferClient.downloadEntry()` inserts a `downloads` row and writes from offset 0.
- Existing `*.partial` is overwritten.
- `download_chunks` table exists but is unused.
- Completion renames partial file to final target.

### Implementation

1. Extend schema only if needed:
   - Current `DownloadChunks` has `chunkIndex`, `hash`, `offset`, `length`, `state`.
   - Consider migration v4 adding `downloadedBytes`, `verifiedAt`, `sourcePeerId`, `errorMessage`.
   - Add unique constraint equivalent in code if Drift table cannot change cheaply: one row per `downloadId + chunkIndex`.

2. Add download state helpers in `database.dart`:
   - `createOrResumeDownload(...)`.
   - `upsertDownloadChunks(downloadId, manifest.chunks)`.
   - `pendingDownloadChunks(downloadId)`.
   - `markDownloadChunkWriting/verified/error`.
   - `updateDownloadProgressFromChunks(downloadId)`.
   - `completeDownload(downloadId)`.

3. Change file layout:
   - Final target: `<download dir>/<relative remote path>`.
   - Partial target: `<final>.partial`.
   - Write chunks with `RandomAccessFile.setPosition(offset)` and `writeFrom`.
   - Preallocate/truncate partial to `totalBytes` where supported.

4. Resume logic:
   - On start, fetch manifest.
   - If final target exists and matches size plus full-file/chunk verification, mark complete.
   - If partial exists, verify already marked chunks by reading local bytes and hashing.
   - If DB says verified but bytes fail, reset that chunk and all overlapping chunks to pending.
   - If partial size is larger than expected, truncate or restart.

5. Verification:
   - Use `crypto` SHA-256 for each downloaded chunk.
   - Compare lowercase hex with manifest hash.
   - Mark chunk `verified` only after `flush` succeeds.
   - Final rename only when all chunks verified.

6. Error states:
   - Store recoverable errors on chunk rows.
   - Keep `downloads.state` as `queued`, `downloading`, `paused`, `complete`, `error`.
   - Avoid embedding full exception text in `state`; add `errorMessage` if schema v4.

7. App service:
   - `queueDownload()` should create/resume queue work, not block UI longer than needed.
   - Foreground notification uses DB progress from verified bytes.

### Tests

- Download interrupted after first chunk; second run resumes without re-fetching verified chunk.
- Corrupt partial chunk resets and re-downloads.
- Final file rename happens only after all chunks verify.
- Existing complete file is detected.

### Acceptance

- Killing app mid-download leaves resumable `*.partial`.
- Restart resumes and final file hash matches source manifest.

**Status: complete (2026-07-01).** Implementation notes:
- Chunk hashes verified as base64 SHA-256 to match `hashFileChunks`, not lowercase hex.
- Partial writes use `FileMode.append` + `setPosition` — `FileMode.write` truncates on each open.

## Phase 3: Parallel Chunk Downloads And Queue Control

### Goals

- Download multiple chunks concurrently with bounded global concurrency.
- Keep resume and verification deterministic.
- Make progress reflect verified bytes, not raw received bytes.

### Current State

- `maxConcurrentDownloads` constant exists; wired in `TransferClient`.

### Implementation

1. Chunk pool scheduler in `TransferClient` with work queue.
2. Per-chunk partial open/write/close behind `_AsyncSerialLock`.
3. Fetch retry (3 attempts) for transient errors; hash mismatch fails immediately.
4. `cancelActiveDownload()` in-memory cancellation groundwork.

### Tests

- Parallel download creates byte-identical file.
- Retry recovers from one failed chunk response.
- Hash mismatch marks error and never finalizes.

### Acceptance

- Large file downloads with at most configured concurrency.
- DB shows verified chunk progress during transfer.

**Status: complete (2026-07-01).** Implementation notes:
- Default pool size `maxConcurrentDownloads` (3); overridable in constructor for tests.
- Disk writes serialized; fetches run in parallel.
- Persisted `paused` state deferred.

## Phase 3.5: Transfer Alignment Cleanup

### Goals

- Remove shortcuts from Phases 1-3 before recursive folder downloads multiply them.
- Make download storage layout match remote relative paths.
- Make chunk hash routes robust for base64 hashes.
- Make download/chunk state names and progress semantics consistent across DB, UI, and tests.

### Current State

- File manifests are per-file only; share-wide manifest remains deferred.
- Downloads verify base64 SHA-256 because the indexer stores base64 digests.
- `GET /chunks/<hash>` accepts raw hash in the path. Base64 can contain `/`, `+`, and `=`, which are awkward or unsafe in URL path segments.
- `downloadEntry()` writes to `<download dir>/<entry.name>`, not `<download dir>/<entry.path>`, so duplicate names from different folders collide.
- `download_chunks.sourcePeerId` exists but is not written for single-source transfers.
- `paused` is a planned state, but only in-memory `cancelActiveDownload()` exists.
- `queueDownload()` still awaits the whole download; no background queue/controller layer exists yet.

### Implementation

1. Make chunk identifiers URL-safe:
   - Prefer `Uri.encodeComponent(chunk.hash)` in the client and route decode on the server.
   - If Shelf router cannot safely capture encoded slashes, change route to `GET /chunks?hash=...`.
   - Add tests with hashes containing `/`, `+`, and `=`.
   - Keep manifest hash format unchanged for now: base64 SHA-256.

2. Align file target paths:
   - Change single-file download target from `entry.name` to sanitized `entry.path`.
   - Create parent directories for nested paths.
   - Reject unsafe paths: `..`, absolute roots, Windows drive prefixes, empty path segments, NUL/control chars.
   - Add a small path helper in transfer code or `core/protocol/path_safety.dart` before Phase 4 uses it.

3. Normalize state handling:
   - Keep fixed strings: `queued`, `downloading`, `paused`, `complete`, `error`, `cancelled`.
   - Add constants or a small value class for download/chunk states before more UI depends on them.
   - Decide whether `cancelActiveDownload()` maps to `paused` or `cancelled`; do not leave cancelled transfers as `error`.
   - Store `sourcePeerId` on each chunk when fetched from a peer, even for single-source.

4. Tighten resume semantics:
   - Use relative-path target as part of resume identity.
   - If manifest hash list changes, reset stale chunks and keep the same download row only if target identity still matches.
   - Avoid duplicate `download_chunks` rows for the same `downloadId + chunkIndex`; enforce in helper logic or add a DB uniqueness constraint in the next migration if needed.

5. Keep app/service behavior explicit:
   - Do not build full background queue here unless small.
   - Add a note or TODO in `AppService.queueDownload()` that the method is still synchronous from UI perspective.
   - Make UI wording avoid implying queued/background behavior until Phase 6 UI pass.

### Tests

- Chunk route works for base64 hashes containing `/`, `+`, and `=`.
- Single-file download preserves nested relative path.
- Unsafe remote paths are rejected and never write outside download root.
- Cancelled/paused path leaves DB state as intended.
- Source peer ID is recorded on verified chunks.

### Acceptance

- Phase 4 can safely recurse remote directories without path collisions or traversal risk.
- Chunk fetches are URL-safe for existing base64 hashes.
- Download/chunk states are represented consistently enough for UI polish.

## Phase 4: Folder Downloads

### Goals

- Let user download a remote directory recursively.
- Preserve relative folder structure under the B-LAN downloads directory.
- Reuse hardened single-file download pipeline.

### Current State

- Browse UI displays directories and files.
- Download action targets single file entries.

### Implementation

1. Add recursive listing in `TransferClient`:
   - `listEntriesRecursive(baseUrl, shareId, path, token)`.
   - Traverse directories breadth-first.
   - Skip directory rows for actual transfer; create local dirs.

2. Add queue model:
   - Either one `downloads` row per file, or add a future `download_groups` table.
   - MVP: one row per file, derive folder progress in UI by relative path prefix or in-memory group.

3. Path safety:
   - Normalize remote paths with `/`.
   - Reject `..`, absolute paths, drive prefixes, empty file names, and control chars.
   - Use `package:path` to create platform paths.

4. UI:
   - In `BrowsePage`, directory download button queues recursive download.
   - Show snackbar with file count.
   - Downloads page can remain file-row based initially.

5. Android:
   - Target app downloads dir first.
   - SAF target directory selection can be separate later.

### Tests

- Recursive queue from nested remote entries.
- Path traversal input rejected.
- Empty folder creates directory or is skipped with clear state.

### Acceptance

- Downloading a remote folder produces expected local tree and verified files.

## Phase 5: Desktop Indexing Hardening

### Goals

- Keep share index fresh without full manual rescans.
- Avoid deleting and rebuilding entire share indexes for common file changes.
- Keep `/chunks/<hash>` trustworthy as files change.

### Current State

- `ShareScanner.scanShare()` clears whole share index and rescans.
- `watcher` dependency exists but is not imported.
- Android folder watching remains unreliable.

### Implementation

1. Add `lib/core/indexing/share_watcher.dart`:
   - Wrap `DirectoryWatcher` from `package:watcher`.
   - Desktop only: Linux/macOS/Windows.
   - Debounce bursts per share.
   - Emit changed relative paths and parent directories.

2. Add incremental scanner path:
   - `scanShareIncremental(shareId, changedPaths)`.
   - For changed file: stat, compare size/mtime, rehash only if changed.
   - For delete: remove entry and chunks.
   - For new directory: enumerate subtree.
   - For rename: treat as delete+add unless watcher gives reliable move event.

3. DB helpers:
   - `entryBySharePath(shareId, relativePath)`.
   - `deleteEntryWithChunks(entryId)`.
   - `upsertEntryAndChunks(...)` in a transaction.
   - Add useful indexes in schema v4 if query plans need them: `entries(share_id, relative_path)`, `chunks(entry_id)`, `chunks(hash)`.

4. Periodic fallback:
   - Desktop: schedule low-frequency full reconcile while share enabled.
   - Android/SAF: keep manual rescan and maybe compare tree document timestamps if available.

5. Progress:
   - Full scan keeps current progress card.
   - Incremental scan uses `scanStatus = updating` and `currentFile`.
   - Do not reset total counters unless running full scan.

### Tests

- Change file updates chunks and mtime.
- Delete file removes chunks.
- Add nested directory indexes new files.
- Full rescan still works.

### Acceptance

- Editing a shared file invalidates old chunks and exposes new hashes without manual rescan on desktop.

## Phase 6: Platform Validation And Polish

### Goals

- Convert prototype platform support into known-good MVP behavior.
- Document platform limitations honestly.
- Bring UI up to parity with implemented core features, not only platform-specific behavior.

### Linux And Bonsoir 7

1. Verify discovery on Linux with current `bonsoir: ^7.1.4`.
2. Test against Avahi running and stopped.
3. Confirm README no longer says `bonsoir_linux_dbus` if code does not use it.
4. If Bonsoir 7 needs runtime setup, document packages and failure UI.

### Windows

1. Keep current browse-only support as MVP unless Bonsoir advertise works.
2. Investigate Windows advertising options:
   - Bonsoir native support.
   - Custom mDNS responder.
   - Manual-peer-first fallback.
3. Do not add fragile advertise code unless two Windows instances can discover each other.
4. Add UI copy: "Windows can browse peers; advertise may require manual connect" if still true.

### Android

1. Real-device matrix:
   - Android 10, 13, 14+ if available.
   - Wi-Fi multicast enabled and disabled networks.
   - App foreground/background during scan and download.
2. SAF validation:
   - Large directory scan.
   - Nested folders.
   - Files deleted/renamed while scanning.
   - Persisted URI permission after restart.
3. Foreground service:
   - Notification permission denied path.
   - Long hash/download while screen off.
   - Stop service on app shutdown/error.
4. Downloads:
   - App documents/downloads dir works.
   - Later: user-selected SAF target directory.

### Web

1. Smoke test Flutter web manual connect:
   - Host URL and browser token.
   - Browse shares.
   - Download file via browser.
2. CORS:
   - Current `*` default is usable but blunt.
   - Add settings for allowed origins only when needed.
3. Web storage limitations:
   - Keep browser downloads simple.
   - Do not promise resumable web downloads until File System Access API path exists.

### Desktop UX

1. Firewall guidance:
   - Show local port.
   - Explain inbound LAN prompt.
   - Offer copyable manual URL/token.
2. Tray/background:
   - Defer until core transfer queue stable.
   - If added, keep service lifecycle explicit.

### UI Feature Surfacing Pass

This phase must include a full walk through implemented backend capability and make sure users can see, trigger, or understand it from UI. Current UI is intentionally thin and trails the feature work.

1. Shares UI:
   - Show share storage type (`filesystem` vs `saf`) and enabled state.
   - Expose rescan and remove actions clearly.
   - Surface scan/hash status, current file, file count, byte progress, and errors.
   - Show whether a share is currently discoverable/served.

2. Browse UI:
   - Show breadcrumb path and current share name.
   - Distinguish hash-ready files from files still indexing on the remote peer.
   - Disable or explain downloads when remote hash manifest is not ready.
   - Add folder download action after Phase 4.
   - Show download target path preview after Phase 3.5 relative-path alignment.

3. Downloads UI:
   - Show verified bytes, total bytes, percent, state, and error messages.
   - Show chunk progress if available: verified chunks / total chunks.
   - Surface resume behavior: "Resume" for interrupted/error downloads where safe.
   - Add cancel/pause controls only after state semantics are aligned.
   - Show source peer and, later, multi-source count.

4. Peers UI:
   - Show discovered/manual source, last seen, host/port, fingerprint, and trust state.
   - Surface session/auth failure separately from peer absence.
   - Keep remove confirmation.
   - Add trust actions in Phase 7.

5. Settings UI:
   - Browser token: copy, rotate, revoke after token helpers exist.
   - Manual web-client instructions: URL, port, token, and CORS caveats.
   - Show platform capability summary: discovery, advertise, sharing, downloads.
   - Add firewall/manual-connect help on desktop.

6. Platform-specific UI:
   - Android: notification permission state, multicast lock status where useful, SAF share limitations, foreground-service explanation.
   - Windows: browse-only/advertise limitation if still true.
   - Linux: Avahi/Bonjour dependency guidance if discovery fails.
   - Web: manual-connect-only mode and no sharing/server/discovery.

7. UX acceptance sweep:
   - Every implemented core feature has a reachable UI path or explicit "not surfaced yet" note.
   - Every known platform limitation appears in UI or docs.
   - README claims match what the UI can actually do.

### Tests

- Manual platform checklist in `docs/platform-test-matrix.md` or section in README.
- Automated tests where platform APIs can be mocked.
- Widget tests for newly surfaced UI actions where cheap.

### Acceptance

- README platform claims match tested behavior.
- Known gaps are visible in UI or docs, not hidden.
- User can discover available features without reading source code.

## Phase 7: Security UX

### Goals

- Keep LAN-simple UX while preventing silent peer identity swaps.
- Make browser token control visible and reversible.
- Decide TLS later based on browser and hostile-LAN needs.

### Current State

- Peer ID is UUID.
- Fingerprint is derived from peer ID, not from a keypair.
- `trusted` exists but no trust workflow uses it.
- Native sessions and browser token exist.

### Implementation

1. Device identity:
   - Add keypair generation at first launch.
   - Store private key in local settings or platform secure storage if dependency is acceptable.
   - Public key included in `/hello`.
   - Fingerprint = hash(public key), displayed to user.

2. Protocol:
   - Add `publicKey` and `identityVersion` to `HelloResponse`.
   - Keep `peerId` stable.
   - If a known peer ID presents a different fingerprint, mark as `identity_changed` and require user action.

3. Trust UI:
   - In `PeersPage`, show fingerprint and trust state.
   - Add "Trust peer" and "Forget trust".
   - Gate downloads behind trust, or allow "download once" with warning for MVP.

4. Sessions:
   - Keep `/session` but bind session to requesting peer ID and expiry.
   - Store session expiry with token in settings or add session table later.
   - Handle expired session by re-authenticating.

5. Browser token:
   - Settings actions: copy, rotate, revoke.
   - Optional one-time token later.
   - Origin allowlist optional after web smoke testing.

6. TLS:
   - Draft only unless required:
     - Self-signed cert derived from device key.
     - Native clients pin fingerprint.
     - Browser UX is hard because self-signed cert warnings break simple web connect.
   - Keep HTTP LAN MVP unless threat model changes.

### Tests

- Known peer fingerprint mismatch is detected.
- Trust state survives restart.
- Rotated browser token rejects old token.
- Expired session refreshes.

### Acceptance

- User can see and manage peer trust and browser token.
- Silent peer identity change cannot be ignored accidentally.

## Phase 8: Multi-Source Downloads

### Goals

- Download different chunks of the same file from multiple peers when hashes match.
- Keep correctness anchored on chunk hash verification.

### Prerequisites

- File manifests expose chunk hashes.
- `download_chunks` stores per-chunk state.
- Remote entries/cache can identify same content by hash list or file manifest.

### Implementation

1. Remote manifest cache:
   - Use `RemoteEntriesCache` initially for raw manifest JSON.
   - Later add normalized `remote_files` and `remote_chunks` tables if needed.

2. Source discovery:
   - For selected file, find peers with same file hash list or chunk hashes.
   - Start simple: same file size + identical chunk hash sequence.
   - Advanced: allow partial overlap by chunk hash.

3. Scheduler:
   - For each pending chunk, choose best source:
     - Trusted and online.
     - Lowest recent failure count.
     - Fastest moving average.
   - Store attempted source in memory; optionally persist last source in `download_chunks.sourcePeerId`.

4. Failure behavior:
   - If a source fails a chunk, retry another source.
   - Hash mismatch penalizes source and may mark peer suspicious.

5. UI:
   - Download row shows source count.
   - Detail later shows chunk/source distribution.

### Tests

- Two test servers each serve different chunks; client completes file.
- One peer fails mid-download; scheduler switches.
- Mismatched chunk never finalizes.

### Acceptance

- Multi-source improves resilience without changing final verification rules.

## Phase 9: Persistence Engine Benchmark

### Goals

- Decide whether local-only libSQL is worth adding.
- Keep Drift API as app boundary.
- No Turso cloud/sync.

### Current State

- `AppDatabase.open()` uses `driftDatabase(name: dbPath)`.
- `sqlite3_flutter_libs` is included.
- No libSQL dependency exists.

### Implementation

1. Define benchmark workloads:
   - Insert/update 100k entries and chunks.
   - Concurrent read of entries while hash worker writes chunks.
   - Download queue updates: many chunk state transitions.
   - Chunk lookup by hash.
   - Migration/open/close reliability.

2. Add benchmark harness:
   - `tool/db_benchmark.dart` or `benchmark/db_benchmark.dart`.
   - Generate deterministic fixture data.
   - Run each workload on a temp DB.
   - Print JSON results for easy comparison.

3. Backend abstraction:
   - Keep `AppDatabase.open()` default unchanged.
   - Add optional factory only for benchmark.
   - Do not put experimental libSQL path in production app until package works on desktop and Android.

4. Evaluate libSQL:
   - Check package maturity and offline-only support.
   - Verify Linux, Windows, macOS, Android packaging.
   - Compare p50/p95 operation times and crash recovery.

### Tests

- Benchmark harness should not affect `flutter test`.
- Production DB remains Drift/SQLite unless explicitly changed.

### Acceptance

- Decision doc records: keep SQLite, switch to libSQL, or revisit later, with measured data.

## Phase 10: Tests, Stress, And Release Readiness

### Goals

- Convert current prototype into a repeatable MVP validation suite.
- Catch regressions in transfer correctness and platform claims.

### Automated Tests

1. Protocol:
   - DTO round trips.
   - Version defaults.
   - Invalid JSON handling where relevant.

2. Transfer server:
   - `/files` range success and invalid ranges.
   - `/chunks` success and stale/missing hash.
   - `/manifest/files/<id>`.
   - Auth required except `/hello` and `/session`.
   - CORS headers for web flow.

3. Transfer client:
   - Resume partial file.
   - Verify chunks.
   - Retry transient failures.
   - Reject corrupt chunks.
   - Final rename atomic behavior.

4. Indexing:
   - Chunk planning.
   - Full scan.
   - Incremental add/change/delete.
   - Progress counters.

5. DB:
   - Migration v1 to latest.
   - Unique path/chunk helper behavior.
   - Queue state transitions.

6. UI:
   - Shares page progress card states.
   - Browse file/folder actions.
   - Settings browser token actions.
   - Peers trust actions.

### Stress Fixtures

- Many small files: 50k tiny files.
- Huge file: larger than memory, multiple chunks.
- Rename storms.
- Changed mtime with same size.
- Low disk space if feasible.
- Interrupted source peer.
- Slow network simulation via test server delay.

### Manual Matrix

- Linux to Linux.
- Linux to Android.
- Windows browse/manual connect.
- Flutter web to Linux desktop peer.
- Android background scan/download.

### Acceptance

- `flutter test` passes.
- Manual matrix has current pass/fail notes.
- README reflects only verified behavior.

## Cross-Cutting Notes

### State Names

Prefer fixed enum-like strings:

- Download: `queued`, `downloading`, `paused`, `complete`, `error`, `cancelled`.
- Download chunk: `pending`, `writing`, `verified`, `error`.
- Share scan: `idle`, `scanning`, `hashing`, `updating`, `complete`, `error`.

If states grow, move them into constants or small value classes before they spread.

### Schema Migration Discipline

- Bump `schemaVersion` for every table/column/index change.
- Add migrations for existing prototype DBs.
- Run `dart run build_runner build` after Drift table edits.
- Avoid changing generated `database.g.dart` manually.

### Implementation Branch Strategy

Suggested PR/task split:

1. Protocol DTOs + manifest endpoint + tests.
2. DB helpers + `download_chunks` migration.
3. Verified resume for single-file sequential downloads.
4. Parallel chunk scheduler.
5. Transfer alignment cleanup.
6. Folder download queue.
7. Watcher + incremental scanner.
8. Platform validation, UI surfacing, and docs/test matrix.
9. Trust/token UX.
10. Multi-source.
11. DB benchmark.

### Do Not Do Yet

- Do not add Turso/cloud sync.
- Do not preserve compatibility with legacy C++ D-LAN wire protocol.
- Do not promise full web peer behavior.
- Do not add TLS until trust/keypair and browser UX are decided.
- Do not replace SQLite with libSQL without measured wins on desktop and Android.
