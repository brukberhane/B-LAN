import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/platform/desktop/windows_proximity_radios.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.brukb.blan/windows');
const _scans = EventChannel('com.brukb.blan/windows/scans');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> channelCalls;

  setUp(() {
    channelCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/windows/inbound'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/windows/frames'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockStreamHandler(_scans, null);
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/windows/inbound'),
      null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/windows/frames'),
      null,
    );
  });

  void scriptChannel(Object? Function(MethodCall call) reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          channelCalls.add(call);
          return reply(call);
        });
  }

  test('short advert throws before the channel', () async {
    scriptChannel((_) => null);
    await expectLater(
      WindowsProximityRadios().startAdvert(
        payload: const [0, 1, 2],
        scanResponse: const [],
      ),
      throwsArgumentError,
    );
    expect(channelCalls, isEmpty);
  });

  test('31-byte advert is sent on the channel', () async {
    scriptChannel((_) => null);
    final payload = List<int>.filled(31, 1);
    await WindowsProximityRadios().startAdvert(
      payload: payload,
      scanResponse: const [2],
    );
    final call = channelCalls.single;
    expect(call.method, 'startAdvert');
    expect((call.arguments as Map)['payload'], payload);
  });

  test('scan keeps 31-byte adverts and drops short ones', () async {
    MockStreamHandlerEventSink? sink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _scans,
          MockStreamHandler.inline(onListen: (_, events) => sink = events),
        );
    final radios = WindowsProximityRadios();
    final hits = <BleScanHit>[];
    final sub = radios.scans.listen(hits.add);
    await pumpEventQueue();
    sink!.success({
      'peerHandle': 'peer-1',
      'advert': Uint8List(31),
      'scanResponse': Uint8List(0),
    });
    sink!.success({
      'peerHandle': 'peer-2',
      'advert': Uint8List(4),
      'scanResponse': Uint8List(0),
    });
    await pumpEventQueue();
    expect(hits, hasLength(1));
    expect(hits.single.peerHandle, 'peer-1');
    expect(hits.single.advert, hasLength(31));
    await sub.cancel();
  });

  test('rfcomm throws and gatt send keeps x25519', () async {
    scriptChannel((call) {
      if (call.method == 'connectControl') {
        return 3;
      }
      return null;
    });
    final radios = WindowsProximityRadios();
    await expectLater(
      radios.connect('peer', transport: ControlTransport.rfcomm),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'rfcomm unavailable',
        ),
      ),
    );
    expect(channelCalls, isEmpty);

    final link = await radios.connect('peer', transport: ControlTransport.gatt);
    await link.send({'x25519': 'peer-key'});
    final send = channelCalls.singleWhere((call) => call.method == 'sendFrame');
    final args = (send.arguments as Map).cast<String, Object?>();
    expect(args['frameJson'], contains('x25519'));
    expect(args['frameJson'], contains('peer-key'));
  });

  test('startHotspot is the typed failure', () async {
    scriptChannel((_) => {'error': 'hotspotFailed'});
    await expectLater(
      WindowsProximityRadios().startHotspot(),
      throwsA(
        isA<PrivateNetworkException>().having(
          (error) => error.method,
          'method',
          HostMethod.hotspot,
        ),
      ),
    );
  });

  test('startWifiDirect is the typed failure', () async {
    scriptChannel((_) => {'error': 'wifiDirectFailed'});
    await expectLater(
      WindowsProximityRadios().startWifiDirect(),
      throwsA(
        isA<PrivateNetworkException>().having(
          (error) => error.method,
          'method',
          HostMethod.wifiDirect,
        ),
      ),
    );
  });

  test('missing and empty wifi replies are null', () async {
    final radios = WindowsProximityRadios();
    scriptChannel((_) => null);
    expect(await radios.readCurrentPersonalPsk(), isNull);

    scriptChannel(
      (_) => {'ssid': 'Home', 'passphrase': '', 'security': 'wpa2-psk'},
    );
    expect(await radios.readCurrentPersonalPsk(), isNull);
  });

  test('invite present only raises the window', () async {
    scriptChannel((_) => null);
    await WindowsInvitePresenter().present();
    expect(channelCalls, hasLength(1));
    expect(channelCalls.single.method, 'presentWindow');
  });
}
