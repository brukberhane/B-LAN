# B-LAN Platform Test Matrix

Manual checklist for release validation. Pair with automated `flutter test` (see README).

**Legend:** `auto` = covered by automated tests · `manual` = run on device before release

## All platforms

| Check | Type | Status |
|-------|------|--------|
| App launches; Peers, Downloads, Settings (+ Shares native) | auto + manual | manual pending |
| Manual peer connect host + port | manual | pending |
| Browse remote shares and nested folders | manual | pending |
| Download file; correct relative path under save dir | auto + manual | manual pending |
| Download folder; nested tree preserved | auto + manual | manual pending |
| Downloads shows state, bytes, chunks, sources, target | auto + manual | manual pending |
| Settings nickname, port, fingerprint, token copy/rotate/revoke | auto + manual | manual pending |
| Peer trust / identity-changed UX | auto + manual | manual pending |
| README claims match device | manual | pending |

## Linux

| Check | Type | Status |
|-------|------|--------|
| Avahi on: advertise + discover | manual | pending |
| Avahi off: graceful failure; manual connect works | manual | pending |
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
| Browse-only limitation shown in UI | auto + manual | manual pending |

## Android

| Check | Type | Status |
|-------|------|--------|
| Android 10 / 13 / 14+ | manual | pending |
| Multicast on: discovery | manual | pending |
| AP isolation: manual connect | manual | pending |
| SAF large nested folder scan | manual | pending |
| SAF delete/rename during scan — no crash | manual | pending |
| SAF URI survives restart | manual | pending |
| Foreground notification scan/download | manual | pending |
| Notification denied: app still works | manual | pending |
| Download to app documents/B-LAN | manual | pending |

## Web

| Check | Type | Status |
|-------|------|--------|
| Settings web client connect | manual | pending |
| Browse shares and entries | manual | pending |
| Download file in browser | manual | pending |
| CORS from desktop peer | auto + manual | manual pending |

## Desktop UX

| Check | Type | Status |
|-------|------|--------|
| Settings HTTP port + copy local URL | auto + manual | manual pending |
| Shares server/advertise status | manual | pending |
| Disable share stops serving | manual | pending |
| Remove share confirmation | manual | pending |

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
| `flutter test` passes | auto | run in CI |
| `flutter analyze` clean | auto | run in CI |
| `dart run tool/db_benchmark.dart --quick` | auto | optional smoke |
| Bonsoir 7, no `bonsoir_linux_dbus`, no `configureBonsoirPlatform()` | manual | verified in code |
