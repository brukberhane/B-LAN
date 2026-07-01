import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../protocol/constants.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Settings,
    Shares,
    Entries,
    Chunks,
    Peers,
    RemoteEntriesCache,
    Downloads,
    DownloadChunks,
    Transfers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(shares, shares.storageType);
            await migrator.addColumn(entries, entries.localUri);
          }
          if (from < 3) {
            await migrator.addColumn(shares, shares.totalFiles);
            await migrator.addColumn(shares, shares.hashedFiles);
            await migrator.addColumn(shares, shares.totalHashBytes);
            await migrator.addColumn(shares, shares.hashedBytes);
            await migrator.addColumn(shares, shares.currentFile);
          }
        },
      );

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'blan.db');
    return AppDatabase(
      driftDatabase(name: dbPath),
    );
  }

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final row =
        await (select(settings)..where((t) => t.key.equals(key)))
            .getSingleOrNull();
    return row?.value ?? defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final updated = await (update(settings)..where((t) => t.key.equals(key)))
        .write(SettingsCompanion(value: Value(value)));
    if (updated == 0) {
      await into(settings).insert(SettingsCompanion.insert(key: key, value: value));
    }
  }

  Future<void> deleteSetting(String key) async {
    await (delete(settings)..where((t) => t.key.equals(key))).go();
  }

  Future<String> ensurePeerId() async {
    var peerId = await getSetting('peer_id');
    if (peerId.isEmpty) {
      peerId = const Uuid().v4();
      await setSetting('peer_id', peerId);
    }
    return peerId;
  }

  Future<String> ensureNick() async {
    var nick = await getSetting('nick');
    if (nick.isEmpty) {
      nick = Platform.localHostname;
      await setSetting('nick', nick);
    }
    return nick;
  }

  Future<int> ensureHttpPort() async {
    final raw = await getSetting('http_port');
    if (raw.isEmpty) {
      await setSetting('http_port', '$defaultHttpPort');
      return defaultHttpPort;
    }
    return int.tryParse(raw) ?? defaultHttpPort;
  }

  Future<String> ensureBrowserToken() async {
    var token = await getSetting('browser_token');
    if (token.isEmpty) {
      token = const Uuid().v4();
      await setSetting('browser_token', token);
    }
    return token;
  }

  Stream<List<Share>> watchShares() =>
      (select(shares)..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .watch();

  Stream<List<Peer>> watchPeers() => (select(peers)
        ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)]))
      .watch();

  Stream<List<Download>> watchDownloads() => (select(downloads)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<List<Entry>> entriesForShare(String shareId, String parentPath) {
    final normalized = _normalizeBrowsePath(parentPath);
    return (select(entries)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.like('$normalized%'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get()
        .then(_filterDirectChildren(normalized));
  }

  Future<ShareSummaryData> shareSummary(String shareId) async {
    final share = await (select(shares)..where((t) => t.id.equals(shareId)))
        .getSingleOrNull();
    if (share == null) {
      throw StateError('Share not found: $shareId');
    }
    final rows = await (select(entries)
          ..where(
            (t) => t.shareId.equals(shareId) & t.isDirectory.equals(false),
          ))
        .get();
    final totalBytes =
        rows.fold<int>(0, (sum, row) => sum + row.size);
    return ShareSummaryData(
      share: share,
      entryCount: rows.length,
      totalBytes: totalBytes,
    );
  }

  Future<void> updateShareProgress(
    String shareId, {
    String? scanStatus,
    int? totalFiles,
    int? hashedFiles,
    int? totalHashBytes,
    int? hashedBytes,
    String? currentFile,
    bool clearCurrentFile = false,
  }) async {
    await (update(shares)..where((t) => t.id.equals(shareId))).write(
      SharesCompanion(
        scanStatus:
            scanStatus == null ? const Value.absent() : Value(scanStatus),
        totalFiles:
            totalFiles == null ? const Value.absent() : Value(totalFiles),
        hashedFiles:
            hashedFiles == null ? const Value.absent() : Value(hashedFiles),
        totalHashBytes: totalHashBytes == null
            ? const Value.absent()
            : Value(totalHashBytes),
        hashedBytes:
            hashedBytes == null ? const Value.absent() : Value(hashedBytes),
        currentFile: clearCurrentFile
            ? const Value(null)
            : currentFile == null
                ? const Value.absent()
                : Value(currentFile),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementShareHashProgress(
    String shareId, {
    required int fileSize,
  }) async {
    await customUpdate(
      'UPDATE shares SET hashed_files = hashed_files + 1, '
      'hashed_bytes = hashed_bytes + ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable<int>(fileSize),
        Variable<DateTime>(DateTime.now()),
        Variable<String>(shareId),
      ],
      updates: {shares},
    );
  }

  Future<void> clearShareIndex(String shareId) async {
    final entryRows = await (select(entries)
          ..where((t) => t.shareId.equals(shareId)))
        .get();
    for (final entry in entryRows) {
      await (delete(chunks)..where((t) => t.entryId.equals(entry.id))).go();
    }
    await (delete(entries)..where((t) => t.shareId.equals(shareId))).go();
  }

  String _normalizeBrowsePath(String path) {
    if (path.isEmpty || path == '/') {
      return '';
    }
    var normalized = path.replaceAll('\\', '/');
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  List<Entry> Function(List<Entry>) _filterDirectChildren(String parentPath) {
    return (rows) {
      final prefixLength = parentPath.length;
      return rows.where((row) {
        if (row.isDirectory && row.relativePath == parentPath) {
          return false;
        }
        final remainder = row.relativePath.substring(prefixLength);
        final slashIndex = remainder.indexOf('/');
        if (row.isDirectory) {
          return slashIndex == remainder.length - 1;
        }
        return !remainder.contains('/');
      }).toList();
    };
  }
}

class ShareSummaryData {
  const ShareSummaryData({
    required this.share,
    required this.entryCount,
    required this.totalBytes,
  });

  final Share share;
  final int entryCount;
  final int totalBytes;
}
