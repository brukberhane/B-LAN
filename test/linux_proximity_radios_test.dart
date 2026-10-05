import 'dart:convert';

import 'package:blan/core/proximity/proximity_advert.dart';
import 'package:blan/core/proximity/proximity_ids.dart';
import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/platform/desktop/linux_bluez.dart';
import 'package:blan/platform/desktop/linux_command.dart';
import 'package:blan/platform/desktop/linux_nm.dart';
import 'package:blan/platform/desktop/linux_proximity_radios.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

LinuxProximityRadios _radios({FakeBluezSession? session, FakeBluezGatt? gatt}) {
  return LinuxProximityRadios(
    nm: LinuxNm(_EmptyRunner()),
    session: session ?? FakeBluezSession(),
    gatt: gatt ?? FakeBluezGatt(),
  );
}

class _EmptyRunner implements CommandRunner {
  @override
  Future<CommandResult> run(String executable, List<String> args) async {
    return const CommandResult(0, '', '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('proximity ids match the shared literals', () {
    expect(ProximityIds.manufacturerId, 0xFDA9);
    expect(ProximityIds.bleServiceUuid, '0000fda9-0000-1000-8000-00805f9b34fb');
    expect(
      ProximityIds.gattServiceUuid,
      '9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7b',
    );
    expect(
      ProximityIds.gattCharacteristicUuid,
      '9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c',
    );
  });

  test('short advert throws before BlueZ', () async {
    final session = FakeBluezSession();
    final radios = _radios(session: session);
    await expectLater(
      radios.startAdvert(payload: const [0, 1, 2], scanResponse: const []),
      throwsArgumentError,
    );
    expect(session.advertCalls, 0);
  });

  test('scan keeps 31-byte hits and drops short ones', () async {
    final session = FakeBluezSession();
    final radios = _radios(session: session);
    final hits = <BleScanHit>[];
    final sub = radios.scans.listen(hits.add);
    await radios.startScan();
    session.emit(
      BluezScanHit('/org/bluez/hci0/dev_AA', List<int>.filled(31, 1)),
    );
    session.emit(const BluezScanHit('/org/bluez/hci0/dev_BB', [1, 2, 3, 4]));
    await pumpEventQueue();
    expect(hits, hasLength(1));
    expect(hits.single.peerHandle, '/org/bluez/hci0/dev_AA');
    expect(hits.single.advert, hasLength(31));
    expect(hits.single.scanResponse, isEmpty);
    await sub.cancel();
  });

  test('scan keeps the nick that arrived with the advert', () async {
    final session = FakeBluezSession();
    final radios = _radios(session: session);
    final hits = <BleScanHit>[];
    final sub = radios.scans.listen(hits.add);
    await radios.startScan();
    session.emit(
      BluezScanHit('/org/bluez/hci0/dev_AA', List<int>.filled(31, 1), [
        65,
        100,
        97,
      ]),
    );
    await pumpEventQueue();
    expect(hits.single.scanResponse, [65, 100, 97]);
    await sub.cancel();
  });

  test('16-byte legacy manufacturer pads to 31', () {
    final sightings = BluezSightings();
    final packed = const ProximityAdvert(
      hasWifi: true,
      ipv4: [10, 0, 0, 7],
      port: 59488,
      shortPeerId: [1, 2, 3, 4],
      role: AdvertRole.none,
      groupId: [0, 0, 0, 0],
    ).pack();
    final manufacturer = DBusDict(DBusSignature('q'), DBusSignature('v'), {
      DBusUint16(ProximityIds.manufacturerId): DBusVariant(
        DBusArray.byte(packed.sublist(0, 16)),
      ),
    });
    final hit = sightings.update(
      '/org/bluez/hci0/dev_CC',
      manufacturer: manufacturer,
      touchManufacturer: true,
    );
    expect(hit!.manufacturer, hasLength(31));
    expect(
      hit.manufacturer,
      equals([...packed.sublist(0, 16), ...List<int>.filled(15, 0)]),
    );
    expect(ProximityAdvert.unpack(hit.manufacturer).port, 59488);
  });

  test('service data on a later signal fills the nick', () {
    final sightings = BluezSightings();
    final path = '/org/bluez/hci0/dev_AA';
    final manufacturer = DBusDict(DBusSignature('q'), DBusSignature('v'), {
      DBusUint16(ProximityIds.manufacturerId): DBusVariant(
        DBusArray.byte(List<int>.filled(31, 7)),
      ),
    });
    final first = sightings.update(
      path,
      manufacturer: manufacturer,
      touchManufacturer: true,
    );
    expect(first!.service, isEmpty);

    final service = DBusDict(DBusSignature('s'), DBusSignature('v'), {
      DBusString(ProximityIds.bleServiceUuid.toUpperCase()): DBusVariant(
        DBusArray.byte(utf8.encode('Ada')),
      ),
    });
    final second = sightings.update(path, service: service, touchService: true);
    expect(second!.manufacturer, List<int>.filled(31, 7));
    expect(utf8.decode(second.service), 'Ada');
  });

  test('rfcomm throws and gatt send keeps x25519', () async {
    final gatt = FakeBluezGatt();
    final radios = _radios(gatt: gatt);
    await expectLater(
      radios.connect('/dev', transport: ControlTransport.rfcomm),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'rfcomm unavailable',
        ),
      ),
    );
    final link = await radios.connect('/dev', transport: ControlTransport.gatt);
    await link.send({'x25519': 'peer-key'});
    expect(gatt.sent.single['x25519'], 'peer-key');
  });

  test('gatt frames reassemble and a hostile length clears the buffer', () {
    final buffer = FrameBuffer();
    final bytes = encodeFrame({'x25519': 'peer-key'});
    List<int>? body;
    for (var offset = 0; offset < bytes.length; offset += gattChunk) {
      final end = offset + gattChunk < bytes.length
          ? offset + gattChunk
          : bytes.length;
      body = buffer.push(bytes.sublist(offset, end));
    }
    expect(decodeFrameBody(body!)!['x25519'], 'peer-key');

    expect(buffer.push([0, 1, 0, 1]), isNull);
    final again = encodeFrame({'x25519': 'next'});
    expect(decodeFrameBody(buffer.push(again)!)!['x25519'], 'next');
  });

  test('one server write drains two frames onto one inbound link', () async {
    final inbound = GattInbound();
    final links = <ControlLink>[];
    final frames = <Map<String, dynamic>>[];
    inbound.onLink = (link) {
      links.add(link);
      link.incoming.listen(frames.add);
    };
    final bytes = [
      ...encodeFrame({'x25519': 'a'}),
      ...encodeFrame({'x25519': 'b'}),
    ];
    inbound.write('/org/bluez/hci0/dev_AA', bytes);
    await pumpEventQueue();
    expect(links, hasLength(1));
    expect(frames.map((frame) => frame['x25519']), ['a', 'b']);
  });

  test('invite present only raises the window', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('com.brukb.blan/linux');
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await LinuxInvitePresenter().present();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'presentWindow');
  });
}
