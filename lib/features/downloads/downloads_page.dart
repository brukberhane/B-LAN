import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/protocol/download_states.dart';
import '../../core/transfers/download_progress.dart';
import '../../core/ui/format.dart';

enum _DownloadFilter { all, active, completed, error }

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  _DownloadFilter _filter = _DownloadFilter.all;

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);
    final groups = ref.watch(downloadGroupsProvider);
    final downloadRoot = ref.watch(downloadsDirectoryProvider);
    final app = ref.watch(appServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Clear completed',
            onPressed: () async {
              final cleared = await app.downloadQueue.clearCompleted();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      cleared == 0
                          ? 'No completed downloads to clear'
                          : 'Cleared $cleared download${cleared == 1 ? '' : 's'}',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<_DownloadFilter>(
              segments: const [
                ButtonSegment(value: _DownloadFilter.all, label: Text('All')),
                ButtonSegment(
                  value: _DownloadFilter.active,
                  label: Text('Active'),
                ),
                ButtonSegment(
                  value: _DownloadFilter.completed,
                  label: Text('Done'),
                ),
                ButtonSegment(
                  value: _DownloadFilter.error,
                  label: Text('Errors'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (value) {
                setState(() => _filter = value.first);
              },
            ),
          ),
          Expanded(
            child: downloads.when(
              data: (rows) {
                final groupRows = groups.maybeWhen(
                  data: (value) => value,
                  orElse: () => const <DownloadGroup>[],
                );
                final filtered = _filterRows(rows);
                if (filtered.isEmpty && groupRows.isEmpty) {
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
                final groupedIds =
                    filtered.map((row) => row.groupId).whereType<String>().toSet();
                final visibleGroups = groupRows
                    .where((group) => groupedIds.contains(group.id))
                    .toList();
                final ungrouped =
                    filtered.where((row) => row.groupId == null).toList();

                return ListView(
                  children: [
                    for (final group in visibleGroups)
                      _GroupTile(group: group, downloads: filtered),
                    for (final download in ungrouped)
                      _DownloadTile(download: download),
                  ],
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

  List<Download> _filterRows(List<Download> rows) {
    return switch (_filter) {
      _DownloadFilter.all => rows,
      _DownloadFilter.active => rows.where((row) {
          return row.state == DownloadState.queued ||
              row.state == DownloadState.downloading ||
              row.state == DownloadState.paused;
        }).toList(),
      _DownloadFilter.completed => rows
          .where((row) => row.state == DownloadState.complete)
          .toList(),
      _DownloadFilter.error => rows.where((row) {
          return row.state == DownloadState.error ||
              row.state == DownloadState.cancelled;
        }).toList(),
    };
  }
}

class _GroupTile extends ConsumerWidget {
  const _GroupTile({
    required this.group,
    required this.downloads,
  });

  final DownloadGroup group;
  final List<Download> downloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children =
        downloads.where((row) => row.groupId == group.id).toList();
    final displayedBytes = children.fold<int>(
      0,
      (sum, row) => sum + downloadDisplayedBytes(row),
    );
    final progress = group.totalBytes == 0
        ? null
        : displayedBytes / group.totalBytes;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text(group.label),
        subtitle: Text(
          '${DownloadState.label(group.state)} · '
          '${group.completedFiles}/${group.totalFiles} files · '
          '${formatBytes(displayedBytes)} / ${formatBytes(group.totalBytes)}',
        ),
        children: children
            .map((download) => _DownloadTile(download: download, nested: true))
            .toList(),
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({
    required this.download,
    this.nested = false,
  });

  final Download download;
  final bool nested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final queue = ref.watch(appServiceProvider).downloadQueue;
    final displayedBytes = downloadDisplayedBytes(download);
    final progress = download.totalBytes == 0
        ? null
        : displayedBytes / download.totalBytes;
    final percent = progress == null ? null : (progress * 100).round();
    final canPause = download.state == DownloadState.downloading ||
        download.state == DownloadState.queued;
    final canResume = download.state == DownloadState.paused ||
        download.state == DownloadState.error;
    final canCancel = download.state == DownloadState.queued ||
        download.state == DownloadState.downloading ||
        download.state == DownloadState.paused;
    final canRetry = download.state == DownloadState.error ||
        download.state == DownloadState.cancelled;
    final canRemove = true;

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
          if (download.paused && download.state != DownloadState.paused)
            'Paused flag set',
          if (download.totalBytes > 0)
            '${formatBytes(displayedBytes)} / ${formatBytes(download.totalBytes)}'
                '${percent == null ? '' : ' ($percent%)'}',
          if (download.inFlightBytes > 0)
            'Verified ${formatBytes(download.downloadedBytes)} · '
                'receiving ${formatBytes(download.inFlightBytes)}',
          if (chunkLine != null) chunkLine,
          if (sourceLine != null) sourceLine,
          if (download.errorMessage?.isNotEmpty ?? false) download.errorMessage!,
          'Target: ${download.targetPath}',
        ];

        return ListTile(
          contentPadding: nested
              ? const EdgeInsets.only(left: 32, right: 16)
              : const EdgeInsets.symmetric(horizontal: 16),
          title: Text(download.relativePath),
          subtitle: Text(lines.join('\n')),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(value: progress),
                ),
              PopupMenuButton<String>(
                onSelected: (action) async {
                  switch (action) {
                    case 'pause':
                      await queue.pause(download.id);
                    case 'resume':
                      await queue.resume(download.id);
                    case 'cancel':
                      await queue.cancel(download.id);
                    case 'retry':
                      await queue.retry(download.id);
                    case 'up':
                      await queue.bumpPriority(download.id, 1);
                    case 'remove':
                      final deleteFiles = download.state !=
                              DownloadState.complete &&
                          await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove download'),
                              content: Text(
                                download.state == DownloadState.complete
                                    ? 'Remove this download record?'
                                    : 'Remove record and delete partial files?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          ) ==
                          true;
                      if (deleteFiles || download.state == DownloadState.complete) {
                        await queue.remove(
                          download.id,
                          deletePartial: deleteFiles &&
                              download.state != DownloadState.complete,
                        );
                      }
                  }
                },
                itemBuilder: (context) => [
                  if (canPause)
                    const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  if (canResume)
                    const PopupMenuItem(value: 'resume', child: Text('Resume')),
                  if (canCancel)
                    const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                  if (canRetry)
                    const PopupMenuItem(value: 'retry', child: Text('Retry')),
                  if (download.state == DownloadState.queued)
                    const PopupMenuItem(
                      value: 'up',
                      child: Text('Raise priority'),
                    ),
                  if (canRemove)
                    const PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
