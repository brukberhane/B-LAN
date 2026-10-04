import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';

import '../../core/proximity/proximity_ids.dart';
import '../../core/proximity/proximity_radios.dart';

class BluezScanHit {
  const BluezScanHit(this.path, this.manufacturer);

  final String path;
  final List<int> manufacturer;
}

abstract class BluezSession {
  Future<void> advertise({
    required List<int> manufacturer,
    required List<int> nick,
  });
  Future<void> stopAdvert();
  Future<void> startScan();
  Future<void> stopScan();
  Stream<BluezScanHit> get scans;
  Future<void> close();
}

abstract class BluezGatt {
  void bindInbound(void Function(ControlLink link) onLink) {}
  Future<void> expose() => Future<void>.value();
  Future<ControlLink> connect(String peerHandle);
  Future<void> close();
}

class FakeBluezSession implements BluezSession {
  int advertCalls = 0;
  final _scans = StreamController<BluezScanHit>.broadcast();

  void emit(BluezScanHit hit) => _scans.add(hit);

  @override
  Future<void> advertise({
    required List<int> manufacturer,
    required List<int> nick,
  }) async {
    advertCalls++;
  }

  @override
  Future<void> stopAdvert() async {}

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Stream<BluezScanHit> get scans => _scans.stream;

  @override
  Future<void> close() async {}
}

class FakeBluezGatt implements BluezGatt {
  final sent = <Map<String, dynamic>>[];
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();

  @override
  void bindInbound(void Function(ControlLink link) onLink) {}

  @override
  Future<void> expose() => Future<void>.value();

  @override
  Future<ControlLink> connect(String peerHandle) async {
    return _FakeGattLink(this);
  }

  @override
  Future<void> close() async {}
}

class _FakeGattLink implements ControlLink {
  _FakeGattLink(this._gatt);

  final FakeBluezGatt _gatt;

  @override
  ControlTransport get transport => ControlTransport.gatt;

  @override
  Future<void> send(Map<String, dynamic> frame) async {
    _gatt.sent.add(frame);
  }

  @override
  Stream<Map<String, dynamic>> get incoming => _gatt._incoming.stream;

  @override
  Future<void> close() async {}
}

const frameCap = 64 * 1024;
const gattChunk = 20;

class FrameBuffer {
  final _bytes = <int>[];

  List<int>? push(List<int> chunk) {
    _bytes.addAll(chunk);
    if (_bytes.length < 4) {
      return null;
    }
    final length = ByteData.sublistView(
      Uint8List.fromList(_bytes.sublist(0, 4)),
    ).getUint32(0);
    if (length > frameCap) {
      _bytes.clear();
      return null;
    }
    if (_bytes.length < 4 + length) {
      return null;
    }
    final body = _bytes.sublist(4, 4 + length);
    _bytes.removeRange(0, 4 + length);
    return body;
  }
}

List<int> encodeFrame(Map<String, dynamic> frame) {
  final body = utf8.encode(jsonEncode(frame));
  if (body.length > frameCap) {
    throw StateError('frame too large');
  }
  final out = Uint8List(4 + body.length);
  ByteData.sublistView(out).setUint32(0, body.length);
  out.setRange(4, out.length, body);
  return out;
}

Map<String, dynamic>? decodeFrameBody(List<int> body) {
  try {
    final decoded = jsonDecode(utf8.decode(body));
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } on FormatException {
    return null;
  }
  return null;
}

class DBusBluezSession implements BluezSession {
  DBusClient? _client;
  DBusRemoteObjectManager? _manager;
  StreamSubscription<DBusSignal>? _scanSub;
  _BluezAdvert? _advert;
  DBusObjectPath? _adapter;
  final _scans = StreamController<BluezScanHit>.broadcast();

  @override
  Stream<BluezScanHit> get scans => _scans.stream;

