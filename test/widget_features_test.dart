import 'package:blan/app/providers.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/features/downloads/downloads_page.dart';
import 'package:blan/features/peers/peers_page.dart';
import 'package:blan/features/settings/settings_page.dart';
import 'package:blan/features/shares/share_progress_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ShareProgressCard shows hashing progress', (tester) async {
    final share = Share(
      id: 'share-1',
      displayName: 'Docs',
      localPath: '/tmp/docs',
      enabled: true,
      scanStatus: 'hashing',
      storageType: 'filesystem',
      totalFiles: 10,
      hashedFiles: 4,
      totalHashBytes: 1000,
      hashedBytes: 400,
      currentFile: 'big.iso',
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShareProgressCard(share: share)),
      ),
    );

    expect(find.text('Hashing'), findsOneWidget);
    expect(find.textContaining('Files 4 / 10'), findsOneWidget);
    expect(find.textContaining('big.iso'), findsOneWidget);
  });

  testWidgets('ShareProgressCard shows ready summary', (tester) async {
    final share = Share(
      id: 'share-1',
      displayName: 'Docs',
      localPath: '/tmp/docs',
      enabled: true,
      scanStatus: 'ready',
      storageType: 'filesystem',
      totalFiles: 3,
      hashedFiles: 3,
      totalHashBytes: 2048,
      hashedBytes: 2048,
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShareProgressCard(share: share)),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.textContaining('3 files indexed'), findsOneWidget);
  });

  testWidgets('PeersPage shows identity changed badge', (tester) async {
    final peer = Peer(
      id: 'peer-1',
      nick: 'remote',
      host: '192.168.1.10',
      port: 59487,
      fingerprint: 'abcd1234',
      trusted: false,
      identityStatus: PeerIdentityStatus.identityChanged,
      lastSeen: DateTime.now(),
      manual: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peersProvider.overrideWith((ref) => Stream.value([peer])),
        ],
        child: const MaterialApp(home: PeersPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Identity changed'), findsOneWidget);
    expect(find.text('remote'), findsOneWidget);
  });

  testWidgets('SettingsPage shows browser token actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nickProvider.overrideWith((ref) async => 'test-host'),
          httpPortProvider.overrideWith((ref) async => 59487),
          browserTokenProvider.overrideWith((ref) async => 'browser-token'),
          serverRunningProvider.overrideWithValue(true),
          discoveryAdvertisingProvider.overrideWithValue(true),
          deviceFingerprintProvider.overrideWith((ref) async => 'fp12345678'),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browser token'), findsOneWidget);
    expect(find.text('browser-token'), findsOneWidget);
    expect(find.byTooltip('Copy token'), findsOneWidget);
    expect(find.byTooltip('Rotate token'), findsOneWidget);
    expect(find.byTooltip('Revoke token'), findsOneWidget);
  });

  testWidgets('DownloadsPage empty state mentions browse', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          downloadsProvider.overrideWith((ref) => Stream.value([])),
          downloadsDirectoryProvider.overrideWith(
            (ref) async => '/tmp/blan-downloads',
          ),
        ],
        child: const MaterialApp(home: DownloadsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Browse a peer and download'),
      findsOneWidget,
    );
  });
}
