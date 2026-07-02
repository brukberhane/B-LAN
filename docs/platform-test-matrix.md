# B-LAN Platform Test Matrix

Manual checklist for release validation. Pair with automated `flutter test` (see README).

**Legend:** `auto` = covered by automated tests · `manual` = run on device before release

Last automated run: 2026-07-02 — `flutter test` 124 tests pass on Linux dev host.

## All platforms

| Check | Type | Status |
|-------|------|--------|
| App launches; Peers, Search, Downloads, Uploads, Settings (+ Shares native) | auto + manual | auto pass (widget smoke); manual pending |
| Manual peer connect host + port | manual | pending |
| Browse remote shares and nested folders | manual | pending |
| Download file; correct relative path under save dir | auto + manual | auto pass; manual pending |
| Download folder; nested tree preserved | auto + manual | auto pass; manual pending |
| Downloads shows state, bytes, chunks, sources, target | auto + manual | auto pass; manual pending |
| Settings nickname, port, fingerprint, token copy/rotate/revoke | auto + manual | auto pass; manual pending |
| Peer trust / identity-changed UX | auto + manual | auto pass; manual pending |
| README claims match device | manual | pending |

## Linux

| Check | Type | Status |
|-------|------|--------|
| Avahi on: advertise + discover | manual | pending |
| Avahi off: graceful failure; manual connect works | manual | pending |
| Avahi status surfaced in Settings network health | auto | pass (2026-07-02) |
| Copy LAN URL uses private IPv4 | auto | pass (2026-07-02) |
| File watcher updates remote hash without rescan | manual | pending |
| Firewall blocked port: visible error | manual | pending |

## macOS

| Check | Type | Status |
|-------|------|--------|
| Advertise + browse between two Macs | manual | pending |
| Watcher updates index after local edit | manual | pending |

## Windows

| Check | Type | Status |
|-------|------|--------|
| Browse discovers Linux/macOS peer | manual | pending |
| Windows not auto-discovered; manual connect in | manual | pending |
| Browse-only limitation shown in UI | auto + manual | auto pass (2026-07-02) |

## Android

| Check | Type | Status |
|-------|------|--------|
| Android 10 / 13 / 14+ | manual | pending |
| Multicast on: discovery | manual | pending |
| AP isolation help shown in Settings | auto | pass (2026-07-02) |
| SAF large nested folder scan | manual | pending |
| SAF delete/rename during scan — no crash | manual | pending |
| SAF URI survives restart | manual | pending |
| Foreground notification scan/download | manual | pending |
| Notification denied: app still works | auto + manual | auto mock pass; device pending |
| Download to app documents/B-LAN or user-picked folder | auto + manual | picker added; device pending |

## Web

| Check | Type | Status |
|-------|------|--------|
| Settings web client connect | manual | pending |
| Browse shares and entries | manual | pending |
| Download file in browser | manual | pending |
| CORS from desktop peer | auto + manual | auto pass (`transfer_server_test`); manual pending |

## Desktop UX

| Check | Type | Status |
|-------|------|--------|
| Settings HTTP port + copy localhost/LAN URL | auto + manual | auto pass (2026-07-02) |
| Open downloads folder action | auto | pass (2026-07-02) |
| Open share folder action (filesystem) | auto | pass (2026-07-02) |
| App close stops sharing (documented in Settings) | auto | pass (2026-07-02) |
| Shares server/advertise status | manual | pending |
| Disable share stops serving | manual | pending |
| Remove share confirmation | auto + manual | auto pass; manual pending |
| Tray / start-at-login | — | deferred (not in MVP) |

## Stress (manual / large hardware)

| Fixture | Automated scale | Manual target |
|---------|-----------------|---------------|
| Many small files | 200 files (`stress_indexing_test`) | 50k tiny files |
| Huge multi-chunk file | ~128 KiB + 64 KiB chunks | File larger than RAM |
| Rename storm | 20 files incremental | Heavy rename churn |
| Same-size mtime change | auto test | Same-size content swap |
| Interrupted source peer | `multi_source_download_test` | Kill peer mid-download |
| Slow network | — | Throttle or delayed server |

## Regression

| Check | Type | Status |
|-------|------|--------|
| `flutter test` passes | auto | pass (2026-07-02, Linux, 124 tests) |
| `flutter analyze` clean | auto | run in CI |
| `dart run tool/db_benchmark.dart --quick` | auto | optional smoke |
| Bonsoir 7, no `bonsoir_linux_dbus`, no `configureBonsoirPlatform()` | manual | verified in code |