  Future<DBusClient> _bus() async {
    final existing = _client;
    if (existing != null) {
      return existing;
    }
    try {
      final client = DBusClient.system();
      _client = client;
      _manager = DBusRemoteObjectManager(
        client,
        name: 'org.bluez',
        path: DBusObjectPath('/'),
      );
      return client;
    } catch (error) {
      throw StateError('bluez bus: $error');
    }
  }

  Future<DBusObjectPath> _adapterPath() async {
    final cached = _adapter;
    if (cached != null) {
      return cached;
    }
    await _bus();
    try {
      final objects = await _manager!.getManagedObjects();
      for (final entry in objects.entries) {
        if (entry.value.containsKey('org.bluez.Adapter1')) {
          _adapter = entry.key;
          return entry.key;
        }
      }
    } catch (error) {
      throw StateError('bluez adapter: $error');
    }
    throw StateError('bluez adapter missing');
  }

  @override
  Future<void> advertise({
    required List<int> manufacturer,
    required List<int> nick,
  }) async {
    final client = await _bus();
    final adapter = await _adapterPath();
    if (_advert != null) {
      await stopAdvert();
    }
    final advert = _BluezAdvert(manufacturer, nick);
    await client.registerObject(advert);
    final remote = DBusRemoteObject(client, name: 'org.bluez', path: adapter);
    try {
      await remote.callMethod(
        'org.bluez.LEAdvertisingManager1',
        'RegisterAdvertisement',
        [advert.path, DBusDict.stringVariant(<String, DBusValue>{})],
        replySignature: DBusSignature(''),
      );
    } catch (error) {
      await client.unregisterObject(advert);
      throw StateError('bluez advertise: $error');
    }
    _advert = advert;
  }

  @override
  Future<void> stopAdvert() async {
    final advert = _advert;
    final adapter = _adapter;
    final client = _client;
    _advert = null;
    if (advert == null || adapter == null || client == null) {
      return;
    }
    final remote = DBusRemoteObject(client, name: 'org.bluez', path: adapter);
    try {
      await remote.callMethod(
        'org.bluez.LEAdvertisingManager1',
        'UnregisterAdvertisement',
        [advert.path],
        replySignature: DBusSignature(''),
      );
    } catch (error) {
      await _dropAdvert(client, advert);
      throw StateError('bluez advertise: $error');
    }
    await _dropAdvert(client, advert);
  }

  Future<void> _dropAdvert(DBusClient client, DBusObject advert) async {
    if (advert.client != null) {
      await client.unregisterObject(advert);
    }
  }

  @override
  Future<void> startScan() async {
    final client = await _bus();
    final adapter = await _adapterPath();
    _scanSub ??= _manager!.signals.listen(_onSignal);
    final remote = DBusRemoteObject(client, name: 'org.bluez', path: adapter);
    try {
      await remote.callMethod('org.bluez.Adapter1', 'SetDiscoveryFilter', [
        DBusDict.stringVariant(<String, DBusValue>{
          'Transport': const DBusString('le'),
        }),
      ], replySignature: DBusSignature(''));
      await remote.callMethod(
        'org.bluez.Adapter1',
        'StartDiscovery',
        const [],
        replySignature: DBusSignature(''),
      );
    } catch (error) {
      throw StateError('bluez scan: $error');
    }
  }

  @override
  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    final adapter = _adapter;
    final client = _client;
    if (adapter == null || client == null) {
      return;
    }
    final remote = DBusRemoteObject(client, name: 'org.bluez', path: adapter);
    try {
      await remote.callMethod(
        'org.bluez.Adapter1',
        'StopDiscovery',
        const [],
        replySignature: DBusSignature(''),
      );
    } catch (error) {
      throw StateError('bluez scan: $error');
    }
  }

  void _onSignal(DBusSignal signal) {
    if (signal is DBusObjectManagerInterfacesAddedSignal) {
      final device = signal.interfacesAndProperties['org.bluez.Device1'];
      _emit(signal.changedPath.value, device?['ManufacturerData']);
      return;
    }
    if (signal is DBusPropertiesChangedSignal &&
        signal.propertiesInterface == 'org.bluez.Device1') {
      _emit(signal.path.value, signal.changedProperties['ManufacturerData']);
    }
  }

  void _emit(String path, DBusValue? manufacturer) {
    final bytes = manufacturerPayload(manufacturer);
    if (bytes == null || bytes.length != 31) {
      return;
    }
    _scans.add(BluezScanHit(path, bytes));
  }

  @override
  Future<void> close() async {
    await _scanSub?.cancel();
    await _client?.close();
    _client = null;
    _manager = null;
    _adapter = null;
  }
}

