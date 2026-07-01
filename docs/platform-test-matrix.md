# B-LAN Platform Test Matrix

Manual checklist for Phase 6 validation. Run on real devices where possible.

## All platforms

- [ ] App launches and shows Peers, Downloads, Settings (and Shares on native)
- [ ] Manual peer connect with host + port works
- [ ] Browse remote shares and nested folders
- [ ] Download single file; file appears under save location with correct relative path
- [ ] Download folder; nested tree preserved
- [ ] Downloads screen shows state, bytes, chunk count, target path
- [ ] Settings shows nickname, port, browser token copy/rotate
- [ ] README platform claims match observed behavior

## Linux

- [ ] Avahi running: peer advertises and is discovered by another device
- [ ] Avahi stopped: discovery fails gracefully; manual connect still works
- [ ] Edit shared file: remote peer sees updated hash without manual rescan
- [ ] Firewall blocked port: manual connect fails with visible error; Settings firewall note helpful

## macOS

- [ ] Advertise + browse between two Mac instances
- [ ] File watcher updates index after local edit

## Windows

- [ ] Browse discovers Linux/macOS peer
- [ ] Windows instance is **not** auto-discovered; manual connect from peer works
- [ ] UI shows browse-only / manual-connect limitation

## Android

- [ ] Android 10 / 13 / 14+ (as available)
- [ ] Wi-Fi with multicast enabled: discovery works
- [ ] Wi-Fi AP isolation / multicast off: manual connect works
- [ ] SAF share: large nested folder scan
- [ ] SAF: delete/rename file during scan — no crash; rescan recovers
- [ ] SAF URI permission survives app restart
- [ ] Foreground notification during scan/download
- [ ] Notification permission denied: app still functions; notification may be missing
- [ ] Download to app documents/B-LAN directory

## Web

- [ ] Settings web client: connect with host, port, browser token
- [ ] Browse shares and entries
- [ ] Download file via browser (no resume DB)
- [ ] CORS: desktop peer reachable from browser origin

## Desktop UX

- [ ] Settings shows HTTP port and copyable local URL
- [ ] Shares page shows server/advertise status
- [ ] Share enable toggle stops serving disabled share
- [ ] Share remove asks confirmation

## Regression

- [ ] `flutter test` passes
- [ ] `flutter analyze` clean
- [ ] No `bonsoir_linux_dbus` in README; Bonsoir 7 used without `configureBonsoirPlatform()`
