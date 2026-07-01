import 'dart:io';

import 'package:flutter/foundation.dart';

/// Human-readable platform capability summary for settings and docs alignment.
abstract final class PlatformCapabilities {
  static bool get isWeb => kIsWeb;

  static bool get supportsLocalSharing => !kIsWeb;

  static bool get supportsMdnsDiscovery => !kIsWeb;

  static bool get supportsMdnsAdvertising =>
      !kIsWeb && !Platform.isWindows;

  static bool get supportsFilesystemWatcher =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  static bool get supportsSafSharing => !kIsWeb && Platform.isAndroid;

  static String get platformName {
    if (kIsWeb) {
      return 'Web';
    }
    if (Platform.isAndroid) {
      return 'Android';
    }
    if (Platform.isLinux) {
      return 'Linux';
    }
    if (Platform.isMacOS) {
      return 'macOS';
    }
    if (Platform.isWindows) {
      return 'Windows';
    }
    return 'Unknown';
  }

  static List<CapabilityRow> capabilityRows() => [
        CapabilityRow(
          'Share folders',
          supportsLocalSharing,
          note: isWeb ? 'Use a desktop peer' : null,
        ),
        CapabilityRow(
          'LAN discovery',
          supportsMdnsDiscovery,
          note: isWeb ? 'Manual connect only' : null,
        ),
        CapabilityRow(
          'LAN advertise',
          supportsMdnsAdvertising,
          note: Platform.isWindows ? 'Browse peers; add manually' : null,
        ),
        CapabilityRow(
          'Browse remote peers',
          true,
        ),
        CapabilityRow(
          'Verified downloads',
          !isWeb,
          note: isWeb ? 'Browser download only; no resume DB' : null,
        ),
        CapabilityRow(
          'Incremental index watch',
          supportsFilesystemWatcher,
          note: Platform.isAndroid ? 'Manual rescan on SAF shares' : null,
        ),
      ];

  static List<String> limitationNotes() {
    final notes = <String>[];
    if (kIsWeb) {
      notes.add(
        'Web is browse/download client only. Enter a desktop peer host, port, '
        'and browser token from Settings on the sharing machine.',
      );
      return notes;
    }
    if (Platform.isWindows) {
      notes.add(
        'Windows can discover and browse LAN peers but does not advertise '
        'itself yet. Use manual connect on other devices.',
      );
    }
    if (Platform.isLinux) {
      notes.add(
        'Linux discovery uses Bonsoir with Avahi. If no peers appear, ensure '
        'avahi-daemon is running and UDP port 5353 is allowed.',
      );
    }
    if (Platform.isAndroid) {
      notes.add(
        'Android uses SAF for folder shares; large trees may need manual rescan. '
        'Scan/download run in a foreground notification while active.',
      );
    }
    return notes;
  }

  static String firewallGuidance(int port) =>
      'B-LAN serves HTTP on port $port. Allow inbound TCP $port from your LAN '
      'if another device cannot browse this machine.';
}

final class CapabilityRow {
  const CapabilityRow(this.label, this.available, {this.note});

  final String label;
  final bool available;
  final String? note;
}
