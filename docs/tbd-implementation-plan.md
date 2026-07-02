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
| 6 Platform validation and UI polish | **complete** | UI surfacing pass, platform capabilities in Settings, README + matrix scaffold; manual proof pending |
| 7 Security UX | **complete** | Ed25519 device identity, trust/identity_changed workflow, session expiry, token rotate/revoke |
| 8 Multi-source downloads | **complete** | Manifest cache, chunk scheduler, per-chunk source failover, source count in UI |
| 9 Persistence engine benchmark | **complete** | `tool/db_benchmark.dart`, SQLite baseline JSON, decision doc — keep SQLite |
| 10 Tests / stress / release | **complete** | Expanded automated suite, stress fixtures, matrix scaffold + README |
| 11 Persistent download queue and controls | **complete** | `DownloadQueue` worker, schema v7 groups/queue fields, pause/resume/cancel/retry UI, non-blocking enqueue |
| 11.5 In-flight chunk progress | **complete** | Schema v8 `inFlightBytes`, streaming chunk fetch, throttled progress tracker, Downloads UI shows mid-chunk progress |
| 12 Global search and remote index | **complete** | Schema v9 search tokens + `remote_files`, `GET /search`, share manifest page, `SearchService`, Search UI, signature merge |
| 12.5 Chunk-level swarm scheduling | pending | Torrent-like per-chunk availability, rarest-first, dynamic peer striping |
| 13 Upload visibility and network health | pending | Upload rows, rates, bandwidth/concurrency limits, range hardening |
| 14 Platform proof and native UX | pending | Execute matrix, platform help, Android/Windows/Linux/Web validation |
| 15 Security hardening | pending | Secure storage, session binding, suspicious peer state, token expiry |
| 16 Remote control / headless mode | optional | Decide scope; CLI/admin API/daemon if wanted |
| 17 Chat and LAN presence | optional | Decide scope; D-LAN-style chat if wanted |
| 18 Release engineering and distribution | pending | CI, packaging, migration fixtures, support bundle |

## Implementation Reality Check

Phases 1-10 are **core MVP complete**, not product complete. The Flutter rewrite now has a working verified transfer core, a Drift/SQLite index and queue, peer discovery/manual connect paths, trust UX, folder downloads, multi-source chunk failover, a benchmark harness, and a broad automated test suite. That is enough to validate the architecture and begin real device testing.

What is verified by automated tests:

- Protocol DTOs, default versions, and basic invalid JSON behavior.
- HTTP server auth, CORS, range responses, manifests, chunk serving, and stale/missing file cases.
- Verified resumable downloads, retry, cancellation, corrupt chunk rejection, nested paths, folder downloads, and multi-source failover.
- Share scanning, incremental indexing, stress-scale fixtures, DB indexes, queue state transitions, device identity, sessions, token rotation, and UI smoke/feature widgets.

What is not yet fulfilled:

- The manual platform matrix is still mostly pending. Linux/macOS/Windows/Android/Web claims remain documented expectations until real-device results are recorded in `docs/platform-test-matrix.md`.
- Downloads still execute synchronously from the UI path: `AppService.queueDownload()` blocks until the transfer finishes. There is no persisted worker, queue ordering, pause/resume, delete, or retry controller yet.
- Folder downloads are represented as one DB row per file; there is no folder/group progress model.
- Multi-source discovery only reuses cached matching manifests. There is no global search or normalized remote content index to find identical files by hash across different paths.
- Uploads are served by HTTP but not surfaced as first-class transfer rows. There is no upload page, upload rate, active client list, or bandwidth control.
- Device identity and trust exist, but private keys and browser tokens are still stored through generic settings rather than platform secure storage.
- D-LAN features still missing from the Flutter rewrite include global indexed search, managed queue controls, upload visibility, chat, headless/remote-control mode, richer settings, tray/background integration, and release packaging.

This document replaces the loose TBD list with an implementation order and detailed work plan. It assumes the current app state:

- Drift + bundled SQLite schema v6 is the active persistence layer.
- Share scanning, SHA-256 chunk hashing, HTTP server, mDNS, Android SAF prototype, trust UX, and core UI exist.
- Downloads are currently manifest-based chunk transfers with verification, resume, bounded parallel fetch, folder recursion, and simple multi-source failover.
- Downloads are not yet managed by a persisted background queue; UI-triggered transfers still await completion.
- Manual device/platform proof is pending; `flutter test` coverage does not replace the matrix in `docs/platform-test-matrix.md`.
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

## Post-MVP Priority Guidance

The next work should focus on turning the transfer MVP into a usable product rather than adding more protocol depth first.

1. **Phase 11: Persistent download queue and controls**
   - Highest priority because it fixes the largest UX correctness gap: downloads currently block the UI-triggered call path and cannot be managed after enqueue.
   - Unlocks better Android foreground behavior, desktop tray/background mode, and reliable restart recovery.

