import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/persistence/database.dart';
import '../core/security/device_identity.dart';
import '../core/services/app_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Database not initialized');
});

final appServiceProvider = Provider<AppService>((ref) {
  final db = ref.watch(databaseProvider);
  return AppService(db);
});

final sharesProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchShares();
});

final peersProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchPeers();
});

final downloadsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDownloads();
});

final downloadGroupsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDownloadGroups();
});

final uploadsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchUploads();
});

final browserTokenProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.ensureBrowserToken();
});

final httpPortProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.ensureHttpPort();
});

final nickProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.ensureNick();
});

final serverRunningProvider = Provider<bool>(
  (ref) => ref.watch(appServiceProvider).server.isRunning,
);

final discoveryAdvertisingProvider = Provider<bool>(
  (ref) => ref.watch(appServiceProvider).discovery.isAdvertising,
);

final discoverySupportsAdvertisingProvider = Provider<bool>(
  (ref) => ref.watch(appServiceProvider).discovery.supportsAdvertising,
);

final downloadsDirectoryProvider = FutureProvider<String>((ref) async {
  return ref.watch(appServiceProvider).downloadsDirectory();
});

final deviceFingerprintProvider = FutureProvider<String>((ref) async {
  final identity =
      await DeviceIdentity(ref.watch(databaseProvider)).ensureIdentity();
  return identity.fingerprint;
});
