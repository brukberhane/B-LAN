import 'package:flutter/material.dart';

import '../../core/persistence/database.dart';

class ShareProgressCard extends StatelessWidget {
  const ShareProgressCard({super.key, required this.share});

  final Share share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusChip(status: share.scanStatus),
        const SizedBox(height: 8),
        if (share.scanStatus == 'scanning') ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(
            'Scanning folder…',
            style: theme.textTheme.bodySmall,
          ),
        ] else if (share.scanStatus == 'updating') ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(
            share.currentFile == null || share.currentFile!.isEmpty
                ? 'Updating index…'
                : 'Updating ${share.currentFile!}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ] else if (share.scanStatus == 'hashing') ...[
          _buildHashProgress(theme),
        ] else if (share.scanStatus == 'ready') ...[
          Text(
            '${share.totalFiles} files indexed · ${_formatBytes(share.totalHashBytes)}',
            style: theme.textTheme.bodySmall,
          ),
        ] else if (share.scanStatus == 'error') ...[
          Text(
            'Indexing failed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHashProgress(ThemeData theme) {
    final fileFraction = share.totalFiles == 0
        ? null
        : share.hashedFiles / share.totalFiles;
    final byteFraction = share.totalHashBytes == 0
        ? null
        : share.hashedBytes / share.totalHashBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: byteFraction),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: fileFraction,
          color: theme.colorScheme.secondary,
          backgroundColor: theme.colorScheme.secondaryContainer,
        ),
        const SizedBox(height: 6),
        Text(
          'Files ${share.hashedFiles} / ${share.totalFiles} · '
          '${_formatBytes(share.hashedBytes)} / ${_formatBytes(share.totalHashBytes)}',
          style: theme.textTheme.bodySmall,
        ),
        if (share.currentFile != null && share.currentFile!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            share.currentFile!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'scanning' => ('Scanning', Colors.orange),
      'updating' => ('Updating', Colors.blue),
      'hashing' => ('Hashing', Colors.blue),
      'ready' => ('Ready', Colors.green),
      'error' => ('Error', Colors.red),
      _ => ('Idle', Colors.grey),
    };

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontSize: 12),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