2. **Phase 11.5: In-flight chunk progress**
   - Shows real progress while a chunk is streaming instead of waiting for verified chunk completion.
   - Do before Phase 12 because it improves current download UX without expanding discovery scope.

3. **Phase 12: Global search and remote index discovery**
   - Core D-LAN identity feature.
   - Makes multi-source more useful because identical files can be found by hash/signature even when peers store them under different paths.

4. **Phase 12.5: Chunk-level swarm scheduling**
   - Turns multi-source from file-level failover into torrent-like chunk sourcing.
   - Do after Phase 12 so the app has a broad source/signature cache to build availability maps from.

5. **Phase 14: Platform proof and native UX**
   - Do before public claims or release artifacts.
   - The matrix must move from "pending" to real pass/fail notes.

6. **Phase 18: Release engineering and distribution**
   - Required before calling B-LAN release-ready.
   - CI, packaging, migration fixtures, and support bundles reduce regression risk.

7. **Phase 13 and Phase 15**
   - Do before broad LAN-party usage.
   - Upload visibility, throttling, secure storage, and suspicious-peer handling improve trust and operability.

8. **Phase 16 and Phase 17**
   - Optional product-scope decisions.
   - Headless remote control and chat are part of original D-LAN's broader feature set, but not required for a file-transfer MVP.

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

- `openAppDatabase()` in `database_open.dart` uses `driftDatabase(name: dbPath)`.
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
   - Keep `openAppDatabase()` default unchanged.
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

## Phase 11: Persistent Download Queue And Controls

### Goals

- Turn the current synchronous download call into a real persisted queue.
- Let users pause, resume, cancel, retry, remove, reorder, and clear completed downloads.
- Make folder downloads visible as one grouped task instead of many unrelated file rows.

### Current State

- `AppService.queueDownload()` still awaits `TransferClient.downloadEntry()` / `downloadFolder()` until completion.
- `downloads` and `download_chunks` persist enough state to resume individual files, but no worker owns the queue.
- `cancelActiveDownload()` is in-memory and only affects the current `TransferClient`.
- Downloads UI displays rows but has no controls beyond retry instructions.
- Folder downloads create one row per file; no group record connects them.

### Implementation

1. Schema v7:
   - Add `download_groups`: `id`, `label`, `root_path`, `target_path`, `state`, `total_files`, `completed_files`, `total_bytes`, `downloaded_bytes`, `created_at`.
   - Add nullable `groupId`, `priority`, `paused`, `completedAt`, and `updatedAt` to `downloads`.
   - Add a uniqueness constraint for `download_chunks(download_id, chunk_index)` if Drift migration is practical; otherwise keep helper enforcement and document it.

2. Queue service:
   - Add `lib/core/transfers/download_queue.dart`.
   - Own one or more `TransferClient` workers.
   - On app startup, recover `downloading` rows to `queued` or `paused` depending on prior explicit state.
   - Process rows by `priority`, `createdAt`, and group ordering.
   - Keep active download cancellation per row, not global client-only state.

3. App service:
   - Change `queueDownload()` to enqueue and return a task/group ID quickly.
   - Start queue worker during `initialize()`.
   - Stop workers during `dispose()` without deleting partial files.
   - Foreground notifications subscribe to queue progress instead of awaiting one method.

4. UI:
   - Downloads page actions: pause/resume, cancel, retry, remove, clear complete.
   - Add active/completed/error filters.
   - Show group progress for folder downloads: files completed, bytes, current file.
   - Add details view: chunks, source peers, error message, target path, retry count.

5. Failure semantics:
   - Cancel removes worker activity and sets `cancelled`; optionally delete partial after confirmation.
   - Pause stops workers and leaves partial + verified chunks intact.
   - Retry resets `error` chunks to `pending` and requeues the row.
   - Removing unfinished downloads deletes partial files only after confirmation.

### Tests

- Enqueue returns before transfer completes.
- App restart recovers queued/error/downloading rows consistently.
- Pause leaves partial file and verified chunks; resume completes.
- Cancel marks `cancelled` and stops network work.
- Retry reuses verified chunks and clears stale error messages.
- Folder group progress aggregates file rows.
- Queue ordering and clear-completed behavior.

### Acceptance

- Downloads can continue/recover without blocking the UI call path.
- User can manage downloads from Downloads page without going back to Browse.
- Killing and restarting the app leaves resumable tasks in a sensible state.

## Phase 11.5: In-Flight Chunk Progress

### Goals

- Show byte progress while an individual chunk is still downloading.
- Keep verified/resumable progress separate from transient in-flight progress.
- Make active downloads feel responsive for large chunks or slow peers.

### Current State

- `TransferClient._fetchChunkBytes()` uses `http.Client.get()`, which buffers the whole response before the client sees bytes.
- `downloads.downloadedBytes` only updates after a chunk is fully fetched, hash-verified, and marked `verified`.
- The Downloads page and foreground notification can appear stalled between chunk completions.
- Parallel chunk downloads make naive "current chunk bytes" reporting inaccurate unless in-flight bytes are aggregated per download.

