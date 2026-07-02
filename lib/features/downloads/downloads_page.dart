import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/protocol/download_states.dart';
import '../../core/ui/format.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final downloadRoot = ref.watch(downloadsDirectoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          downloadRoot.when(
            data: (path) => Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Save location: $path',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: downloads.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No downloads yet. Browse a peer and download files or folders.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _DownloadTile(download: rows[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.download});

  final Download download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final progress = download.totalBytes == 0
        ? null
        : download.downloadedBytes / download.totalBytes;
    final percent = progress == null ? null : (progress * 100).round();

    return FutureBuilder<({int verifiedChunks, int totalChunks, int sourceCount})>(
      future: () async {
        final stats = await db.downloadChunkStats(download.id);
        final sourceCount = await db.distinctDownloadSourceCount(download.id);
        return (
          verifiedChunks: stats.verifiedChunks,
          totalChunks: stats.totalChunks,
          sourceCount: sourceCount,
        );
      }(),
      builder: (context, snapshot) {
        final chunkLine = snapshot.hasData && snapshot.data!.totalChunks > 0
            ? 'Chunks ${snapshot.data!.verifiedChunks}/${snapshot.data!.totalChunks}'
            : null;
        final sourceLine = snapshot.hasData && snapshot.data!.sourceCount > 0
            ? 'Sources ${snapshot.data!.sourceCount}'
            : null;

        final lines = <String>[
          DownloadState.label(download.state),
          if (download.totalBytes > 0)
            '${formatBytes(download.downloadedBytes)} / ${formatBytes(download.totalBytes)}'
                '${percent == null ? '' : ' ($percent%)'}',
          if (chunkLine != null) chunkLine,
          if (sourceLine != null) sourceLine,
          if (download.errorMessage?.isNotEmpty ?? false) download.errorMessage!,
          if (download.state == DownloadState.error ||
              download.state == DownloadState.cancelled)
            'Re-download from Browse to retry',
          'Target: ${download.targetPath}',
        ];

        return ListTile(
          title: Text(download.relativePath),
          subtitle: Text(lines.join('\n')),
          isThreeLine: true,
          trailing: progress == null
              ? null
              : SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(value: progress),
                ),
        );
      },
    );
  }
}
