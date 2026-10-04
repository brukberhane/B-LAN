import 'dart:math';

import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/platform/desktop/linux_command.dart';
import 'package:blan/platform/desktop/linux_nm.dart';
import 'package:flutter_test/flutter_test.dart';

class ScriptedRunner implements CommandRunner {
  ScriptedRunner(this._results);

  final List<CommandResult> _results;
  final argv = <List<String>>[];
  var _index = 0;

  @override
  Future<CommandResult> run(String executable, List<String> args) async {
    argv.add([executable, ...args]);
    if (_index >= _results.length) {
      return const CommandResult(0, '', '');
    }
    return _results[_index++];
  }
}

void main() {
  test('active personal wpa-psk skips blan-hotspot', () async {
    final runner = ScriptedRunner(const [
      CommandResult(
        0,
        'blan-hotspot:dead:802-11-wireless:wlan0\n'
            'Home:abc:802-11-wireless:wlan0\n',
        '',
      ),
      CommandResult(
        0,
        '802-11-wireless-security.key-mgmt:wpa-psk\n'
            '802-11-wireless-security.psk:sekret\n',
        '',
      ),
    ]);
    final network = await LinuxNm(runner).readPersonal();
    expect(network, isNotNull);
    expect(network!.ssid, 'Home');
    expect(network.passphrase, 'sekret');
    expect(network.security, WifiSecurity.wpa2Psk);
    expect(runner.argv[1], contains('abc'));
  });

  test('escaped colon in the name stays in the ssid', () async {
    final runner = ScriptedRunner(const [
      CommandResult(0, 'Home\\:net:abc:802-11-wireless:wlan0\n', ''),
      CommandResult(
        0,
        '802-11-wireless-security.key-mgmt:wpa-psk\n'
            '802-11-wireless-security.psk:sek\\:ret\n',
        '',
      ),
    ]);
    final network = await LinuxNm(runner).readPersonal();
    expect(network!.ssid, 'Home:net');
    expect(network.passphrase, 'sek:ret');
  });

  test('sae maps to wpa3', () async {
    final runner = ScriptedRunner(const [
      CommandResult(0, 'Cafe:uuid:802-11-wireless:wlan0\n', ''),
      CommandResult(
        0,
        '802-11-wireless-security.key-mgmt:sae\n'
            '802-11-wireless-security.psk:sekret\n',
        '',
      ),
    ]);
    final network = await LinuxNm(runner).readPersonal();
    expect(network!.security, WifiSecurity.wpa3Sae);
  });

  test('enterprise and empty psk return null', () async {
    final enterprise = ScriptedRunner(const [
      CommandResult(0, 'Work:uuid:802-11-wireless:wlan0\n', ''),
      CommandResult(
        0,
        '802-11-wireless-security.key-mgmt:wpa-eap\n'
            '802-11-wireless-security.psk:sekret\n',
        '',
      ),
    ]);
    expect(await LinuxNm(enterprise).readPersonal(), isNull);

    final empty = ScriptedRunner(const [
      CommandResult(0, 'Home:uuid:802-11-wireless:wlan0\n', ''),
      CommandResult(
        0,
        '802-11-wireless-security.key-mgmt:wpa-psk\n'
            '802-11-wireless-security.psk:\n',
        '',
      ),
    ]);
    expect(await LinuxNm(empty).readPersonal(), isNull);
  });

  test('missing nmcli returns null', () async {
    final runner = ScriptedRunner(const [CommandResult(127, '', '')]);
    expect(await LinuxNm(runner).readPersonal(), isNull);
  });

  test('startHotspot uses nmcli ap and returns the passphrase', () async {
    final runner = ScriptedRunner(const [CommandResult(0, 'wlan0:wifi\n', '')]);
    final creds = await LinuxNm(runner, random: Random(1)).startHotspot();
    final add = runner.argv.firstWhere((args) => args.contains('add'));
    expect(add, contains('blan-hotspot'));
    expect(add, contains('802-11-wireless.mode'));
    expect(add, contains('ap'));
    expect(add, contains('wpa-psk'));
    expect(add, contains(creds.passphrase));
    expect(creds.security, WifiSecurity.wpa2Psk);
    expect(creds.passphrase, hasLength(16));
    for (final args in runner.argv) {
      final line = args.join(' ');
      expect(line.contains('p2p'), isFalse);
      expect(line.contains('wifi-direct'), isFalse);
    }
  });

  test('failed hotspot up deletes the connection', () async {
    final runner = ScriptedRunner(const [
      CommandResult(0, 'wlan0:wifi\n', ''),
      CommandResult(0, '', ''),
      CommandResult(1, '', 'up failed'),
    ]);
    await expectLater(
      LinuxNm(runner, random: Random(1)).startHotspot(),
      throwsA(
        isA<PrivateNetworkException>().having(
          (error) => error.method,
          'method',
          HostMethod.hotspot,
        ),
      ),
    );
    expect(
      runner.argv.any(
        (args) => args.contains('delete') && args.contains('blan-hotspot'),
      ),
      isTrue,
    );
  });

  test('wifi direct throws without a command', () async {
    final runner = ScriptedRunner(const []);
    await expectLater(
      LinuxNm(runner).startWifiDirect(),
      throwsA(
        isA<PrivateNetworkException>().having(
          (error) => error.method,
          'method',
          HostMethod.wifiDirect,
        ),
      ),
    );
    expect(runner.argv, isEmpty);
  });

  test('join failure is a state error and leave uses the last ssid', () async {
    final failed = ScriptedRunner(const [CommandResult(1, '', '')]);
    await expectLater(
      LinuxNm(failed).join(ssid: 'Cafe', passphrase: 'sekret', localOnly: true),
      throwsA(isA<StateError>()),
    );
    expect(failed.argv.single, contains('Cafe'));
    expect(failed.argv.single.join(' '), isNot(contains('local-only')));

    final joined = ScriptedRunner(const [CommandResult(0, '', '')]);
    final nm = LinuxNm(joined);
    await nm.join(ssid: 'Cafe', passphrase: 'sekret', localOnly: false);
    await nm.leaveJoined();
    expect(joined.argv.last, contains('Cafe'));
    expect(joined.argv.last, contains('down'));
  });

  test('stopHotspot downs and deletes even when nmcli fails', () async {
    final runner = ScriptedRunner(const [
      CommandResult(1, '', ''),
      CommandResult(1, '', ''),
    ]);
    await LinuxNm(runner).stopHotspot();
    expect(
      runner.argv.any(
        (args) => args.contains('down') && args.contains('blan-hotspot'),
      ),
      isTrue,
    );
    expect(
      runner.argv.any(
        (args) => args.contains('delete') && args.contains('blan-hotspot'),
      ),
      isTrue,
    );
  });
}
