import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/protocol/transfer_states.dart';
import '../../core/ui/format.dart';

class UploadsPage extends ConsumerWidget {
  const UploadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploads = ref.watch(uploadsProvider);
    final peers = ref.watch(peersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Uploads')),
      body: uploads.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No uploads yet. Peers downloading from this device appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final peerMap = peers.maybeWhen(
            data: (list) => {for (final peer in list) peer.id: peer.nick},
            orElse: () => const <String, String>{},
          );
          final groups = _groupUploads(rows);
          return ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final group = groups[index];
              return _UploadGroupTile(group: group, peerMap: peerMap);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

List<_UploadGroup> _groupUploads(List<Transfer> rows) {
  final buckets = <String, List<Transfer>>{};
  for (final row in rows) {
    final key = row.entryId ?? row.chunkHash ?? 'upload-${row.id}';
    buckets.putIfAbsent(key, () => []).add(row);
  }
  final groups = buckets.entries
      .map((entry) => _UploadGroup(key: entry.key, rows: entry.value))
      .toList();
  groups.sort((a, b) {
    final aTime = a.rows
        .map((row) => row.updatedAt)
        .reduce((value, element) => value.isAfter(element) ? value : element);
    final bTime = b.rows
        .map((row) => row.updatedAt)
        .reduce((value, element) => value.isAfter(element) ? value : element);
    return bTime.compareTo(aTime);
  });
  return groups;
}

class _UploadGroup {
  const _UploadGroup({required this.key, required this.rows});

  final String key;
  final List<Transfer> rows;

  String? get entryId {
    for (final row in rows) {
      if (row.entryId != null) {
        return row.entryId;
      }
    }
    return null;
  }
}

class _UploadGroupTile extends ConsumerWidget {
  const _UploadGroupTile({required this.group, required this.peerMap});

  final _UploadGroup group;
  final Map<String, String> peerMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<_UploadGroupDetails>(
      future: _loadDetails(db, group),
      builder: (context, snapshot) {
        final details = snapshot.data;
        final total = group.rows.fold<int>(
          0,
          (sum, row) => sum + row.bytesTotal,
        );
        final sent = group.rows.fold<int>(
          0,
          (sum, row) => sum + row.bytesTransferred,
        );
        final progress = total == 0 ? null : sent / total;
        final active = group.rows
            .where((row) => row.state == TransferState.active)
            .length;
        final complete = group.rows
            .where((row) => row.state == TransferState.complete)
            .length;
        final peers =
            group.rows
                .map((row) => row.peerId == null ? null : peerMap[row.peerId])
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
        final title =
            details?.entry?.relativePath ??
            details?.entry?.name ??
            _fallbackTitle(group.rows.first);
        final chunkCount =
            details?.chunkCount ?? _chunkTransferCount(group.rows);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            leading: Icon(
              active > 0 ? Icons.upload_outlined : Icons.upload_file,
            ),
            title: Text(title),
            subtitle: Text(
              [
                if (details?.shareName != null) details!.shareName!,
                if (peers.isNotEmpty)
                  'Peer${peers.length == 1 ? '' : 's'}: ${peers.join(', ')}',
                '$complete/${group.rows.length} requests complete',
                if (chunkCount > 0) '$chunkCount chunks',
                '${formatBytes(sent)} / ${formatBytes(total)}',
              ].join(' · '),
            ),
            trailing: progress == null
                ? null
                : SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(value: progress),
                  ),
            children: [
              for (final row in group.rows)
                _UploadTile(
                  row: row,
                  peerNick: row.peerId == null ? null : peerMap[row.peerId],
                  chunkIndex: details?.chunkIndexByHash[row.chunkHash],
                  nested: true,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<_UploadGroupDetails> _loadDetails(
    AppDatabase db,
    _UploadGroup group,
  ) async {
    final entryId = group.entryId;
    Entry? entry;
    Share? share;
    List<Chunk> chunks = const [];
    if (entryId != null) {
      entry = await db.entryById(entryId);
      if (entry != null) {
        share = await (db.select(
          db.shares,
        )..where((table) => table.id.equals(entry!.shareId))).getSingleOrNull();
        chunks = await db.chunksForEntry(entryId);
      }
    }
    return _UploadGroupDetails(
      entry: entry,
      shareName: share?.displayName,
      chunkCount: chunks.length,
      chunkIndexByHash: {
        for (final chunk in chunks) chunk.hash: chunk.chunkIndex,
      },
    );
  }

  String _fallbackTitle(Transfer row) {
    if (row.entryId != null) {
      return 'File ${row.entryId}';
    }
    if (row.chunkHash != null) {
      return 'Chunk ${_shortHash(row.chunkHash!)}';
    }
    return 'Upload ${row.id}';
  }

  int _chunkTransferCount(List<Transfer> rows) =>
      rows.where((row) => row.chunkHash != null).length;
}

class _UploadGroupDetails {
  const _UploadGroupDetails({
    required this.entry,
    required this.shareName,
    required this.chunkCount,
    required this.chunkIndexByHash,
  });

  final Entry? entry;
  final String? shareName;
  final int chunkCount;
  final Map<String, int> chunkIndexByHash;
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.row,
    this.peerNick,
    this.chunkIndex,
    this.nested = false,
  });

  final Transfer row;
  final String? peerNick;
  final int? chunkIndex;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final progress = row.bytesTotal == 0
        ? null
        : row.bytesTransferred / row.bytesTotal;
    final label = row.chunkHash != null
        ? 'Chunk ${chunkIndex == null ? '' : '#$chunkIndex '}${_shortHash(row.chunkHash!)}'
        : row.entryId == null
        ? 'File request'
        : 'Range / file request';

    final lines = <String>[
      TransferState.label(row.state),
      if (peerNick != null) 'Peer: $peerNick',
      if (row.remoteAddress != null) 'Client: ${row.remoteAddress}',
      '${formatBytes(row.bytesTransferred)} / ${formatBytes(row.bytesTotal)}',
      if (row.rateBytesPerSecond > 0)
        '${formatBytes(row.rateBytesPerSecond)}/s',
      if (row.errorMessage?.isNotEmpty ?? false) row.errorMessage!,
    ];

    return ListTile(
      contentPadding: nested
          ? const EdgeInsets.only(left: 32, right: 16)
          : const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        row.state == TransferState.active
            ? Icons.upload_outlined
            : row.state == TransferState.complete
            ? Icons.check_circle_outline
            : Icons.error_outline,
      ),
      title: Text(label),
      subtitle: Text(lines.join('\n')),
      isThreeLine: true,
      trailing: progress == null
          ? null
          : SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(value: progress),
            ),
    );
  }
}

String _shortHash(String hash) =>
    hash.length > 12 ? '${hash.substring(0, 12)}…' : hash;
