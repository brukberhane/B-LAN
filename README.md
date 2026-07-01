# B-LAN

Flutter rewrite of D-LAN: share folders on your LAN, discover peers, browse remote files, and download with resume-friendly HTTP transfers.

## Platforms

- Linux, macOS, Windows: full peer (share, discover, browse, download)
- Android: browse/download MVP; folder sharing still limited
- Web: limited client — manually connect to a desktop peer with browser token

## Discovery (mDNS)

- Service type: `_blan._tcp`
- **Android / macOS / Linux**: Bonsoir advertise + browse (Linux uses `bonsoir_linux_dbus` + Avahi)
- **Windows**: browse-only via `multicast_dns` (advertise not supported yet)
- **Web**: disabled; use manual peer URL
- TXT records: `peerId`, `pv`, `nick`
- On resolve: HTTP `/hello` + `/session` handshake, upsert peer by real `peerId`

## Android

- **SAF folder sharing**: use folder-copy icon on Shares screen (Storage Access Framework tree URI).
- **Foreground service**: scan/hash/download show persistent notification while running.
- **Multicast lock**: held while app core is active for mDNS browse.
- Permissions: notifications, multicast, foreground `dataSync`, cleartext HTTP for LAN.

## Run

```bash
cd /home/brukb/projects/Dart/flutter/B-LAN
flutter pub get
dart run build_runner build
flutter run -d linux
```

## Architecture

- `lib/core/persistence/` — Drift/SQLite local index and queue
- `lib/core/indexing/` — folder scan + SHA-256 chunk hashing
- `lib/core/transfers/` — embedded HTTP server + download client
- `lib/core/discovery/` — mDNS browse (advertising deferred)
- `lib/features/` — shares, peers, browse, downloads, settings UI

## Protocol (v1)

- `GET /hello` — peer metadata
- `POST /session` — native client session token
- `GET /shares`, `GET /entries`, `GET /files/{id}` with `Range`
- Web clients use browser token from Settings; native clients use `/session`

## Dev

```bash
flutter test
flutter analyze
```