class GattInbound {
  void Function(ControlLink link)? onLink;
  Future<void> Function(List<int> chunk)? notify;
  final _buffers = <String, FrameBuffer>{};
  final _links = <String, _InboundGattLink>{};

  void write(String devicePath, List<int> chunk) {
    final link = _links.putIfAbsent(devicePath, () {
      final created = _InboundGattLink(devicePath)..notify = notify;
      onLink?.call(created);
      return created;
    });
    final buffer = _buffers.putIfAbsent(devicePath, FrameBuffer.new);
    var body = buffer.push(chunk);
    while (body != null) {
      final frame = decodeFrameBody(body);
      if (frame != null) {
        link.add(frame);
      }
      body = buffer.push(const []);
    }
  }
}

class _InboundGattLink implements ControlLink {
  _InboundGattLink(this.peerHandle);

  final String peerHandle;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  Future<void> Function(List<int> chunk)? notify;

  void add(Map<String, dynamic> frame) => _incoming.add(frame);

  @override
  ControlTransport get transport => ControlTransport.gatt;

  @override
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  @override
  Future<void> send(Map<String, dynamic> frame) async {
    final sendChunk = notify;
    if (sendChunk == null) {
      throw StateError('gatt notify unavailable');
    }
    final bytes = encodeFrame(frame);
    for (var offset = 0; offset < bytes.length; offset += gattChunk) {
      final end = offset + gattChunk < bytes.length
          ? offset + gattChunk
          : bytes.length;
      await sendChunk(bytes.sublist(offset, end));
    }
  }

  @override
  Future<void> close() async {}
}

class DBusBluezGatt implements BluezGatt {
  DBusClient? _client;
  DBusRemoteObjectManager? _manager;
  final _peers = GattInbound();
  _GattCharacteristic? _characteristic;
  var _exposed = false;

  @override
  void bindInbound(void Function(ControlLink link) onLink) {
    _peers.onLink = onLink;
    _peers.notify = (chunk) async {
      await _characteristic?.notify(chunk);
    };
  }

  Future<DBusClient> _bus() async {
    final existing = _client;
    if (existing != null) {
      return existing;
    }
    try {
      final client = DBusClient.system();
      _client = client;
      _manager = DBusRemoteObjectManager(
        client,
        name: 'org.bluez',
        path: DBusObjectPath('/'),
      );
      return client;
    } catch (error) {
      throw StateError('bluez bus: $error');
    }
  }

  void _ingest(List<int> chunk, String devicePath) {
    _peers.write(devicePath, chunk);
  }

  @override
  Future<void> expose() async {
    if (_exposed) {
      return;
    }
    final client = await _bus();
    final objects = await _manager!.getManagedObjects();
    DBusObjectPath? adapter;
    for (final entry in objects.entries) {
      if (entry.value.containsKey('org.bluez.GattManager1')) {
        adapter = entry.key;
        break;
      }
    }
    if (adapter == null) {
      throw StateError('bluez gatt manager missing');
    }
    final app = _GattApp();
    final service = _GattService();
    final characteristic = _GattCharacteristic(_ingest);
    _characteristic = characteristic;
    await client.registerObject(app);
    await client.registerObject(service);
    await client.registerObject(characteristic);
    final remote = DBusRemoteObject(client, name: 'org.bluez', path: adapter);
    try {
      await remote.callMethod('org.bluez.GattManager1', 'RegisterApplication', [
        app.path,
        DBusDict.stringVariant(<String, DBusValue>{}),
      ], replySignature: DBusSignature(''));
    } catch (error) {
      throw StateError('bluez gatt: $error');
    }
    _exposed = true;
  }

