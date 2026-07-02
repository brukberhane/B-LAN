import 'package:blan/app/providers.dart';
import 'package:blan/app/shell.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/services/app_service.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App shell renders navigation', (tester) async {
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
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Uploads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
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
}