### Implementation

1. Schema v8:
   - Add transient `inFlightBytes` to `downloads`, default `0`.
   - Keep `downloadedBytes` as verified bytes only.
   - Reset `inFlightBytes` to `0` on startup recovery, pause, cancel, error, complete, and retry.

2. Streaming client:
   - Replace chunk body fetches in `TransferClient` with `http.Client.send()` and stream reads.
   - Count bytes as response chunks arrive for both `/chunks?hash=` and `Range` fallback.
   - Preserve current semantics: write to partial file and mark verified only after full chunk bytes pass length and hash checks.
   - Throw `DownloadCancelled` promptly during stream reads when the row is paused/cancelled.

3. Progress aggregation:
   - Track in-flight bytes per active chunk worker in memory, keyed by `downloadId` and `chunkIndex`.
   - Persist the aggregate to `downloads.inFlightBytes` on a throttle, roughly every 100-250 ms.
   - Report UI/notification progress as `downloadedBytes + inFlightBytes` out of `totalBytes`.
   - Clamp display progress to `totalBytes`; never let in-flight bytes imply completion.

4. Queue integration:
   - `DownloadQueue` foreground notification should use aggregate progress, not only verified bytes.
   - Pause/cancel should clear in-flight bytes before or immediately after stopping workers.
   - Retry should reuse verified chunks but start with zero in-flight bytes.

5. UI:
   - Downloads page progress indicator should advance during active chunk streaming.
   - Details text can show `Verified X / Y` and `Receiving Z` if useful.
   - Folder group progress should include child `inFlightBytes` in displayed bytes while preserving completed-file counts.

### Tests

- Slow streaming chunk increments displayed/persisted progress before verification.
- `downloadedBytes` remains verified-only while `inFlightBytes` carries temporary bytes.
- Pause/cancel clears `inFlightBytes` and leaves verified chunks resumable.
- Retry starts with `inFlightBytes == 0` and keeps verified chunk progress.
- Parallel chunk workers aggregate in-flight bytes without double-counting.
- Foreground notification callback receives intermediate progress.

### Acceptance

- Large/slow chunks show smooth progress before chunk verification completes.
- Restart/recovery never treats in-flight bytes as durable downloaded data.
- Existing resume, hash verification, multi-source, pause/cancel/retry tests still pass.

## Phase 12: Global Search And Remote Index Discovery

### Goals

- Restore a core D-LAN feature: fast search across LAN peers.
- Let multi-source find identical files even when paths differ.
- Avoid fetching every remote directory tree on every search.

### Current State

- Browse is per peer/share/path.
- Remote manifest cache stores raw file manifests only after a file has already been touched.
- No share-wide manifest endpoint, no remote search endpoint, and no local word index.
- Original D-LAN had word-index/search components; Flutter rewrite does not.

### Implementation

1. Protocol:
   - Add `GET /search?q=&type=&minSize=&maxSize=&pageSize=&pageToken=`.
   - Add `SearchResultDto`: peer/share/file entry fields, size, mtime, hash readiness, optional file-level content key.
   - Add `GET /manifest/shares/<shareId>?pageSize=&pageToken=` for bulk index sync if search needs local cache.
   - Keep pagination stable; never return local absolute paths.

2. Local indexing:
   - Add normalized filename/path token index.
   - Start with filename and relative path only; content indexing is out of scope unless explicitly chosen.
   - Handle incremental updates from `ShareScanner.scanShareIncremental()`.
   - Index directory names so folder search works.

3. Remote cache:
   - Add normalized tables if needed: `remote_files`, `remote_chunks`, `remote_file_sources`.
   - Store content signatures: size + ordered chunk hashes for ready files.
   - Expire stale entries by peer last seen and share scan timestamp.

4. Search service:
   - Query online peers in parallel with bounded concurrency.
   - Merge results by content signature when hashes match.
   - Surface stale/offline cache results separately only if UX is clear.
   - Prefer trusted peers in result ordering.

5. UI:
   - Add Search destination/page.
   - Query box, filters, result grouping by file/content.
   - Show sources count, size, hash-ready state, peer trust state.
   - "Download selected" enqueues from best source and preloads matching source cache for multi-source.

### Tests

- Tokenizer/index updates for add/change/delete/rename.
- Search endpoint pagination and filtering.
- Multi-peer result merge by matching hash sequence.
- Stale peer/cache handling.
- Download from search result completes and records source peers.

### Acceptance

- User can search visible LAN content without manually browsing each peer.
- Identical files on different peers are grouped and usable by multi-source downloads.
- Search stays responsive on large shares.

**Status: complete (2026-07-02).** Schema v9 `entry_search_tokens` + `remote_files`; `GET /search` and `GET /manifest/shares/<id>`; local token index maintained by scanner; `SearchService` parallel peer queries with signature merge; Search nav page; `matchingPeers` cross-path via signature; 96 tests pass.

