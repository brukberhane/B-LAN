import 'dart:math';

import '../../core/proximity/proximity_radios.dart';
import '../../core/proximity/proximity_types.dart';
import '../../core/security/remembered_wifi.dart';
import 'linux_command.dart';

class ActiveWifi {
  const ActiveWifi(this.name, this.uuid);
  final String name;
  final String uuid;
}

const hotspotConnectionName = 'blan-hotspot';

/// Splits an `nmcli -t` line on unescaped colons and unescapes `\:` and `\\`.
List<String> splitNmcliFields(String line) {
  final parts = <String>[];
  final current = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '\\' && i + 1 < line.length) {
      final next = line[i + 1];
      if (next == ':' || next == '\\') {
        current.write(next);
        i++;
        continue;
      }
    }
    if (char == ':') {
      parts.add(current.toString());
      current.clear();
      continue;
    }
    current.write(char);
  }
  parts.add(current.toString());
  return parts;
}

List<ActiveWifi> parseActiveWifi(String stdout) {
  final rows = <ActiveWifi>[];
  for (final raw in stdout.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    final parts = splitNmcliFields(line);
    if (parts.length < 4) {
      continue;
    }
    final name = parts[0];
    final type = parts[2];
    if (type != '802-11-wireless' || name == hotspotConnectionName) {
      continue;
    }
    rows.add(ActiveWifi(name, parts[1]));
  }
  return rows;
}

/// `connection show -t` prints one `property:value` line per field.
({String keyMgmt, String psk})? parseNmSecrets(String stdout) {
  String? keyMgmt;
  String? psk;
  for (final raw in stdout.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    final parts = splitNmcliFields(line);
    if (parts.length < 2) {
      continue;
    }
    final name = parts[0];
    final value = parts[1];
    if (name == 'key-mgmt' || name.endsWith('.key-mgmt')) {
      keyMgmt = value;
    } else if (name == 'psk' || name.endsWith('.psk')) {
      psk = value;
    }
  }
  if (keyMgmt == null) {
    return null;
  }
  return (keyMgmt: keyMgmt, psk: psk ?? '');
}

String? parseWifiDevice(String stdout) {
  for (final raw in stdout.split('\n')) {
    final parts = raw.trim().split(':');
    if (parts.length >= 2 && parts[1] == 'wifi' && parts[0].isNotEmpty) {
      return parts[0];
    }
  }
  return null;
}

WifiSecurity? securityFromKeyMgmt(String keyMgmt) {
  switch (keyMgmt) {
    case 'wpa-psk':
      return WifiSecurity.wpa2Psk;
    case 'sae':
      return WifiSecurity.wpa3Sae;
    default:
      return null;
  }
}

class LinuxNm {
  LinuxNm(this._runner, {Random? random}) : _random = random ?? Random.secure();

  final CommandRunner _runner;
  final Random _random;
  String? _joinedSsid;

  Future<OsWifiNetwork?> readPersonal() async {
    final active = await _runner.run('nmcli', const [
      '-t',
      '-f',
      'NAME,UUID,TYPE,DEVICE',
      'connection',
      'show',
      '--active',
    ]);
    if (!active.ok) {
      return null;
    }
    final rows = parseActiveWifi(active.stdout);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final secret = await _runner.run('nmcli', [
      '--show-secrets',
      '-t',
      '-f',
      '802-11-wireless-security.key-mgmt,802-11-wireless-security.psk',
      'connection',
      'show',
      row.uuid,
    ]);
    if (!secret.ok) {
      return null;
    }
    final parsed = parseNmSecrets(secret.stdout);
    if (parsed == null) {
      return null;
    }
    final security = securityFromKeyMgmt(parsed.keyMgmt);
    if (security == null || parsed.psk.isEmpty) {
      return null;
    }
    return OsWifiNetwork(
      ssid: row.name,
      passphrase: parsed.psk,
      security: security,
    );
  }

  Future<HotspotCredentials> startHotspot() async {
    final devices = await _runner.run('nmcli', const [
      '-t',
      '-f',
      'DEVICE,TYPE',
      'device',
    ]);
    final device = devices.ok ? parseWifiDevice(devices.stdout) : null;
    if (device == null) {
      throw const PrivateNetworkException(HostMethod.hotspot);
    }
    final ssid = 'BLAN-${_hex4()}';
    final passphrase = _passphrase();
    final added = await _runner.run('nmcli', [
      'connection',
      'add',
      'type',
      'wifi',
      'ifname',
      device,
      'con-name',
      hotspotConnectionName,
      'autoconnect',
      'no',
      'ssid',
      ssid,
      '802-11-wireless.mode',
      'ap',
      '802-11-wireless.band',
      'bg',
      'ipv4.method',
      'shared',
      'wifi-sec.key-mgmt',
      'wpa-psk',
      'wifi-sec.psk',
      passphrase,
    ]);
    if (!added.ok) {
      await _deleteHotspot();
      throw const PrivateNetworkException(HostMethod.hotspot);
    }
    final up = await _runner.run('nmcli', const [
      'connection',
      'up',
      hotspotConnectionName,
    ]);
    if (!up.ok) {
      await _deleteHotspot();
      throw const PrivateNetworkException(HostMethod.hotspot);
    }
    return HotspotCredentials(
      ssid: ssid,
      passphrase: passphrase,
      security: WifiSecurity.wpa2Psk,
    );
  }

  Future<void> stopHotspot() async {
    await _runner.run('nmcli', const [
      'connection',
      'down',
      hotspotConnectionName,
    ]);
    await _deleteHotspot();
  }

  Future<HotspotCredentials> startWifiDirect() async {
    throw const PrivateNetworkException(HostMethod.wifiDirect);
  }

  Future<void> stopWifiDirect() async {}

  Future<void> join({
    required String ssid,
    required String passphrase,
    required bool localOnly,
  }) async {
    final result = await _runner.run('nmcli', [
      'device',
      'wifi',
      'connect',
      ssid,
      'password',
      passphrase,
    ]);
    if (!result.ok) {
      throw StateError('join failed');
    }
    _joinedSsid = ssid;
  }

  Future<void> leaveJoined() async {
    final ssid = _joinedSsid;
    _joinedSsid = null;
    if (ssid == null) {
      return;
    }
    await _runner.run('nmcli', ['connection', 'down', 'id', ssid]);
  }

  Future<void> _deleteHotspot() async {
    await _runner.run('nmcli', const [
      'connection',
      'delete',
      hotspotConnectionName,
    ]);
  }

  String _hex4() => _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');

  String _passphrase() {
    const alphabet = 'abcdefghijkmnopqrstuvwxyz23456789';
    return String.fromCharCodes(
      List.generate(
        16,
        (_) => alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
      ),
    );
  }
}
