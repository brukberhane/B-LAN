# B-LAN

Flutter rewrite of D-LAN: share folders on your LAN, discover peers, browse remote files, and download with verified chunk resume.

## Platforms

| Platform | Share | Discover | Advertise | Notes |
|----------|-------|----------|-----------|-------|
| Linux | Yes | Yes | Yes | Bonsoir 7 + Avahi; allow TCP HTTP port on LAN |
| macOS | Yes | Yes | Yes | Bonsoir advertise + browse |
| Windows | Yes | Yes | No | Browse/manual connect; advertise not supported yet |
| Android | SAF/filesystem | Yes | Yes | Foreground service for scan/download; SAF needs manual rescan |
| Web | No | No | No | Manual connect with browser token only |

Desktop: Settings shows network health checks, copy LAN URL, open downloads/share folders. Tray/background mode not implemented — closing the app stops sharing.

**Security:** Ed25519 device identity; peer trust and identity-changed workflow; sessions bound to peer fingerprint; suspicious-peer warnings after hash mismatches; secrets in platform secure storage when available (settings fallback on desktop/Linux without keyring). Browser token optional expiry in Settings. TLS not enabled — intended for trusted LANs.

See [docs/platform-test-matrix.md](docs/platform-test-matrix.md) for manual validation checklist.

## Discovery (mDNS)

- Service type: `_blan._tcp`
- **Android / macOS / Linux**: Bonsoir `^7.1.4` advertise + browse (no `bonsoir_linux_dbus`, no `configureBonsoirPlatform()`)
- **Linux**: requires Avahi (`avahi-daemon`) for reliable discovery
- **Windows**: browse-only via `multicast_dns`; use manual peer connect to reach this machine
- **Web**: disabled; enter host, port, and browser token in Settings
- TXT records: `peerId`, `pv`, `nick`
- On resolve: HTTP `/hello` + `/session` handshake, upsert peer by real `peerId`

## Android

- **SAF folder sharing**: folder-copy icon on Shares screen (Storage Access Framework tree URI).
- **Foreground service**: scan/hash/download show persistent notification while running.
- **Multicast lock**: held while app core is active for mDNS browse.
- Permissions: notifications, multicast, foreground `dataSync`, cleartext HTTP for LAN.

## Run

```bash
cd B-LAN
flutter pub get
dart run build_runner build
flutter run -d linux
```

## Architecture

- `lib/core/persistence/` — Drift/SQLite local index and queue
- `lib/core/indexing/` — folder scan, incremental watch (desktop), SHA-256 chunk hashing
- `lib/core/transfers/` — embedded HTTP server + verified download client
- `lib/core/discovery/` — mDNS browse/advertise (Windows browse-only)
- `lib/features/` — shares, peers, browse, downloads, settings UI

## Protocol (v1)

- `GET /hello` — peer metadata
- `POST /session` — native client session token
- `GET /shares`, `GET /entries`, `GET /manifest/files/<id>`, `GET /chunks?hash=`, `GET /files/<id>` with `Range`
- Web clients use browser token from Settings; native clients use `/session`
- Device Ed25519 identity in `/hello`; peer trust and `identity_changed` workflow
- Multi-source downloads: matching manifests, per-chunk peer failover

## Testing

Automated MVP suite (`flutter test`):

| Area | Tests |
|------|-------|
| Protocol DTOs + defaults | `protocol_test.dart` |
| HTTP server auth, CORS, range, chunks | `transfer_server_test.dart` |
| Verified resume, retry, cancel, multi-source | `transfer_client_test.dart`, `multi_source_download_test.dart` |
| Indexing + incremental + stress fixtures | `share_incremental_test.dart`, `stress_indexing_test.dart` |
| DB schema, indexes, queue states | `database_test.dart` |
| Security trust/sessions | `security_test.dart` |
| UI smoke + feature widgets | `widget_test.dart`, `widget_features_test.dart` |
| Platform health + LAN helpers | `platform_health_test.dart`, `lan_addresses_test.dart`, `platform_services_mock_test.dart` |

Optional DB benchmark: `dart run tool/db_benchmark.dart --quick` — see [docs/db-benchmark-decision.md](docs/db-benchmark-decision.md).

Manual cross-platform matrix: [docs/platform-test-matrix.md](docs/platform-test-matrix.md).

## Dev

```bash
flutter test
flutter analyze
dart run tool/db_benchmark.dart --quick   # optional persistence smoke
```