## Phase 12.5: Chunk-Level Swarm Scheduling

### Goals

- Make downloads torrent-like at the chunk level, not only file-manifest failover.
- Pull different chunks from any peer that can prove it has the required chunk hash.
- Improve speed and resilience when peers have partial overlap, different paths, or intermittent availability.

### Current State

- Phase 8 multi-source downloads require cached manifests with the same `shareId`, same relative path, same size, and identical full chunk sequence.
- Phase 12 will broaden source discovery by file/content signature, but it still groups whole-file sources.
- `ChunkSourceScheduler` ranks peers, but it does not maintain a global availability map per chunk.
- There is no rarest-first strategy, no dynamic peer re-announcement, and no independent swarm state for a download.

### Implementation

1. Swarm data model:
   - Add `remote_chunk_sources`: `chunk_hash`, `peer_id`, `entry_id`, `share_id`, `offset`, `length`, `last_seen`, `last_success_at`, `failure_count`, `avg_latency_ms`, `avg_bytes_per_second`.
   - Add `download_chunk_sources` or in-memory equivalent for attempted peers per download chunk.
   - Keep `download_chunks.sourcePeerId` as the final successful source.
   - Persist enough availability to resume swarm scheduling after restart, but expire stale source rows aggressively.
   - Suggested Drift tables:
     - `RemoteFiles`: `id`, `peerId`, `shareId`, `entryId`, `relativePath`, `size`, `mtimeMs`, `signature`, `manifestJson`, `lastSeen`.
     - `RemoteChunkSources`: `id`, `hash`, `peerId`, `remoteFileId`, `chunkIndex`, `offset`, `length`, `lastSeen`, `lastSuccessAt`, `failureCount`, `avgLatencyMs`, `avgBytesPerSecond`.
     - `DownloadChunkAttempts`: `id`, `downloadChunkId`, `peerId`, `state`, `errorMessage`, `startedAt`, `finishedAt`.
   - Suggested indexes:
     - `remote_chunk_sources(hash)`.
     - `remote_chunk_sources(peer_id, hash)`.
     - `remote_files(signature)`.
     - `download_chunk_attempts(download_chunk_id, peer_id)`.
   - Signature format:
     - `sha256:size:<totalBytes>:chunks:<hash1>,<hash2>,...` initially.
     - Store full ordered hash list in `manifestJson`; signature is only a compact grouping key.

2. Availability discovery:
   - Populate chunk-source rows from:
     - Search results and share manifests from Phase 12.
     - Direct file manifest fetches during browse/download.
     - Successful chunk responses.
   - Add optional endpoint `GET /chunks/availability?hash=<hash>` or batched `POST /chunks/availability` if probing by hash is cheaper than manifest sync.
   - Avoid probing every peer for every chunk; use cached signatures first, then bounded background probes.
   - Prefer batched endpoint if implemented:
     - Request: `POST /chunks/availability` with `{ "hashes": ["..."], "maxResults": 512 }`.
     - Response: `{ "available": [{ "hash": "...", "entryId": "...", "offset": 0, "length": 262144 }] }`.
   - Privacy rule:
     - Response proves availability for requested hashes only.
     - It does not enumerate all files or expose paths unless the peer already got those via search/manifest.
   - Discovery flow:
     - When a download starts, load manifest hashes.
     - Query local `RemoteChunkSources` for all hashes.
     - If a chunk has no candidates, enqueue a low-priority availability probe against online trusted/known peers.
     - Merge probe results into `RemoteChunkSources`.
     - Start transfer without waiting for all probes if enough candidates exist.

3. Scheduler:
   - Build per-download availability map: `chunkIndex -> candidate peers`.
   - Start with rarest-first among pending chunks to reduce risk of losing scarce chunks.
   - Assign chunks across peers using:
     - trusted and online peers first,
     - fewer failures,
     - higher measured throughput,
     - lower current in-flight count,
     - chunk rarity.
   - Keep per-peer concurrency caps so one fast peer does not starve all others unless it is clearly best.
   - Re-rank on success/failure and periodically during long downloads.
   - Suggested service:
     - `SwarmAvailabilityStore`: DB reads/writes for remote file/chunk source cache.
     - `SwarmScheduler`: pure ranking logic, unit-testable.
     - `SwarmDownloadWorker`: integrates scheduler with `TransferClient` chunk fetching and DB state.
   - Scheduler input:
     - pending `DownloadChunk` rows.
     - candidate `RemoteChunkSource` rows keyed by hash.
     - peer state: trusted, online, in-flight count, failures, measured speed.
     - user settings: max global chunks, max chunks per peer.
   - Scheduler output:
     - assignments: `(downloadChunkId, peerId, remoteEntryId?, hash, offset, length)`.
   - Selection algorithm sketch:
     - Filter candidates to online peers with valid session or reachable manual URL.
     - For each pending chunk, compute rarity = candidate count.
     - Sort chunks by rarity ascending, then chunk index ascending.
     - For each chunk, score candidates:
       - trusted bonus,
       - online/manual reachable bonus,
       - lower in-flight bonus,
       - lower failure count bonus,
       - higher throughput bonus,
       - recent success bonus.
     - Pick best candidate below per-peer cap.
     - If no candidate is available, leave chunk pending with `waiting_for_source`.
   - Do not mark a chunk verified until:
     - bytes length matches manifest length,
     - hash matches manifest hash,
     - bytes flushed to partial file,
     - DB update succeeds.

