# B-LAN

```text
 ____       _        _    _   _
| __ )     | |      / \  | \ | |
|  _ \     | |     / _ \ |  \| |
| |_) |    | |___ / ___ \| |\  |
|____/     |_____/_/   \_\_| \_|
```

## Summary

B-LAN shares folders with other devices you trust. On a normal LAN it finds peers with mDNS, browses their files, and downloads with verified chunks over pinned HTTPS. The next layer lets phones that are near each other see one another over Bluetooth, accept once, and either join a Wi-Fi or start a private hotspot when they are not already on the same network.

People running the app on Linux, macOS, Windows, or Android. iOS code and tests ship with the nearby work and stay mocked until a Mac can run them. Done means a nearby device can be opened on the existing transfer stack, and `make verify` stays green.

## Table of Contents

- [The problem](#-the-problem)
- [The fix](#-the-fix)
- [Status](#-status)
- [Repo layout](#-repo-layout)
- [Dependencies and docs](#-dependencies--docs)
- [Building](#-building)
- [Model recommendations](#model-recommendations)
- [Security](#-security)
- [License](#-license)

---

## ❗ The problem

| What you try | What happens |
| ------------ | ------------ |
| Two phones on different Wi-Fi, or on none | mDNS never lists them. Manual connect needs an address they do not have. |
| Same LAN, discovery works | Pinned HTTPS on port 59488 already covers browse and download. Nearby must not replace that. |
| "Just use Nearby Share's library" | That stack takes over Wi-Fi and does not speak B-LAN's chunk protocol. |

## 🛠️ The fix

Today: advertise `_blan._tcp`, handshake `/hello` and `/session`, transfer on pinned HTTPS.

Next, from the settled nearby design:

1. BLE list on the Peers screen, with a badge for same LAN, other LAN, or BLE only.
2. One accept dialog and a 6-digit code for a new device. Trust sticks to the Ed25519 fingerprint.
3. If they are not on one reachable LAN, share a WPA2/WPA3-Personal network or start a local-only hotspot. Android tries Wi-Fi Direct only when the hotspot fails, then the next device.
4. File bytes stay on the existing client, pointed at the new address.

```text
BLE advert → accept on Bluetooth → LAN or hotspot/Wi-Fi Direct → HTTPS :59488
```

## 📊 Status

| Area | State |
| ---- | ----- |
| Agent rules (`.cursor/rules/`) | Retargeted to this app |
| Phase index (`planning/phases/`) | See [INDEX](planning/phases/INDEX.md) |
| LAN share, discovery, transfers | In the tree |
| Nearby proximity | Planned. Not implemented. |
| Verify | `make verify` — analyze, test, Android debug apk |

Host toolchain at bootstrap: Flutter 3.47.2, Dart 3.13.2, stable channel. A newer Flutter stable was advertised. The shared SDK was left as-is.

## 📂 Repo layout

| Path | For |
| ---- | --- |
| [`README.md`](README.md) | Humans |
| [`.cursor/rules/`](.cursor/rules/) | Agent conventions |
| [`.cursor/skills/`](.cursor/skills/) | Plan / execute / complete |
| [`planning/phases/`](planning/phases/) | Task sequence |
| [`lib/`](lib/) | Dart app (`lib/core/proximity/` = session policy, 31-byte advert, sealed control frames) |
| [`android/`](android/) | Android runner and foreground service |

## 📚 Dependencies & docs

| Dependency | Role | Docs | Agent rules |
| ---------- | ---- | ---- | ----------- |
| Flutter 3.47 / Dart 3.13 | UI, runners, platform channels | [docs.flutter.dev](https://docs.flutter.dev/) | [flutter.mdc](.cursor/rules/flutter.mdc) |
| Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 | Android apk build (Flutter 3.47 minimums) | [gradle.org](https://gradle.org/) | [flutter.mdc](.cursor/rules/flutter.mdc) |
| Drift | Local database | [drift.simonbinder.eu](https://drift.simonbinder.eu/) | [drift.mdc](.cursor/rules/drift.mdc) |
| Bonsoir | mDNS advertise and browse | [pub.dev/bonsoir](https://pub.dev/packages/bonsoir) | [discovery.mdc](.cursor/rules/discovery.mdc) |
| cryptography + flutter_secure_storage | Identity, pins, secrets | [pub.dev/cryptography](https://pub.dev/packages/cryptography) | [security.mdc](.cursor/rules/security.mdc) |
| Android BLE / Bluetooth | Nearby presence and control channel | [BLE overview](https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview) | [proximity.mdc](.cursor/rules/proximity.mdc) |
| Android Wi-Fi | Local-only hotspot, Wi-Fi Direct, join | [Local-only hotspot](https://developer.android.com/develop/connectivity/wifi/localonlyhotspot) | [android-wifi.mdc](.cursor/rules/android-wifi.mdc) |
| Shizuku / Shevery | Privileged read of a personal Wi-Fi passphrase (`dev.rikka.shizuku:api` and `:provider` 13.1.5) | [RikkaApps/Shizuku](https://github.com/RikkaApps/Shizuku) | [shizuku.mdc](.cursor/rules/shizuku.mdc) |
| dbus 0.7.15 | Linux BlueZ on the system bus (BLE advert, scan, GATT). NetworkManager itself is `nmcli`, no sudo | [pub.dev/dbus](https://pub.dev/packages/dbus) | [proximity.mdc](.cursor/rules/proximity.mdc) |

## 🔁 Building with [Turboplan](https://github.com/commoddity/turboplan)

Work proceeds one phase task at a time. Each command tells you which model size to use for that step and for the next one. Sizes are recommendations.

```text
/task-1-plan TXX          model: medium (large if the task is hard)
      ↓
/task-2-execute TXX       model: small (medium or large only if the plan says so)
      ↓
/task-3-complete TXX      model: small (medium if there is a real lesson to write down)
      → push (default) + manual test → next stub branch
```

## Model recommendations

| Step | Size | Why |
| ---- | ---- | --- |
| `/task-1-plan` | medium | The plan has to be detailed enough for a smaller model to implement. Use large when the stub is ambiguous or spans several platforms. |
| `/task-2-execute` | small | Follow the plan. Use medium when the plan says the work is non-trivial. Use large only when the plan says large. |
| `/task-3-complete` | small | Re-verify, commit, push, manual test. Use medium when a real failure should be written into the rules. A brand-new failure mode can be re-run on large. That does not block the close-out. |

See [`planning/phases/INDEX.md`](planning/phases/INDEX.md).

```bash
flutter pub get
dart run build_runner build   # after Drift edits
make verify
make install-hooks             # once; pre-commit runs make quick-verify (analyze+test)
flutter run -d linux
```

### Platforms that already share

| Platform | Share | Discover | Advertise |
| -------- | ----- | --------- | --------- |
| Linux | Yes | Yes | Yes. Bonsoir + Avahi |
| macOS | Yes | Yes | Yes |
| Windows | Yes | Yes | Yes. Bonsoir via WinDNS |
| Android | SAF or filesystem | Yes | Yes. Foreground service while sharing |
| Web | No | No | No. Manual connect with a browser token |

Protocol v1: `GET /hello`, `POST /session`, shares, entries, manifests, chunks, ranged files. Peer transfers are HTTPS with a pinned self-signed cert. The browser API stays on loopback HTTP port 59487.

## 🔒 Security

- Ed25519 device identity. Trust is explicit. Untrusted peers are removed on the next launch.
- Nearby accept trusts those two fingerprints. A 6-digit code is on both screens. Passwords move only after Accept, sealed on Bluetooth.
- WPA2-Personal and WPA3-Personal only. No enterprise Wi-Fi.
- Passphrases go in the platform secure store when it exists. They are not SQLite columns, logs, or BLE payloads.
- Android cannot read the current Wi-Fi password without Shizuku (ADB or root) on Android 11+. `WRITE_SECURE_SETTINGS` does not do it.
- Linux reads the current personal PSK from NetworkManager with no sudo. Polkit may prompt. An iwd-only machine, enterprise network, or missing `nmcli` returns empty.

## 📜 License

No license file is declared in this tree yet.
