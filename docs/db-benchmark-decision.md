# Database Engine Benchmark Decision

Last run: 2026-07-02 (Linux, Drift + bundled SQLite, schema v6)

## Decision

**Keep SQLite** as the production persistence engine. Do not add libSQL/Turso to B-LAN yet.

## How to reproduce

```bash
# Quick smoke (1k entries, ~11k rows)
dart run tool/db_benchmark.dart --quick

# Full plan workloads (10k entries, 100k chunks)
dart run tool/db_benchmark.dart

# File-backed open/close cycle (temp db on disk)
dart run tool/db_benchmark.dart --quick --file
```

Output is JSON on stdout; progress on stderr. Harness lives in `lib/core/persistence/db_benchmark_runner.dart`. Production app opens via `openAppDatabase()` in `database_open.dart`; benchmarks use `AppDatabase.openForBenchmark()` only.

## SQLite baseline (full scale)

| Workload | Duration | Throughput | Notes |
|----------|----------|------------|-------|
| bulk_index_writes | 523 ms | ~210k ops/s | 10k entries + 100k chunks in one transaction batch |
| concurrent_read_write | 32.9 s | ~43 ops/s | 4 readers × 250 `entriesForShare` + 200 `replaceEntryChunks` writers |
| download_chunk_transitions | 8.0 s | ~501 ops/s | 2k chunks pending→writing→verified |
| chunk_lookup_by_hash | 12.0 s total | p50 **2.37 ms**, p95 **2.64 ms** | 5k indexed lookups on `chunks.hash` |
| open_close_reliability | 24 ms | 50 cycles | In-memory open/insert/close |

Chunk hash index (`idx_chunks_hash`, schema v5) keeps lookups in low single-digit milliseconds at 100k chunks.

## libSQL evaluation

| Criterion | Assessment |
|-----------|------------|
| Offline local-only | `libsql_dart` supports `LibsqlClient.local(path)` without sync URL |
| Drift integration | `drift_libsql` 0.1.0 — thin wrapper, low pub adoption |
| Flutter targets | Android, iOS, Linux, macOS, Windows (prebuilt natives since 0.7.0) |
| Turso/sync coupling | Primary docs and examples assume `syncUrl` + `authToken` |
| B-LAN fit | No cloud sync requirement; SQLite already meets latency needs |

**Blockers to switching**

1. No measured win — libSQL not benchmarked in-tree; SQLite p95 chunk lookup ~2.6 ms at 100k rows.
2. Extra native dependency and packaging risk vs current `sqlite3_flutter_libs` path.
3. `drift_libsql` immature for a local-only LAN app; value proposition is Turso replication.

**Revisit when**

- WAL lock contention or p95 regressions show up under real indexing/download load on large shares.
- libSQL local driver gains parity with sqlite3 Flutter packaging and a stable Drift executor without sync boilerplate.

## Production impact

- `AppDatabase.open()` removed from `database.dart`; app uses `openAppDatabase()`.
- `flutter test` unchanged — benchmark is opt-in via `dart run tool/db_benchmark.dart`.
- No libSQL dependency added to `pubspec.yaml`.