4. Concrete transfer changes:
   - Split `TransferClient.downloadEntry()` into:
     - manifest/target setup,
     - partial-file reconciliation,
     - chunk fetch primitive,
     - finalization.
   - Add chunk fetch primitive that accepts explicit source:
     - `fetchChunkFromPeer({Peer peer, ChunkDto chunk, String? token, bool chunkRouteOnly})`.
   - Keep `/files/<id>` range fallback for single-source legacy downloads only.
   - For swarm mode, prefer `/chunks?hash=` because remote `entryId` can differ by peer/path.
   - Use range fallback in swarm mode only when the candidate source row includes remote `entryId`, `offset`, and `length`.
   - Update `ChunkSourceScheduler` or replace it with `SwarmScheduler`; do not keep both doing overlapping ranking long-term.

5. Failure behavior:
   - On timeout/network error, penalize peer for that chunk and try another candidate.
   - On hash mismatch, strongly penalize peer and feed Phase 15 suspicious-peer logic.
   - If no candidates remain, keep chunk pending and schedule a bounded rediscovery pass.
   - If all chunks with candidates complete but some remain unavailable, leave download resumable and surface "waiting for sources".
   - Suggested states:
     - `download_chunks.state`: keep `pending`, `writing`, `verified`, `error`.
     - Add `waiting_for_source` only if UI needs to distinguish unavailable from failed.
     - Attempt states: `queued`, `fetching`, `failed`, `verified`, `superseded`.
   - Retry rules:
     - Timeout: +1 failure for peer/hash, retry another peer immediately.
     - HTTP 404 for `/chunks?hash=`: mark peer no longer available for that hash; do not penalize heavily.
     - Hash mismatch: +3 failure, mark suspicious candidate, do not retry same peer/hash until manual/session refresh.
     - Auth failure: clear session and re-auth once; if still failing, mark peer unavailable.
     - Offline peer: mark peer offline and requeue its assigned chunks.

6. Protocol and privacy:
   - Use chunk hashes as content identifiers, not absolute paths.
   - Do not expose a peer's full share index unless the user explicitly shares it via search/manifest endpoints.
   - Consider rate-limiting availability probes to avoid LAN spam.
   - Availability endpoint should require the same auth as downloads.
   - Browser token clients may use it, but rate limits should be stricter.
   - Add maximum hashes per request (for example 512) and maximum response size.
   - Log availability probes only at debug level; avoid leaking searched content in normal logs.

7. UI:
   - Downloads details show:
     - available sources per chunk,
     - active peer striping,
     - stalled chunks waiting for source,
     - peer failure counts.
   - Search/download UI can show "swarm sources" count separately from whole-file sources.
   - Add copy that B-LAN uses LAN swarm chunks, not BitTorrent protocol or public trackers.
   - Downloads list:
     - Show `Sources 5 · Active 3 · Waiting 0` when swarm metadata exists.
     - If stalled: `Waiting for sources for 4 chunks`.
   - Details view:
     - Summary cards: total chunks, verified, waiting, failed, active peers.
     - Per-peer contribution: chunks verified, bytes, average speed, failures.
     - Per-chunk debug list hidden behind "Advanced".
   - Search results:
     - Show "Swarm-ready" when enough sources cover all chunks.
     - Show "Partial sources" if union covers only some chunks.

8. Rollout order:
   - Add schema/cache and backfill from existing `RemoteEntriesCache`.
   - Add `SwarmAvailabilityStore` and tests without changing downloads.
   - Add batched availability endpoint and tests.
   - Add `SwarmScheduler` pure unit tests.
   - Wire swarm worker behind a feature flag / setting.
   - Enable by default only after parity tests pass.
   - Remove redundant Phase 8 file-level source code paths once swarm path covers same-file failover.

### Core Invariants

- Final file bytes are trusted only after local hash verification, never because a peer claims availability.
- A chunk hash maps to content bytes, not to a path. Paths are only metadata for UI and range fallback.
- A peer can be a source for chunk N even if it does not have the full file.
- Missing sources must not corrupt or delete verified chunks.
- Scheduler decisions are performance hints; correctness remains in hash verification and DB state.

### Suggested File Layout

