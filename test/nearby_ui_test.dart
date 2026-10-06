import 'dart:convert';

import 'package:blan/app/providers.dart';
import 'package:blan/app/shell.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/platform/lan_addresses.dart';
import 'package:blan/core/platform/platform_health.dart';
import 'package:blan/core/proximity/proximity_advert.dart';
import 'package:blan/core/proximity/proximity_control_frames.dart';
import 'package:blan/core/proximity/proximity_invite_queue.dart';
import 'package:blan/core/proximity/proximity_orchestrator.dart';
import 'package:blan/core/proximity/proximity_radio_fakes.dart';
import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/protocol/constants.dart';
import 'package:blan/core/security/device_identity.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/core/security/secret_store.dart';
import 'package:blan/core/services/app_service.dart';
import 'package:blan/features/peers/nearby_section.dart';
import 'package:blan/features/peers/peers_page.dart';
import 'package:blan/features/settings/nearby_settings_section.dart';
import 'package:blan/features/settings/settings_page.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shizuku settings copy', () {
    expect(shizukuSettingsCopy('dead'), 'Start it in Shevery');
    expect(shizukuSettingsCopy('notInstalled'), 'Install Shevery or Shizuku');
    expect(shizukuSettingsCopy('noPermission'), 'Needs permission');
  });

  testWidgets('nearby rows show the three badges', (tester) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble);
    final peer = _peer(host: '10.0.0.8', port: 59488);

    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['10.0.0.8'],
        child: MaterialApp(
          home: Scaffold(
            body: NearbySection(
              peers: [peer],
              subnets: const [
                Ipv4Subnet(address: '10.0.0.1', prefixLength: 24),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    ble.emit(_hit('Ada', const [10, 0, 0, 8], 59488));
    ble.emit(_hit('Bea', const [192, 168, 9, 9], 1));
    ble.emit(_hit('Cid', const [0, 0, 0, 0], 0));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Same LAN · 01020304'), findsOneWidget);
    expect(find.text('Other LAN · 01020304'), findsOneWidget);
    expect(find.text('BLE only · 01020304'), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth), findsNWidgets(3));

    await orch.setVisible(true, foreground: true);
    await orch.refreshRadio();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Ada'), findsNothing);
    expect(find.text('Bea'), findsNothing);
    expect(find.text('Cid'), findsNothing);
  });

  testWidgets('dual advert hits render as one row', (tester) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble);

    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['10.0.0.8'],
        child: MaterialApp(
          home: Scaffold(
            body: NearbySection(
              peers: const [],
              subnets: const [
                Ipv4Subnet(address: '10.0.0.1', prefixLength: 24),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final advert = ProximityAdvert(
      hasWifi: true,
      ipv4: const [10, 0, 0, 8],
      port: 59488,
      shortPeerId: const [1, 2, 3, 4],
      role: AdvertRole.none,
      groupId: const [0, 0, 0, 0],
    ).pack();
    // Same device, two advert sets: the extended hit carries the nick, the
    // legacy hit arrives later with an empty scan response.
    ble.emit(
      BleScanHit(
        advert: advert,
        scanResponse: utf8.encode('Ada'),
        peerHandle: 'AA:AA:AA:AA:AA:AA',
      ),
    );
    ble.emit(
      BleScanHit(
        advert: advert,
        scanResponse: const [],
        peerHandle: 'BB:BB:BB:BB:BB:BB',
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('same device on another local address is same LAN', (tester) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble);
    final peer = _peer(
      host: '192.168.69.45',
      port: 59488,
      id: '01020304-0000-4000-8000-000000000001',
    );

    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['192.168.69.104'],
        child: MaterialApp(
          home: Scaffold(
            body: NearbySection(
              peers: [peer],
              subnets: const [
                Ipv4Subnet(address: '192.168.69.104', prefixLength: 24),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    ble.emit(_hit('B-Yoga-7-Pro', const [192, 168, 69, 241], 59488));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('B-Yoga-7-Pro'), findsNothing);
    expect(find.text('Nearby'), findsNothing);
  });

  testWidgets('matched peer row shows wifi and bluetooth', (tester) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble);
    final peer = _peer(
      host: '192.168.69.45',
      port: 59488,
      id: '01020304-0000-4000-8000-000000000001',
      identityStatus: PeerIdentityStatus.normal,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peersProvider.overrideWith((ref) => Stream.value([peer])),
          nearbyOrchestratorProvider.overrideWithValue(orch),
          lanAddressesProvider.overrideWith((ref) async => const ['192.168.69.104']),
          lanSubnetsProvider.overrideWith(
            (ref) async => const [
              Ipv4Subnet(address: '192.168.69.104', prefixLength: 24),
            ],
          ),
        ],
        child: const MaterialApp(home: PeersPage()),
      ),
    );
    await tester.pump();
    ble.emit(_hit('B-Yoga-7-Pro', const [192, 168, 69, 241], 59488));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('B-Yoga-7-Pro'), findsNothing);
    expect(find.byIcon(Icons.wifi), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    expect(find.text('Same LAN · 01020304'), findsNothing);
  });

  testWidgets('empty peers copy hides when a nearby row is showing', (
    tester,
  ) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peersProvider.overrideWith((ref) => Stream.value(const <Peer>[])),
          nearbyOrchestratorProvider.overrideWithValue(orch),
          lanAddressesProvider.overrideWith((ref) async => const ['10.0.0.8']),
          lanSubnetsProvider.overrideWith(
            (ref) async => const [
              Ipv4Subnet(address: '10.0.0.1', prefixLength: 24),
            ],
          ),
        ],
        child: const MaterialApp(home: PeersPage()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('No peers yet'), findsOneWidget);

    ble.emit(_hit('B-Yoga-7-Pro', const [192, 168, 69, 241], 59488));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('B-Yoga-7-Pro'), findsOneWidget);
    expect(find.textContaining('No peers yet'), findsNothing);
  });

  testWidgets('mDNS menu still trusts and the rail has no nearby destination', (
    tester,
  ) async {
    final peer = _peer(host: '192.168.1.10', port: 59488);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peersProvider.overrideWith((ref) => Stream.value([peer])),
        ],
        child: const MaterialApp(home: PeersPage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Trust peer'), findsOneWidget);
  });

  testWidgets('rail has no nearby destination', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appServiceProvider.overrideWith(
            (ref) => AppService(db, platform: _NoopPlatform()),
          ),
          sharesProvider.overrideWith((ref) => Stream.value([])),
          peersProvider.overrideWith((ref) => Stream.value([])),
          downloadsProvider.overrideWith((ref) => Stream.value([])),
          uploadsProvider.overrideWith((ref) => Stream.value([])),
          downloadsDirectoryProvider.overrideWith(
            (ref) async => '/tmp/blan-downloads',
          ),
          serverRunningProvider.overrideWithValue(false),
          discoveryAdvertisingProvider.overrideWithValue(false),
          discoverySupportsAdvertisingProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();
    expect(find.text('Peers'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Nearby is blocked'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('invite sheet shows on Shares without opening Peers', (tester) async {
    final orch = _orch(FakeBlePresencePort());
    final pending = ValueNotifier<InvitePrompt?>(
      const InvitePrompt(
        nick: 'Ada',
        code: '111111',
        hostPlan: [],
        useLanMine: false,
        useLanTheirs: false,
        usePrivateNetwork: true,
      ),
    );
    addTearDown(pending.dispose);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appServiceProvider.overrideWith(
            (ref) => AppService(db, platform: _NoopPlatform()),
          ),
          nearbyOrchestratorProvider.overrideWithValue(orch),
          pendingInviteProvider.overrideWithValue(pending),
          sharesProvider.overrideWith((ref) => Stream.value([])),
          peersProvider.overrideWith((ref) => Stream.value([])),
          downloadsProvider.overrideWith((ref) => Stream.value([])),
          uploadsProvider.overrideWith((ref) => Stream.value([])),
          downloadsDirectoryProvider.overrideWith(
            (ref) async => '/tmp/blan-downloads',
          ),
          serverRunningProvider.overrideWithValue(false),
          discoveryAdvertisingProvider.overrideWithValue(false),
          discoverySupportsAdvertisingProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Shares'), findsWidgets);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('111111'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('use my lan does not join this phone', (tester) async {
    final ble = FakeBlePresencePort();
    final network = FakePrivateNetworkPort();
    final orch = _orch(ble, network: network);
    orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.desktop,
    );

    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['10.0.0.8'],
        child: MaterialApp(
          home: Scaffold(
            body: NearbySection(
              peers: const [],
              subnets: const [],
              remoteKind: ProximityDeviceKind.ios,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    ble.emit(_hit('Bea', const [192, 168, 9, 9], 9, hasWifi: true));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('Bea'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Use my LAN'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby failed'), findsOneWidget);
    expect(network.calls.where((call) => call == 'startHotspot'), isEmpty);
    expect(network.calls.where((call) => call.startsWith('join:')), isEmpty);
  });

  testWidgets('initiator sheet highlights hotspot and offers their network', (
    tester,
  ) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble);
    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['10.0.0.8'],
        child: const MaterialApp(
          home: Scaffold(body: NearbySection(peers: [], subnets: [])),
        ),
      ),
    );
    await tester.pump();
    ble.emit(_hit('Fold', const [192, 168, 1, 3], 59488));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('Fold'));
    await tester.pumpAndSettle();

    expect(find.textContaining('HostStep'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Private network'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Use their network'),
      findsOneWidget,
    );
    expect(find.textContaining('usual choice'), findsOneWidget);
  });

  testWidgets('row keeps the newest hit for a device', (tester) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble);

    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['10.0.0.8'],
        child: const MaterialApp(
          home: Scaffold(body: NearbySection(peers: [], subnets: [])),
        ),
      ),
    );
    await tester.pump();
    // Same device identity, rotated address: the newest nick-bearing hit
    // must own the row so the address is never stale.
    ble.emit(_hit('Ada', const [10, 0, 0, 8], 59488));
    ble.emit(_hit('Ada Live', const [10, 0, 0, 8], 59488));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    expect(find.text('Ada Live'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('use my lan does not confirm or join locally', (
    tester,
  ) async {
    final ble = FakeBlePresencePort();
    final network = FakePrivateNetworkPort();
    final orch = _orch(
      ble,
      network: network,
      psk: const OsWifiNetwork(
        ssid: 'Home',
        passphrase: 'pw-home',
        security: WifiSecurity.wpa2Psk,
      ),
    );
    orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.desktop,
    );

    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['10.0.0.8'],
        child: MaterialApp(
          home: Scaffold(
            body: NearbySection(
              peers: const [],
              subnets: const [],
              remoteKind: ProximityDeviceKind.ios,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    ble.emit(_hit('Bea', const [192, 168, 9, 9], 9, hasWifi: true));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('Bea'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Use my LAN'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Home'), findsNothing);
    expect(find.text('Nearby failed'), findsOneWidget);
    expect(network.calls, isNot(contains('join:Home')));
  });

  testWidgets('their network failure surfaces a dialog', (tester) async {
    final ble = FakeBlePresencePort();
    final orch = _orch(ble, control: _FailConnectControl());
    final local = await _codec();
    orch.codec = local.$1;
    orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.desktop,
    );

    await tester.pumpWidget(
      _scope(
        orch: orch,
        addresses: const ['10.0.0.8'],
        child: const MaterialApp(
          home: Scaffold(body: NearbySection(peers: [], subnets: [])),
        ),
      ),
    );
    await tester.pump();
    ble.emit(_hit('Fold', const [192, 168, 1, 3], 59488));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('Fold'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Use their network'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby failed'), findsOneWidget);
    expect(find.textContaining("Couldn't reach the device"), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('disband asks once', (tester) async {
    final ble = FakeBlePresencePort();
    final network = FakePrivateNetworkPort();
    final orch = _orch(ble, network: network);
    await orch.runHostPlan(
      local: const AttemptDevice(
        id: 'local',
        kind: ProximityDeviceKind.desktop,
      ),
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.ios),
      link: FakeControlPair.connect().a,
      session: orch.session,
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final service = AppService(db, platform: _NoopPlatform(), proximity: orch);

    await tester.pumpWidget(
      _scope(
        orch: orch,
        service: service,
        addresses: const ['10.0.0.8'],
        child: const MaterialApp(
          home: Scaffold(
            body: NearbySection(peers: [], subnets: []),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Hosting a private network'), findsOneWidget);
    await tester.tap(find.text('Disband'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(network.calls.where((call) => call == 'stopHotspot'), isEmpty);

    await tester.tap(find.text('Disband'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Disband').last);
    await tester.pumpAndSettle();
    expect(network.calls.where((call) => call == 'stopHotspot').length, 1);
  });

  testWidgets('settings show nearby visible and idle default', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appServiceProvider.overrideWith(
            (ref) => AppService(db, platform: _NoopPlatform()),
          ),
          nickProvider.overrideWith((ref) async => 'test-host'),
          httpPortProvider.overrideWith((ref) async => 59487),
          httpsPortProvider.overrideWith((ref) async => 59488),
          browserTokenProvider.overrideWith((ref) async => 'browser-token'),
          serverRunningProvider.overrideWithValue(true),
          discoveryAdvertisingProvider.overrideWithValue(true),
          deviceFingerprintProvider.overrideWith((ref) async => 'fp12345678'),
          lanAddressesProvider.overrideWith((ref) async => ['192.168.1.20']),
          platformHealthProvider.overrideWith(
            (ref) async => const PlatformHealthReport([
              PlatformHealthItem(
                label: 'HTTP server',
                level: PlatformHealthLevel.ok,
                message: 'Listening on port 59487',
              ),
            ]),
          ),
          downloadsDirectoryProvider.overrideWith(
            (ref) async => '/tmp/blan-downloads',
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      if (find.byType(NearbySettingsSection).evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    expect(find.text('Nearby visible'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Nearby visible'),
    );
    expect(tile.value, isTrue);
  });

  testWidgets('invite waiting before peers opens', (tester) async {
    final orch = _orch(FakeBlePresencePort());
    final pending = ValueNotifier<InvitePrompt?>(
      const InvitePrompt(
        nick: 'Ada',
        code: '111111',
        hostPlan: [],
        useLanMine: false,
        useLanTheirs: false,
        usePrivateNetwork: true,
      ),
    );
    addTearDown(pending.dispose);

    await tester.pumpWidget(
      _scope(
        orch: orch,
        pending: pending,
        child: const MaterialApp(
          home: Scaffold(body: NearbySection(peers: [], subnets: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('111111'), findsOneWidget);
  });

  testWidgets('decline keeps the next queued invite', (tester) async {
    final orch = _orch(FakeBlePresencePort());
    final pending = ValueNotifier<InvitePrompt?>(null);
    addTearDown(pending.dispose);
    orch.presentInvite = (prompt, {required bool foreground}) async {
      pending.value = prompt;
    };
    final local = await _codec();
    final remote = await _codec();
    orch.codec = local.$1;

    await tester.pumpWidget(
      _scope(
        orch: orch,
        pending: pending,
        child: const MaterialApp(
          home: Scaffold(body: NearbySection(peers: [], subnets: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pair = FakeControlPair.connect();
    final inbound = orch.onInbound(pair.a);
    await pair.b.send(
      await remote.$1.encode(
        ControlHelloBody(
          peerId: 'remote',
          nick: 'remote',
          publicKeyBase64: remote.$2.publicKeyBase64,
        ),
        session: remote.$3,
      ),
    );
    await tester.pump();
    Future<void> invite(String nick, String code) async {
      await pair.b.send(
        await remote.$1.encode(
          ControlInviteBody(
            nick: nick,
            code: code,
            hostPlan: const [],
            useLanMine: false,
            useLanTheirs: false,
            usePrivateNetwork: true,
          ),
          session: remote.$3,
        ),
      );
      await tester.pump();
    }

    await invite('Bea', '222222');
    await tester.pumpAndSettle();
    expect(find.text('Bea'), findsOneWidget);
    await invite('Cid', '333333');

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(find.text('Cid'), findsOneWidget);
    expect(find.text('333333'), findsOneWidget);
    expect(pending.value?.code, '333333');
    await pair.b.close();
    await inbound;
  });

  testWidgets('wifi password dialog prefills the current ssid', (tester) async {
    final orch = _orch(FakeBlePresencePort());
    orch.readCurrentSsid = () async => 'HomeNet';
    final pending = ValueNotifier<InvitePrompt?>(
      const InvitePrompt(
        nick: 'Ada',
        code: '111111',
        hostPlan: [],
        useLanMine: false,
        useLanTheirs: true,
        usePrivateNetwork: false,
      ),
    );
    addTearDown(pending.dispose);

    await tester.pumpWidget(
      _scope(
        orch: orch,
        pending: pending,
        child: const MaterialApp(
          home: Scaffold(body: NearbySection(peers: [], subnets: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Wi-Fi password'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'HomeNet',
    );
  });

  testWidgets('wifi password Join stays off until a passphrase is typed', (
    tester,
  ) async {
    final orch = _orch(FakeBlePresencePort());
    orch.readCurrentSsid = () async => 'HomeNet';
    final pending = ValueNotifier<InvitePrompt?>(
      const InvitePrompt(
        nick: 'Ada',
        code: '111111',
        hostPlan: [],
        useLanMine: false,
        useLanTheirs: true,
        usePrivateNetwork: false,
      ),
    );
    addTearDown(pending.dispose);

    await tester.pumpWidget(
      _scope(
        orch: orch,
        pending: pending,
        child: const MaterialApp(
          home: Scaffold(body: NearbySection(peers: [], subnets: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Join')).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.pump();
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Join')).onPressed,
      isNotNull,
    );
  });
}

ProximityOrchestrator _orch(
  FakeBlePresencePort ble, {
  FakePrivateNetworkPort? network,
  ControlChannelPort? control,
  OsWifiNetwork? psk,
}) {
  return ProximityOrchestrator(
    ble: ble,
    control: control ?? FakeControlChannelPort(),
    network: network ?? FakePrivateNetworkPort(),
    queue: InviteQueue(),
    codec: null,
    now: DateTime.now,
    readPersonalPsk: () async => psk,
    openLan: (_, _) async {},
  );
}

Widget _scope({
  required ProximityOrchestrator orch,
  required Widget child,
  AppService? service,
  ValueNotifier<InvitePrompt?>? pending,
  List<String> addresses = const [],
}) {
  return ProviderScope(
    overrides: [
      nearbyOrchestratorProvider.overrideWithValue(orch),
      lanAddressesProvider.overrideWith((ref) async => addresses),
      if (pending != null) pendingInviteProvider.overrideWithValue(pending),
      if (service != null)
        appServiceProvider.overrideWithValue(service),
    ],
    child: child,
  );
}

BleScanHit _hit(
  String nick,
  List<int> ipv4,
  int port, {
  bool hasWifi = false,
}) {
  return BleScanHit(
    advert: ProximityAdvert(
      hasWifi: hasWifi,
      ipv4: ipv4,
      port: port,
      shortPeerId: const [1, 2, 3, 4],
      role: AdvertRole.none,
      groupId: const [0, 0, 0, 0],
    ).pack(),
    scanResponse: utf8.encode(nick),
    peerHandle: nick,
  );
}

Peer _peer({
  required String host,
  required int port,
  String id = 'peer-1',
  String identityStatus = PeerIdentityStatus.identityChanged,
}) {
  return Peer(
    id: id,
    nick: 'remote',
    host: host,
    port: port,
    scheme: peerSchemeHttps,
    fingerprint: 'abcd1234',
    trusted: false,
    identityStatus: identityStatus,
    lastSeen: DateTime.now(),
    manual: false,
    stale: false,
  );
}

class _NoopPlatform implements PlatformServices {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> acquireMulticastLock() async => true;

  @override
  Future<void> releaseMulticastLock() async {}

  @override
  Future<void> startForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> updateForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> stopForegroundTask(String taskId) async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<String?> pickSafTreeUri() async => null;

  @override
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async => const [];

  @override
  Future<String?> defaultDeviceName() async => null;
}

Future<(ControlFrameCodec, DeviceIdentityData, ControlSession)> _codec() async {
  final identity = DeviceIdentity(InMemorySecretStore(secure: true));
  final data = await identity.ensureIdentity();
  return (ControlFrameCodec(identity), data, ControlSession());
}

class _FailConnectControl implements ControlChannelPort {
  @override
  Stream<ControlLink> get inbound => const Stream.empty();

  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    throw StateError('proximity radio failed: connectFailed');
  }

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}
}