  @override
  Future<ControlLink> connect(String peerHandle) async {
    final client = await _bus();
    final device = DBusRemoteObject(
      client,
      name: 'org.bluez',
      path: DBusObjectPath(peerHandle),
    );
    try {
      await device.callMethod(
        'org.bluez.Device1',
        'Connect',
        const [],
        replySignature: DBusSignature(''),
      );
    } catch (error) {
      if (!error.toString().contains('AlreadyConnected')) {
        throw StateError('gatt connect: $error');
      }
    }
    await _waitServicesResolved(device, peerHandle);
    final characteristic = characteristicUnder(
      await _manager!.getManagedObjects(),
      peerHandle,
    );
    if (characteristic == null) {
      throw StateError('gatt characteristic missing');
    }
    final incoming = StreamController<Map<String, dynamic>>.broadcast();
    final buffer = FrameBuffer();
    final subscription = _manager!.signals.listen((signal) {
      if (signal is! DBusPropertiesChangedSignal ||
          signal.path.value != characteristic.value ||
          signal.propertiesInterface != 'org.bluez.GattCharacteristic1') {
        return;
      }
      final value = signal.changedProperties['Value'];
      if (value is! DBusArray) {
        return;
      }
      var body = buffer.push(value.asByteArray().toList());
      while (body != null) {
        final frame = decodeFrameBody(body);
        if (frame != null) {
          incoming.add(frame);
        }
        body = buffer.push(const []);
      }
    });
    return _DBusGattLink(
      DBusRemoteObject(client, name: 'org.bluez', path: characteristic),
      incoming.stream,
      subscription,
    );
  }