- `lib/core/transfers/swarm_availability_store.dart`
- `lib/core/transfers/swarm_scheduler.dart`
- `lib/core/transfers/swarm_download_worker.dart`
- `lib/core/protocol/swarm_models.dart` or extend `models.dart` if small.
- `test/swarm_scheduler_test.dart`
- `test/swarm_download_test.dart`
- `test/swarm_availability_test.dart`

### Tests

- Three peers each have disjoint subsets of chunks; one download completes by combining all.
- Rarest-first schedules scarce chunks before common chunks.
- Fast peer receives more chunks but per-peer cap still allows striping.
- Peer disappears mid-download; remaining chunks shift to other peers.
- Hash mismatch excludes/penalizes peer and never finalizes corrupt bytes.
- Restart preserves swarm availability and resumes pending chunks.
- Availability probe is bounded and does not query every peer for every chunk.
- Union coverage calculation:
  - peer A has chunks 0,1;
  - peer B has chunks 1,2;
  - peer C has chunks 3;
  - file is downloadable only when union covers 0,1,2,3.
- Range fallback correctness when source peer has same hash at different offset.
- Auth refresh on swarm candidate peer.
- Stalled download remains `downloading` or `paused` with visible waiting reason, not `error`, when only source availability is missing.

### Acceptance

- A file can complete when no single peer has every chunk, as long as the union of peers has all chunks.
- Long downloads actively stripe chunks across multiple capable peers, not only fail over when a source is missing.
- Missing-source chunks remain resumable and visible instead of failing the entire download prematurely.

## Phase 13: Upload Visibility, Rate Limiting, And Network Health

### Goals

- Make serving files observable and controllable.
- Expose active uploads and network health instead of silent HTTP responses.
- Add bandwidth and concurrency controls needed for LAN-party use.

### Current State

- `TransferServer` serves `/files` and `/chunks` without recording transfer rows.
- `transfers` table exists but is not a complete upload/download telemetry model.
- No Uploads page, transfer rates, client list, throttling, or source health UI.
- Range validation is basic and should reject invalid/out-of-bounds ranges more carefully.

### Implementation

1. Transfer telemetry:
   - Add `active_transfers` or extend `transfers`: `direction`, `peerId`, `remoteAddress`, `entryId`, `chunkHash`, `bytesTotal`, `bytesTransferred`, `startedAt`, `updatedAt`, `rateBytesPerSecond`, `state`, `errorMessage`.
   - Track both `/chunks?hash=` and `/files/<id>` requests.
   - Cleanup abandoned rows on disconnect/error.

2. Upload manager:
   - Wrap response streams so bytes sent can be counted.
   - Associate session tokens with peer IDs where possible.
   - Record anonymous/browser-token transfers separately.
   - Add per-peer recent failure and throughput stats used by the multi-source scheduler.

3. Rate and concurrency controls:
   - Settings: max download chunks, max upload chunks, optional global bandwidth caps.
   - Enforce upload concurrency in `TransferServer`.
   - Add backpressure/delay wrapper for bandwidth limit.
   - Keep defaults simple and high enough for LAN use.

4. Network health UI:
   - Add Uploads page or combined Transfers page.
   - Show active uploads/downloads, peer, file, rate, ETA, errors.
   - Settings/network panel: port, LAN URL, active sessions, recent failures.

5. Protocol hardening:
   - Reject range start beyond file length.
   - Reject end < start.
   - Clamp suffix/open-ended ranges correctly or return `416`.
   - Add content-range for invalid ranges when helpful.

### Tests

- Upload row appears and completes for `/chunks` and `/files`.
- Range invalid/out-of-bounds returns correct status.
- Slow client/disconnect cleans up transfer row.
- Rate limiter delays large response.
- Concurrency cap queues or rejects excess upload work predictably.

### Acceptance

- User can see who is downloading from them and at what speed.
- Network failures are diagnosable without reading logs.
- Upload/download load can be limited from Settings.

## Phase 14: Platform Proof And Native UX

### Goals

- Convert documented platform claims into recorded evidence.
- Improve platform-specific onboarding and failure handling.
- Make B-LAN feel native enough for daily use on target platforms.

### Current State

- `docs/platform-test-matrix.md` has nearly all real-device rows pending.
- Platform capabilities exist, but some are static claims rather than measured runtime status.
- Windows advertise is unsupported; Android SAF and notifications need device validation.
- No tray/background integration or startup option exists.

### Implementation

1. Manual matrix execution:
   - Run Linux-to-Linux, Linux-to-Android, Windows browse/manual connect, Flutter web-to-Linux, Android background scan/download.
   - Record date, OS versions, app commit, pass/fail, and notes in `docs/platform-test-matrix.md`.
   - Split "documented limitation" from "failed unexpectedly".

2. Linux:
   - Detect likely Avahi/Bonjour absence where possible.
   - Show discovery troubleshooting and firewall/port guidance.
   - Add "copy LAN URL" using an actual LAN address, not only loopback.

