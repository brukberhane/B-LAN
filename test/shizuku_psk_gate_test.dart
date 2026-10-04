import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/core/security/shizuku_psk_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const network = OsWifiNetwork(
    ssid: 'Home',
    passphrase: 'sekret',
    security: WifiSecurity.wpa2Psk,
  );

  Future<OsWifiNetwork?> run({
    required bool? choice,
    required List<String> states,
    bool askAnswer = false,
    OsWifiNetwork? readResult = network,
    List<String>? calls,
  }) {
    var index = 0;
    return ShizukuPskGate.read(
      choice: () async => choice,
      persist: (allow) async => calls?.add('persist:$allow'),
      state: () async => states[index++],
      requestPermission: () async => calls?.add('requestPermission'),
      ask: () async {
        calls?.add('ask');
        return askAnswer;
      },
      read: () async {
        calls?.add('read');
        return readResult;
      },
    );
  }

  test('explicit no skips the dialog and the read', () async {
    final calls = <String>[];
    expect(
      await run(choice: false, states: const ['ready'], calls: calls),
      isNull,
    );
    expect(calls, isEmpty);
  });

  test('dead, missing, and too-old binders do not ask', () async {
    for (final state in ['dead', 'notInstalled', 'tooOld']) {
      final calls = <String>[];
      expect(
        await run(choice: null, states: [state], calls: calls),
        isNull,
      );
      expect(calls, isEmpty);
    }
  });

  test('first ask declined is persisted and does not read', () async {
    final calls = <String>[];
    expect(
      await run(
        choice: null,
        states: const ['ready'],
        askAnswer: false,
        calls: calls,
      ),
      isNull,
    );
    expect(calls, ['ask', 'persist:false']);
  });

  test('yes with no permission requests, then reads when ready', () async {
    final calls = <String>[];
    var index = 0;
    const states = ['noPermission', 'ready'];
    final got = await ShizukuPskGate.read(
      choice: () async => null,
      persist: (allow) async => calls.add('persist:$allow'),
      state: () async => states[index++],
      requestPermission: () async => calls.add('requestPermission'),
      ask: () async {
        calls.add('ask');
        return true;
      },
      read: () async {
        calls.add('read');
        return network;
      },
    );
    expect(got, network);
    expect(calls, ['ask', 'persist:true', 'requestPermission', 'read']);
  });

  test('allowed choice returns the network from read', () async {
    final calls = <String>[];
    final got = await run(choice: true, states: const ['ready'], calls: calls);
    expect(got?.passphrase, 'sekret');
    expect(got?.security, WifiSecurity.wpa2Psk);
    expect(calls, ['read']);
  });

  test('empty read stays null and does not revoke yes', () async {
    final calls = <String>[];
    expect(
      await run(
        choice: true,
        states: const ['ready'],
        readResult: null,
        calls: calls,
      ),
      isNull,
    );
    expect(calls, ['read']);
  });

  test('a failed ask is not persisted as No', () async {
    final calls = <String>[];
    await expectLater(
      ShizukuPskGate.read(
        choice: () async => null,
        persist: (allow) async => calls.add('persist:$allow'),
        state: () async => 'ready',
        requestPermission: () async {},
        ask: () async => throw StateError('dialog not shown'),
        read: () async => network,
      ),
      throwsStateError,
    );
    expect(calls, isEmpty);
  });
}