  Future<void> _waitServicesResolved(
    DBusRemoteObject device,
    String peerHandle,
  ) async {
    final ready = Completer<void>();
    final subscription = _manager!.signals.listen((signal) {
      if (ready.isCompleted ||
          signal is! DBusPropertiesChangedSignal ||
          signal.path.value != peerHandle ||
          signal.propertiesInterface != 'org.bluez.Device1') {
        return;
      }
      if (_dbusBool(signal.changedProperties['ServicesResolved'])) {
        ready.complete();
      }
    });
    try {
      final props = await device.getAllProperties('org.bluez.Device1');
      if (_dbusBool(props['ServicesResolved'])) {
        return;
      }
      await ready.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw StateError('gatt services unresolved');
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> close() async {
    await _client?.close();
    _client = null;
    _manager = null;
    _exposed = false;
  }
}

class _DBusGattLink implements ControlLink {
  _DBusGattLink(this._characteristic, this._incoming, this._subscription);

  final DBusRemoteObject _characteristic;
  final Stream<Map<String, dynamic>> _incoming;
  final StreamSubscription<DBusSignal> _subscription;

  @override
  ControlTransport get transport => ControlTransport.gatt;

  @override
  Stream<Map<String, dynamic>> get incoming => _incoming;

  @override
  Future<void> send(Map<String, dynamic> frame) async {
    final bytes = encodeFrame(frame);
    try {
      for (var offset = 0; offset < bytes.length; offset += gattChunk) {
        final end = offset + gattChunk < bytes.length
            ? offset + gattChunk
            : bytes.length;
        await _characteristic
            .callMethod('org.bluez.GattCharacteristic1', 'WriteValue', [
              DBusArray.byte(bytes.sublist(offset, end)),
              DBusDict.stringVariant(<String, DBusValue>{}),
            ], replySignature: DBusSignature(''));
      }
    } catch (error) {
      throw StateError('gatt write: $error');
    }
  }

  @override
  Future<void> close() => _subscription.cancel();
}

DBusObjectPath? characteristicUnder(
  Map<DBusObjectPath, Map<String, Map<String, DBusValue>>> objects,
  String peerHandle,
) {
  for (final entry in objects.entries) {
    final props = entry.value['org.bluez.GattCharacteristic1'];
    if (props == null) {
      continue;
    }
    final path = entry.key.value;
    if (path != peerHandle && !path.startsWith('$peerHandle/')) {
      continue;
    }
    final uuid = props['UUID']?.asString().toLowerCase();
    if (uuid == ProximityIds.gattCharacteristicUuid) {
      return entry.key;
    }
  }
  return null;
}

bool _dbusBool(DBusValue? value) => value is DBusBoolean && value.value;

List<int>? manufacturerPayload(DBusValue? value) {
  final dict = value is DBusVariant ? value.value : value;
  if (dict is! DBusDict) {
    return null;
  }
  for (final entry in dict.children.entries) {
    if (entry.key is! DBusUint16 ||
        entry.key.asUint16() != ProximityIds.manufacturerId) {
      continue;
    }
    final inner = entry.value is DBusVariant
        ? (entry.value as DBusVariant).value
        : entry.value;
    if (inner is DBusArray) {
      return inner.asByteArray().toList();
    }
  }
  return null;
}

class _BluezAdvert extends DBusObject {
  _BluezAdvert(this.manufacturer, this.nick)
    : super(DBusObjectPath('/com/brukb/blan/advert0'));

  final List<int> manufacturer;
  final List<int> nick;

  Map<String, DBusValue> get _properties => {
    'Type': const DBusString('peripheral'),
    'Discoverable': const DBusBoolean(true),
    'ManufacturerData': DBusDict(DBusSignature('q'), DBusSignature('v'), {
      DBusUint16(ProximityIds.manufacturerId): DBusVariant(
        DBusArray.byte(manufacturer),
      ),
    }),
    'ServiceData': DBusDict(DBusSignature('s'), DBusSignature('v'), {
      DBusString(ProximityIds.bleServiceUuid): DBusVariant(
        DBusArray.byte(nick),
      ),
    }),
  };

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface != 'org.bluez.LEAdvertisement1') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    return DBusGetAllPropertiesResponse(_properties);
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface != 'org.bluez.LEAdvertisement1') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final value = _properties[name];
    if (value == null) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.bluez.LEAdvertisement1' &&
        methodCall.name == 'Release') {
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

class _GattApp extends DBusObject {
  _GattApp() : super(DBusObjectPath('/com/brukb/blan'), isObjectManager: true);
}

class _GattService extends DBusObject {
  _GattService() : super(DBusObjectPath('/com/brukb/blan/service0'));

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.GattService1': {
      'UUID': const DBusString(ProximityIds.gattServiceUuid),
      'Primary': const DBusBoolean(true),
    },
  };
}

class _GattCharacteristic extends DBusObject {
  _GattCharacteristic(this._onWrite)
    : super(DBusObjectPath('/com/brukb/blan/service0/char0'));

  final void Function(List<int> chunk, String devicePath) _onWrite;

  Future<void> notify(List<int> chunk) {
    return emitPropertiesChanged(
      'org.bluez.GattCharacteristic1',
      changedProperties: {'Value': DBusArray.byte(chunk)},
    );
  }

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.GattCharacteristic1': {
      'UUID': const DBusString(ProximityIds.gattCharacteristicUuid),
      'Service': DBusObjectPath('/com/brukb/blan/service0'),
      'Flags': DBusArray(DBusSignature('s'), [
        const DBusString('write'),
        const DBusString('write-without-response'),
        const DBusString('notify'),
      ]),
    },
  };

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.bluez.GattCharacteristic1' &&
        methodCall.name == 'WriteValue') {
      _onWrite(
        methodCall.values.first.asByteArray().toList(),
        _devicePath(methodCall),
      );
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  String _devicePath(DBusMethodCall methodCall) {
    if (methodCall.values.length < 2 || methodCall.values[1] is! DBusDict) {
      return '';
    }
    final device = (methodCall.values[1] as DBusDict)
        .asStringVariantDict()['device'];
    if (device is DBusObjectPath) {
      return device.value;
    }
    return '';
  }
}
