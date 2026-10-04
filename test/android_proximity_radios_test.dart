import 'package:blan/core/proximity/proximity_advert.dart';
import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/platform/android/android_proximity_radios.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.brukb.blan/proximity';
  const scansEvent = EventChannel('$channelName/scans');
  const framesEvent = EventChannel('$channelName/frames');
  const inviteResultEvent = EventChannel('$channelName/inviteResult');

  late TestDefaultBinaryMessenger messenger;
  late List<MethodCall> calls;
  Map<String, Object?> replies = {};

  setUp(() {
    messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    calls = [];
    replies = {};
    messenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      (call) async {
        calls.add(call);
        return replies[call.method];
      },
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(channelName), null);
    messenger.setMockStreamHandler(scansEvent, null);
    messenger.setMockStreamHandler(framesEvent, null);
    messenger.setMockStreamHandler(inviteResultEvent, null);
  });

  final payload = const ProximityAdvert(
    hasWifi: true,
    ipv4: [10, 0, 0, 7],
    port: 59488,
    shortPeerId: [1, 2, 3, 4],
    role: AdvertRole.owner,
    groupId: [0, 0, 0, 1],
  ).pack();
  final scanResponse = const ProximityScanResponse(nick: 'Ada').pack();

  test('startAdvert hops payload and scan response verbatim', () async {
    final radios = AndroidProximityRadios();
    await radios.startAdvert(payload: payload, scanResponse: scanResponse);

    final call = calls.singleWhere((c) => c.method == 'startAdvert');
    expect(call.arguments['payload'], Uint8List.fromList(payload));
    expect(call.arguments['scanResponse'], Uint8List.fromList(scanResponse));
  });

  test('startAdvert asserts 31 bytes before any channel hop', () async {
    final radios = AndroidProximityRadios();
    await expectLater(
      radios.startAdvert(payload: const [0, 1, 2], scanResponse: const []),
      throwsArgumentError,
    );
    expect(calls.where((c) => c.method == 'startAdvert'), isEmpty);
  });

  test('scans events map to BleScanHit', () async {
    MockStreamHandlerEventSink? sink;
    messenger.setMockStreamHandler(
      scansEvent,
      MockStreamHandler.inline(
        onListen: (_, events) => sink = events,
      ),
    );
    final radios = AndroidProximityRadios();
    final hits = <BleScanHit>[];
    final sub = radios.scans.listen(hits.add);
    await pumpEventQueue();
    sink!.success({
      'peerHandle': 'AA:BB:CC:DD:EE:FF',
      'advert': Uint8List.fromList(payload),
      'scanResponse': Uint8List.fromList(scanResponse),
    });
    await pumpEventQueue();

    expect(hits.single.peerHandle, 'AA:BB:CC:DD:EE:FF');
    expect(hits.single.advert, payload);
    expect(hits.single.scanResponse, scanResponse);
    await sub.cancel();
  });

  test('startHotspot maps creds incl WifiSecurity.fromWire', () async {
    replies['startHotspot'] = {
      'ssid': 'AndroidAP1234',
      'passphrase': 'hotspot-psk',
      'security': 'wpa2-psk',
    };
    final radios = AndroidProximityRadios();
    final creds = await radios.startHotspot();

    expect(creds.ssid, 'AndroidAP1234');
    expect(creds.passphrase, 'hotspot-psk');
    expect(creds.security, WifiSecurity.wpa2Psk);

    replies['startWifiDirect'] = {
      'ssid': 'DIRECT-xy',
      'passphrase': 'wfd-psk',
      'security': 'wpa2-psk',
    };
    final wfd = await radios.startWifiDirect();
    expect(wfd.ssid, 'DIRECT-xy');
    expect(wfd.security, WifiSecurity.wpa2Psk);
  });

  test('radio error codes map to PrivateNetworkException', () async {
    replies['startHotspot'] = {'error': 'hotspotFailed'};
    replies['startWifiDirect'] = {'error': 'wifiDirectFailed'};
    final radios = AndroidProximityRadios();

    await expectLater(
      radios.startHotspot(),
      throwsA(isA<PrivateNetworkException>().having(
        (e) => e.method,
        'method',
        HostMethod.hotspot,
      )),
    );
    await expectLater(
      radios.startWifiDirect(),
      throwsA(isA<PrivateNetworkException>().having(
        (e) => e.method,
        'method',
        HostMethod.wifiDirect,
      )),
    );
  });

  test('join hops ssid, passphrase, security wire, localOnly', () async {
    final radios = AndroidProximityRadios();
    await radios.join(
      ssid: 'DIRECT-xy',
      passphrase: 'join-psk',
      security: WifiSecurity.wpa3Sae,
      localOnly: true,
    );

    final call = calls.singleWhere((c) => c.method == 'join');
    expect(call.arguments['ssid'], 'DIRECT-xy');
    expect(call.arguments['passphrase'], 'join-psk');
    expect(call.arguments['security'], 'wpa3-sae');
    expect(call.arguments['localOnly'], true);
  });

  test('connectControl + sendFrame keep linkId and x25519', () async {
    MockStreamHandlerEventSink? frameSink;
    messenger.setMockStreamHandler(
      framesEvent,
      MockStreamHandler.inline(onListen: (_, events) => frameSink = events),
    );

    replies['connectControl'] = 7;
    final radios = AndroidProximityRadios();
    final link = await radios.connect(
      'AA:BB:CC:DD:EE:FF',
      transport: ControlTransport.rfcomm,
    );

    final connectCall = calls.singleWhere((c) => c.method == 'connectControl');
    expect(connectCall.arguments['peerHandle'], 'AA:BB:CC:DD:EE:FF');
    expect(connectCall.arguments['transport'], 'rfcomm');
    expect(link.transport, ControlTransport.rfcomm);

    final incoming = <Map<String, dynamic>>[];
    final sub = link.incoming.listen(incoming.add);
    await pumpEventQueue();

    await link.send({
      'type': 'hello',
      'from': 'peer-a',
      'x25519': 'base64key',
      'body': {'nick': 'Ada'},
    });
    final sendCall = calls.singleWhere((c) => c.method == 'sendFrame');
    expect(sendCall.arguments['linkId'], 7);
    final sent = sendCall.arguments['frameJson'] as String;
    expect(sent, contains('"x25519":"base64key"'));

    frameSink!.success({'linkId': 7, 'frameJson': '{"x25519":"peer-key"}'});
    await pumpEventQueue();
    expect(incoming.single, {'x25519': 'peer-key'});

    await sub.cancel();
    await link.close();
  });

  test('invite presenter relays dialog path and accept result', () async {
    MockStreamHandlerEventSink? inviteSink;
    messenger.setMockStreamHandler(
      inviteResultEvent,
      MockStreamHandler.inline(onListen: (_, events) => inviteSink = events),
    );

    replies['showInvite'] = 'dialog';
    final presenter = AndroidInvitePresenter();
    final results = <String>[];
    final sub = presenter.inviteResults.listen(results.add);
    await pumpEventQueue();

    final path = await presenter.showInvite(nick: 'Ada', code: '123456');
    expect(path, 'dialog');
    expect(
      calls.singleWhere((c) => c.method == 'showInvite').arguments,
      {'nick': 'Ada', 'code': '123456'},
    );

    inviteSink!.success('accept');
    await pumpEventQueue();
    expect(results, ['accept']);
    await sub.cancel();
  });

  test('invite presenter falls back to notification and declines', () async {
    MockStreamHandlerEventSink? inviteSink;
    messenger.setMockStreamHandler(
      inviteResultEvent,
      MockStreamHandler.inline(onListen: (_, events) => inviteSink = events),
    );

    replies['showInvite'] = 'notification';
    replies['hasFullScreenIntent'] = false;
    replies['hasOverlayPermission'] = false;
    final presenter = AndroidInvitePresenter();
    final results = <String>[];
    final sub = presenter.inviteResults.listen(results.add);
    await pumpEventQueue();

    expect(await presenter.hasFullScreenIntent(), isFalse);
    expect(await presenter.hasOverlayPermission(), isFalse);
    expect(await presenter.showInvite(nick: 'Ada', code: '654321'),
        'notification');

    inviteSink!.success('decline');
    await pumpEventQueue();
    expect(results, ['decline']);
    await sub.cancel();
  });

  test('readCurrentPersonalPsk maps the privileged reply and nothing else', () async {
    replies['readPersonalPsk'] = {
      'ssid': 'Home',
      'passphrase': 'sekret',
      'security': 'wpa3-sae',
    };
    final radios = AndroidProximityRadios();
    final network = await radios.readCurrentPersonalPsk();
    expect(network?.ssid, 'Home');
    expect(network?.passphrase, 'sekret');
    expect(network?.security, WifiSecurity.wpa3Sae);
    expect(calls.map((call) => call.method), ['readPersonalPsk']);
  });

  test('readCurrentPersonalPsk null reply stays null', () async {
    replies['readPersonalPsk'] = null;
    final radios = AndroidProximityRadios();
    expect(await radios.readCurrentPersonalPsk(), isNull);
  });

  test('shizuku facts recognize Shevery ahead of official Shizuku', () async {
    replies['shizukuFacts'] = {
      'known': [
        {
          'name': 'com.hamondev.shevery',
          'installed': true,
          'permissions': ['moe.shizuku.manager.permission.API_V23'],
        },
        {
          'name': 'moe.shizuku.privileged.api',
          'installed': true,
          'permissions': ['moe.shizuku.manager.permission.MANAGER'],
        },
      ],
      'candidates': [],
    };
    final consent = AndroidShizukuConsent();
    expect(await consent.detectedPackage(), 'com.hamondev.shevery');
  });

  test('confirm channel error is not a stored No', () async {
    messenger.setMockMethodCallHandler(
      const MethodChannel(channelName),
      (call) async {
        throw PlatformException(code: 'noActivity');
      },
    );
    final consent = AndroidShizukuConsent();
    expect(consent.confirm(), throwsA(isA<PlatformException>()));
  });

  test('inbound events map to ControlLink with transport', () async {
    MockStreamHandlerEventSink? inboundSink;
    messenger.setMockStreamHandler(
      const EventChannel('$channelName/inbound'),
      MockStreamHandler.inline(onListen: (_, events) => inboundSink = events),
    );
    final radios = AndroidProximityRadios();
    final links = <ControlLink>[];
    final sub = radios.inbound.listen(links.add);
    await pumpEventQueue();

    inboundSink!.success({'linkId': 5, 'transport': 'gatt'});
    await pumpEventQueue();

    expect(links.single.transport, ControlTransport.gatt);
    await sub.cancel();
  });

  test('frames filter by linkId and strip internal tag', () async {
    MockStreamHandlerEventSink? frameSink;
    messenger.setMockStreamHandler(
      framesEvent,
      MockStreamHandler.inline(onListen: (_, events) => frameSink = events),
    );
    final radios = AndroidProximityRadios();
    replies['connectControl'] = 7;
    final linkA = await radios.connect('AA:AA:AA:AA:AA:AA',
        transport: ControlTransport.rfcomm);
    replies['connectControl'] = 9;
    final linkB = await radios.connect('BB:BB:BB:BB:BB:BB',
        transport: ControlTransport.rfcomm);

    final gotA = <Map<String, dynamic>>[];
    final gotB = <Map<String, dynamic>>[];
    final subA = linkA.incoming.listen(gotA.add);
    final subB = linkB.incoming.listen(gotB.add);
    await pumpEventQueue();

    frameSink!.success({'linkId': 9, 'frameJson': '{"x25519":"key-b"}'});
    frameSink!.success({'linkId': 7, 'frameJson': '{"x25519":"key-a"}'});
    await pumpEventQueue();

    expect(gotB.single, {'x25519': 'key-b'});
    expect(gotA.single, {'x25519': 'key-a'});
    expect(gotA.single.containsKey('__linkId'), isFalse);

    await subA.cancel();
    await subB.cancel();
  });

  test('sendFrame error map throws StateError, not silent success', () async {
    replies['connectControl'] = 7;
    replies['sendFrame'] = {'error': 'sendFailed'};
    final radios = AndroidProximityRadios();
    final link = await radios.connect(
      'AA:BB:CC:DD:EE:FF',
      transport: ControlTransport.rfcomm,
    );
    await expectLater(link.send({'type': 'invite'}), throwsStateError);
  });
}