3. Windows:
   - Decide between: browse-only as supported MVP, custom mDNS advertise, or manual-connect-first UX.
   - If browse-only remains: make inbound manual connect setup obvious.
   - Document firewall prompt behavior.

4. Android:
   - Validate persisted SAF grants after restart.
   - Validate foreground service during long scan/download and notification denied path.
   - Add user-selected download target if app-documents-only is too limiting.
   - Show multicast/AP isolation help when discovery fails.

5. Desktop native UX:
   - Evaluate tray/minimize-to-tray and start-at-login.
   - Keep service lifecycle explicit: closing app should clearly stop sharing unless tray/background mode is enabled.
   - Add "open downloads folder" and "open share folder" actions.

6. Web:
   - Validate browser-token flow and CORS.
   - Add allowed-origin setting only if real web use needs it.
   - Keep "browser client only" copy prominent.

### Tests

- Widget tests for platform-specific help text.
- Mock platform services for notification denied, SAF permission missing, and unsupported advertise.
- CORS allowlist tests if origin setting is added.

### Acceptance

- README platform table reflects measured behavior.
- Matrix has current pass/fail notes, not generic pending checkboxes.
- Users see actionable help when discovery/sharing fails.

## Phase 15: Security Hardening

### Goals

- Protect identity keys and tokens better than generic settings storage.
- Bind sessions and trust more tightly to peer identity.
- Detect suspicious peers without overcomplicating LAN-simple UX.

### Current State

- Ed25519 device identity exists, but key bytes are stored in settings.
- Browser token is stored in settings and is long-lived until rotated.
- Session tokens have expiry in memory/settings but are not strongly bound to fingerprint.
- Hash mismatch only fails downloads; repeated suspicious behavior is not surfaced as peer state.
- TLS is still deferred.

### Implementation

1. Secure storage:
   - Add platform secure storage for device private key and browser token where available.
   - Migrate existing settings values on first startup.
   - Keep desktop fallback explicit and documented if secure storage is unavailable.

2. Peer sessions:
   - Store session peer ID, fingerprint, token, expiry.
   - On fingerprint change, revoke stored sessions for that peer.
   - Add "Re-authenticate peer" and "Revoke peer sessions" actions.

3. Suspicious peer state:
   - Add `PeerIdentityStatus.suspicious` or separate security status.
   - Increment suspicion on repeated chunk hash mismatch from the same peer.
   - Surface warning in Peers and Downloads.
   - Let user clear warning only by trusting again or forgetting the peer.

4. Browser token controls:
   - Optional token expiry.
   - Optional one-time browser token.
   - Active browser sessions list if browser clients become common.

5. TLS experiment:
   - Draft native-only pinned TLS using device identity.
   - Do not enable browser TLS by default unless self-signed UX is solved.
   - Document threat model: friendly LAN vs hostile LAN.

### Tests

- Key migration from settings to secure storage mock.
- Trust survives restart; identity change clears sessions.
- Expired/revoked peer session re-authenticates.
- Repeated hash mismatch marks peer suspicious.
- Browser token expiry and one-time token behavior if enabled.

### Acceptance

- Private identity material is not stored as ordinary app settings when platform support exists.
- Identity changes and suspicious transfer behavior are visible and actionable.
- Security UX remains understandable for non-expert LAN users.

## Phase 16: Remote Control / Headless Mode

### Goals

- Decide whether the D-LAN GUI/core split matters for the Flutter rewrite.
- Enable server/headless use only if it fits B-LAN's product direction.

### Current State

- Original D-LAN can run without GUI and be controlled remotely.
- Flutter B-LAN embeds app service and UI in one app process.
- There is no local admin API, CLI, daemon mode, or remote-management auth.

### Implementation

1. Scope decision:
   - If B-LAN targets only end-user desktop/mobile apps, mark this phase out of scope.
   - If B-LAN should support home-server/NAS/LAN-party host use, implement headless mode.

2. Service boundary:
   - Extract an app-core controller API around shares, peers, downloads, settings, and status.
   - Keep Flutter UI as one client of that controller.
   - Avoid exposing peer/browser token APIs as admin APIs.

3. Local admin API:
   - Bind to loopback by default.
   - Require separate admin token or OS user boundary.
   - Endpoints/commands: status, add/remove share, list peers, enqueue download, pause/resume/cancel queue.

4. CLI:
   - `blan status`, `blan shares`, `blan peers`, `blan downloads`, `blan add-share`, `blan pause/resume`.
   - JSON output option for scripting.

5. Daemon lifecycle:
   - Desktop service/systemd docs if supported.
   - Logs and config file location.
   - Safe shutdown with queue persistence.

### Tests

- Controller unit tests independent of Flutter widgets.
- Local API auth and loopback binding.
- CLI smoke tests with temp DB.
- Daemon start/stop preserves queue state.

### Acceptance

- Either explicitly out of scope with rationale, or a minimal headless/CLI workflow works without launching Flutter UI.

## Phase 17: Chat And LAN Presence

