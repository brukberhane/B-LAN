# MVP Phase Index

**Product**: B-LAN  
**Method**: `/task-1-plan` → `/task-2-execute` → `/task-3-complete`  
**Rule**: Only one task `InProgress` unless the human approves more.  
**INDEX Status**: use `✅` when complete (never the word `Done` in this column).

LAN share, mDNS, pinned HTTPS, and trust already exist in `lib/`. This index does not replay that work. T01 locks the verify gate. T02–T14 are nearby proximity.

## Settled nearby decisions

- BLE list on Peers, above mDNS. Badges: Same LAN, Other LAN, BLE only.
- Visible switch defaults on. Foreground advertises and scans. Background sharing service advertises and accepts invites, does not scan.
- Untrusted non-LAN tap: link sheet, then nick + 6-digit code + host plan + link plan. Default host is the other device. Trusted same-LAN opens immediately. Trusted different-LAN shows the sheet without the code. Trusted and neither on Wi-Fi skips the sheet.
- Accept stores mutual trust for the two fingerprints even if Wi-Fi fails. Decline or timeout stores nothing.
- No WPA passphrase (extract failed, or they will not type): fall through to the private network. Sheet cancel and short-code decline abort.
- WPA2-Personal and WPA3-Personal only. No enterprise. Remember stores SSID and security in Drift and the passphrase in the secure store. No secure store means do not write it.
- Linux reads NetworkManager secrets. macOS reads the keychain with a user prompt. Android reads via Shizuku/Shevery using SecureSettingsManager's detector. `WRITE_SECURE_SETTINGS` is not the password path. Ask once; default off.
- Private network: local-only hotspot, then Wi-Fi Direct on that Android device if the hotspot fails, then the next device already in the attempt. Desktops only hotspot. A desktop joiner skips Wi-Fi Direct. All fail: stop.
- Members can invite, host setting default on. Trust is only the admitter and the new phone. Wi-Fi Direct admit is owner-only.
- Control channel: classic Bluetooth, else GATT. Sealed Ed25519. Secrets after Accept. No Nearby Connections.
- File bytes stay on pinned HTTPS at the address from the control channel.
- Idle default 3 minutes after the network is empty. Disband asks once. The visible switch does not keep an empty hotspot up.
- One invite dialog. Others wait. 60s timeout declines. Overlay and full-screen intent, else a heads-up. Desktop raises a window.
- iOS: real platform code and expected tests, mocked until a Mac runs them.
- Implement platforms in the task order below. Test-and-fix stays inside each platform task. Do not upgrade the shared Flutter SDK from a task.

| ID | Title | Status | Depends-on | Next | Layer | Notes |
| -- | ----- | ------ | ---------- | ---- | ----- | ----- |
| T01 | [Verify gate](./T01-verify-gate.md) | ✅ | — | T02 | L0 | Existing app. `make verify` builds an Android debug apk |
| T02 | [Session rules](./T02-proximity-session.md) | Pending | T01 | T03 | L3 | Pure policy |
| T03 | [Sealed control frames](./T03-control-frames.md) | Pending | T02 | T04 | L3 | No radio |
| T04 | [Wi-Fi secrets and settings](./T04-wifi-secrets.md) | Pending | T03 | T05 | L2 | PSK not in SQLite |
| T05 | [Radio ports and fakes](./T05-radio-ports.md) | Pending | T04 | T06 | L4 | Interfaces |
| T06 | [Android radios](./T06-android-radios.md) | Pending | T05 | T07 | L6 | Hotspot, then Wi-Fi Direct |
| T07 | [Android Shizuku](./T07-android-shizuku.md) | Pending | T06 | T08 | L6 | Personal PSK only |
| T08 | [Linux radios](./T08-linux-radios.md) | Pending | T07 | T09 | L6 | NetworkManager |
| T09 | [macOS radios](./T09-macos-radios.md) | Pending | T08 | T10 | L6 | Mocked until a Mac |
| T10 | [Windows radios](./T10-windows-radios.md) | Pending | T09 | T11 | L6 | Best effort |
| T11 | [iOS radios](./T11-ios-radios.md) | Pending | T10 | T12 | L6 | Code + expected tests |
| T12 | [Orchestrator](./T12-proximity-orchestrator.md) | Pending | T11 | T13 | L4 | Existing HTTPS |
| T13 | [Nearby UI](./T13-nearby-ui.md) | Pending | T12 | T14 | L7 | Peers + Settings |
| T14 | [E2E proof](./T14-e2e.md) | Pending | T13 | — | L8 | Fakes here, devices manual |

## Layer legend

| Layer | Meaning |
| ----- | ------- |
| L0 | Verify gate on the existing app |
| L1 | Config / logging |
| L2 | Secrets / identity |
| L3 | Pure core |
| L4 | Integration surface |
| L5 | External processes |
| L6 | Host integration |
| L7 | Operator UX |
| L8 | E2E proof |

## How to work

1. `/task-1-plan T01` — model: **medium** (large if the stub is ambiguous or cross-platform)
2. `/task-2-execute T01` — model: **small** when the plan is tight; **medium** if the plan says so; **large** only if the plan says large
3. `/task-3-complete T01` — model: **small** (medium if dialectic has a real lesson) → push (default; `--no-push` to skip) + Manual test → continues on `T02-proximity-session`
4. Repeat. Each step tells you the size for that step and for the next command.  
