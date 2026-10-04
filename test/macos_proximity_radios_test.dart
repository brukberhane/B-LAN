import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/platform/desktop/linux_command.dart';
import 'package:blan/platform/desktop/macos_proximity_radios.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.brukb.blan/macos');
const _scans = EventChannel('com.brukb.blan/macos/scans');

const _securityArgv = [
  '/usr/bin/security',
  'find-generic-password',
  '-w',
  '-a',
  'Home',
  '-s',
  'AirPort',
  '/Library/Keychains/System.keychain',
];

class _ScriptedRunner implements CommandRunner {
  _ScriptedRunner(this._result);

  final CommandResult _result;
  final calls = <List<String>>[];

  @override
  Future<CommandResult> run(String executable, List<String> args) async {
    calls.add([executable, ...args]);
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> channelCalls;

  setUp(() {
    channelCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/macos/inbound'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/macos/frames'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockStreamHandler(_scans, null);
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/macos/inbound'),
      null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('com.brukb.blan/macos/frames'),
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

  test('wpa2 keychain read uses security and keeps the passphrase', () async {
    final runner = _ScriptedRunner(const CommandResult(0, 'sekret\n', ''));
    scriptChannel((call) {
      if (call.method == 'currentWifi') {
        return {'ssid': 'Home', 'security': 'wpa2-psk'};
      }
      return null;
    });
    final network = await MacosProximityRadios(
      commands: runner,
    ).readCurrentPersonalPsk();
    expect(network?.ssid, 'Home');
    expect(network?.passphrase, 'sekret');
    expect(network?.security, WifiSecurity.wpa2Psk);
    expect(runner.calls, [_securityArgv]);
    expect(runner.calls.single.contains('sudo'), isFalse);
  });

  test('wpa3 keychain read maps sae', () async {
    final runner = _ScriptedRunner(const CommandResult(0, 'sekret\n', ''));
    scriptChannel((_) => {'ssid': 'Home', 'security': 'wpa3-sae'});
    final network = await MacosProximityRadios(
      commands: runner,
    ).readCurrentPersonalPsk();
    expect(network?.security, WifiSecurity.wpa3Sae);
    expect(runner.calls.single[4], 'Home');
  });

  test('enterprise current wifi does not call security', () async {
    final runner = _ScriptedRunner(const CommandResult(0, 'sekret\n', ''));
    scriptChannel((_) => {'ssid': 'Home', 'security': 'other'});
    final network = await MacosProximityRadios(
      commands: runner,
    ).readCurrentPersonalPsk();
    expect(network, isNull);
    expect(runner.calls, isEmpty);
  });

  test('keychain miss, empty secret, and missing tool return null', () async {
    scriptChannel((_) => {'ssid': 'Home', 'security': 'wpa2-psk'});
    for (final result in const [
      CommandResult(44, '', ''),
      CommandResult(0, '', ''),
      CommandResult(0, '\n', ''),
      CommandResult(127, '', ''),
    ]) {
      final runner = _ScriptedRunner(result);
      final network = await MacosProximityRadios(
        commands: runner,
      ).readCurrentPersonalPsk();
      expect(network, isNull);
    }
  });

  test('startHotspot is the typed failure', () async {
    scriptChannel((_) => {'error': 'hotspotFailed'});
    final radios = MacosProximityRadios(
      commands: _ScriptedRunner(const CommandResult(0, '', '')),
    );
    await expectLater(
      radios.startHotspot(),
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
    final radios = MacosProximityRadios(
      commands: _ScriptedRunner(const CommandResult(0, '', '')),
    );
    await expectLater(
      radios.startWifiDirect(),
      throwsA(
        isA<PrivateNetworkException>().having(
          (error) => error.method,
          'method',
          HostMethod.wifiDirect,
        ),
      ),
    );
  });

  test('short advert throws before the channel', () async {
    scriptChannel((_) => null);
    final radios = MacosProximityRadios(
      commands: _ScriptedRunner(const CommandResult(0, '', '')),
    );
    await expectLater(
      radios.startAdvert(payload: const [0, 1, 2], scanResponse: const []),
      throwsArgumentError,
    );
    expect(channelCalls, isEmpty);
  });

  test('scan keeps 31-byte adverts and drops short ones', () async {
    MockStreamHandlerEventSink? sink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _scans,
          MockStreamHandler.inline(onListen: (_, events) => sink = events),
        );
    final radios = MacosProximityRadios(
      commands: _ScriptedRunner(const CommandResult(0, '', '')),
    );
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
    final radios = MacosProximityRadios(
      commands: _ScriptedRunner(const CommandResult(0, '', '')),
    );
    await expectLater(
      radios.connect('peer', transport: ControlTransport.rfcomm),
      throwsA(isA<StateError>()),
    );
    expect(channelCalls, isEmpty);

    final link = await radios.connect('peer', transport: ControlTransport.gatt);
    await link.send({'x25519': 'peer-key'});
    final send = channelCalls.singleWhere((call) => call.method == 'sendFrame');
    final args = (send.arguments as Map).cast<String, Object?>();
    expect(args['frameJson'], contains('x25519'));
    expect(args['frameJson'], contains('peer-key'));
  });

  test('invite present only raises the window', () async {
    scriptChannel((_) => null);
    await MacosInvitePresenter().present();
    expect(channelCalls, hasLength(1));
    expect(channelCalls.single.method, 'presentWindow');
  });
}