### Goals

- Decide whether to restore D-LAN's global persisted chat.
- If in scope, add simple LAN chat without compromising file-transfer stability.

### Current State

- Original D-LAN has channels, persisted messages, formatting, and emoticons.
- Flutter B-LAN has no chat model, protocol, persistence, or UI.
- Peer discovery already provides presence basics.

### Implementation

1. Scope decision:
   - If B-LAN is file-transfer-only, mark chat out of scope.
   - If "LAN party utility" is the goal, implement basic chat after queue/search/platform proof.

2. Protocol:
   - Add chat message DTO: id, room, sender peer ID, timestamp, body, optional reply/thread metadata.
   - Transport options: HTTP polling first, then WebSocket/SSE if needed.
   - Deduplicate by message ID.

3. Persistence:
   - Add `chat_rooms`, `chat_messages`, `chat_peers`.
   - Retention setting to cap DB size.
   - Store unread state per room.

4. UI:
   - Chat page with room list, messages, unread count.
   - Basic text formatting only for MVP; emoticons later.
   - Peer presence indicators.

5. Moderation/security:
   - Trust-aware display for unknown peers.
   - Block/mute peer locally.
   - Avoid executing/rendering unsafe markup.

### Tests

- Message serialization and deduplication.
- Persist/reload messages.
- Room unread count.
- Mute/block behavior.
- Multi-peer delivery simulation.

### Acceptance

- Chat scope is explicitly decided.
- If implemented, basic room chat works across LAN peers and survives restart.

## Phase 18: Release Engineering And Distribution

### Goals

- Make B-LAN reproducible, distributable, and supportable.
- Avoid claiming release readiness until artifacts and migrations are tested.

### Current State

- Tests and benchmark exist locally.
- No CI, release scripts, packaged artifacts, crash/log export, or migration fixture suite are documented.
- README has run/dev instructions but not install/release instructions.

### Implementation

1. CI:
   - Run `flutter test`, `flutter analyze`, `dart format --set-exit-if-changed`, and `dart run tool/db_benchmark.dart --quick`.
   - Build smoke targets: Linux, Android APK, Web.
   - Cache Flutter/pub dependencies.

2. Migration and fixture tests:
   - Keep file-backed DB fixtures for old schema versions.
   - Test open/migrate to latest.
   - Validate indexes and critical settings after migration.

3. Packaging:
   - Linux: AppImage/deb or documented portable build.
   - Android: debug/release APK signing instructions.
   - Windows/macOS: document manual build first if CI packaging is not ready.
   - Web: static hosting notes and browser-token limitations.

4. Release metadata:
   - Versioning policy.
   - Changelog format.
   - Build provenance: commit hash, Flutter version, platform matrix status.

5. Diagnostics:
   - Add log export/support bundle with DB schema version, platform, settings summary excluding secrets, recent transfer errors.
   - Add crash/error reporting only if privacy model is clear; local export first.

6. Documentation:
   - README install section.
   - Troubleshooting guide: discovery, firewall, Android multicast, SAF, token auth, downloads.
   - Security model document: HTTP LAN, trust, token, no TLS by default.

### Tests

- CI runs full automated suite.
- Migration fixtures pass.
- Release script dry run.
- Support bundle excludes secrets.

### Acceptance

- A fresh user can install or build B-LAN from documented steps.
- Release artifacts are traceable to source and test results.
- Known limitations are documented before distribution.

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
12. MVP validation suite and stress fixtures.
13. Persistent download queue worker + controls.
14. Download groups and detailed download UI.
15. Global search protocol + local filename/path index.
16. Search UI + cross-path multi-source discovery.
17. Chunk-level availability map and source cache.
18. Rarest-first swarm scheduler and peer striping.
19. Upload telemetry + transfer rates.
20. Bandwidth/concurrency settings.
21. Real platform matrix execution + native UX fixes.
22. Secure storage/session hardening.
23. Release CI, migration fixtures, packaging, and support bundle.

### Optional Scope Decisions

These are valuable if B-LAN aims to fully recreate D-LAN, but they should be accepted or rejected explicitly before implementation:

- Headless/remote-control mode:
  - Include if B-LAN should run as a desktop/NAS service without Flutter UI.
  - Exclude if the product target is simple end-user desktop/mobile apps.
- Chat and LAN presence:
  - Include if B-LAN should be a LAN-party utility like original D-LAN.
  - Exclude if the product target is focused file transfer.
- TLS:
  - Native pinned TLS may be useful after secure storage and trust hardening.
  - Browser TLS should stay deferred unless self-signed UX is solved.

### Do Not Do Yet

- Do not add Turso/cloud sync.
- Do not preserve compatibility with legacy C++ D-LAN wire protocol.
- Do not promise full web peer behavior.
- Do not add TLS by default until Phase 15 threat model and UX decisions are complete.
- Do not replace SQLite with libSQL without measured wins on desktop and Android.
