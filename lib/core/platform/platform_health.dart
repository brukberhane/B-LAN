import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../platform/platform_services.dart';
import 'lan_addresses.dart';
import 'platform_capabilities.dart';

enum PlatformHealthLevel { ok, warning, error, info }

class PlatformHealthItem {
  const PlatformHealthItem({
    required this.label,
    required this.level,
    required this.message,
    this.hint,
  });

  final String label;
  final PlatformHealthLevel level;
  final String message;
  final String? hint;
}

class PlatformHealthReport {
  const PlatformHealthReport(this.items);

  final List<PlatformHealthItem> items;
}

typedef AvahiChecker = Future<bool> Function();

Future<bool> checkAvahiDaemon({AvahiChecker? checker}) async {
  if (kIsWeb || !Platform.isLinux) {
    return true;
  }
  final run = checker ?? _defaultAvahiChecker;
  return run();
}

Future<bool> _defaultAvahiChecker() async {
  try {
    final result = await Process.run('systemctl', ['is-active', 'avahi-daemon']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim() == 'active';
    }
  } catch (_) {
    // Fall through to pid-file probe.
  }
  return File('/run/avahi-daemon/pid').existsSync();
}

Future<PlatformHealthReport> buildPlatformHealthReport({
  required bool serverRunning,
  required bool advertising,
  required bool supportsAdvertising,
  required PlatformServices platform,
  required int httpPort,
  AvahiChecker? avahiChecker,
}) async {
  final items = <PlatformHealthItem>[];

  items.add(
    PlatformHealthItem(
      label: 'HTTP server',
      level: serverRunning ? PlatformHealthLevel.ok : PlatformHealthLevel.error,
      message: serverRunning
          ? 'Listening on port $httpPort'
          : 'Not running — peers cannot browse or download',
      hint: serverRunning
          ? null
          : 'Restart the app. Check port conflicts in Settings.',
    ),
  );

  if (kIsWeb) {
    items.add(
      const PlatformHealthItem(
        label: 'Web client mode',
        level: PlatformHealthLevel.info,
        message: 'Browse-only client. Connect manually to a desktop peer.',
        hint: 'Use host, port, and browser token from the sharing machine.',
      ),
    );
    return PlatformHealthReport(items);
  }

  if (supportsAdvertising) {
    items.add(
      PlatformHealthItem(
        label: 'LAN advertise',
        level: advertising ? PlatformHealthLevel.ok : PlatformHealthLevel.warning,
        message: advertising
            ? 'This device is visible on the LAN'
            : 'Not advertising — other devices may not auto-discover you',
        hint: advertising
            ? null
            : 'Ensure HTTP server is running and mDNS is not blocked.',
      ),
    );
  } else {
    items.add(
      PlatformHealthItem(
        label: 'LAN advertise',
        level: PlatformHealthLevel.info,
        message:
            'Not supported on ${PlatformCapabilities.platformName}. Use manual connect.',
        hint: Platform.isWindows
            ? 'On other devices: Peers → Connect manually with this machine\'s LAN IP and port.'
            : null,
      ),
    );
  }

  final lanAddresses = await listLanIpv4Addresses();
  if (lanAddresses.isEmpty) {
    items.add(
      const PlatformHealthItem(
        label: 'LAN address',
        level: PlatformHealthLevel.warning,
        message: 'No private IPv4 address found',
        hint: 'Connect Wi‑Fi/Ethernet. Manual connect may still work on loopback.',
      ),
    );
  } else {
    items.add(
      PlatformHealthItem(
        label: 'LAN address',
        level: PlatformHealthLevel.ok,
        message: lanAddresses.join(', '),
        hint: 'Share this IP with manual-connect clients.',
      ),
    );
  }

  if (Platform.isLinux) {
    final avahi = await checkAvahiDaemon(checker: avahiChecker);
    items.add(
      PlatformHealthItem(
        label: 'Avahi',
        level: avahi ? PlatformHealthLevel.ok : PlatformHealthLevel.warning,
        message: avahi ? 'avahi-daemon is active' : 'avahi-daemon not detected',
        hint: avahi
            ? null
            : 'Install/start avahi-daemon and allow UDP 5353 on the LAN.',
      ),
    );
  }

  if (Platform.isAndroid) {
    final notifications = await platform.notificationsEnabled();
    items.add(
      PlatformHealthItem(
        label: 'Notifications',
        level: notifications
            ? PlatformHealthLevel.ok
            : PlatformHealthLevel.warning,
        message: notifications
            ? 'Foreground scan/download notifications allowed'
            : 'Notifications denied — long scans may be less visible',
        hint: notifications
            ? null
            : 'Grant notification permission in system settings.',
      ),
    );
    items.add(
      const PlatformHealthItem(
        label: 'Multicast / Wi‑Fi',
        level: PlatformHealthLevel.info,
        message: 'Some routers block peer discovery (AP isolation)',
        hint: 'If no peers appear, use manual connect with the host IP.',
      ),
    );
  }

  if (Platform.isMacOS) {
    items.add(
      const PlatformHealthItem(
        label: 'Local network',
        level: PlatformHealthLevel.info,
        message: 'Discovery needs Local Network permission on macOS',
        hint:
            'System Settings → Privacy & Security → Local Network → enable B-LAN. '
            'Manual connect uses peer HTTPS port (Settings → Peer HTTPS port), '
            'not browser HTTP.',
      ),
    );
    items.add(
      const PlatformHealthItem(
        label: 'macOS firewall',
        level: PlatformHealthLevel.info,
        message: 'Inbound HTTPS may be blocked until allowed',
        hint:
            'Allow incoming connections for B-LAN when prompted, or add a rule '
            'for the peer HTTPS port.',
      ),
    );
  }

  if (Platform.isWindows) {
    items.add(
      const PlatformHealthItem(
        label: 'Windows firewall',
        level: PlatformHealthLevel.info,
        message: 'First inbound connection may prompt for firewall access',
        hint: 'Allow B-LAN on private networks when prompted.',
      ),
    );
  }

  return PlatformHealthReport(items);
}
