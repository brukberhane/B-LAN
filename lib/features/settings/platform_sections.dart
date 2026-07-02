import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/platform/platform_health.dart';

class PlatformTroubleshootingSection extends ConsumerWidget {
  const PlatformTroubleshootingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(platformHealthProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Network health',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(platformHealthProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Closing the app stops the HTTP server and LAN advertising.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        health.when(
          data: (report) => Column(
            children: [
              for (final item in report.items) _HealthTile(item: item),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (error, _) => Text('Health check failed: $error'),
        ),
      ],
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({required this.item});

  final PlatformHealthItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(item.level), color: _colorFor(context, item.level)),
      title: Text(item.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.message),
          if (item.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.hint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(PlatformHealthLevel level) => switch (level) {
        PlatformHealthLevel.ok => Icons.check_circle,
        PlatformHealthLevel.warning => Icons.warning_amber,
        PlatformHealthLevel.error => Icons.error_outline,
        PlatformHealthLevel.info => Icons.info_outline,
      };

  Color? _colorFor(BuildContext context, PlatformHealthLevel level) =>
      switch (level) {
        PlatformHealthLevel.ok => Colors.green,
        PlatformHealthLevel.warning => Colors.orange,
        PlatformHealthLevel.error => Theme.of(context).colorScheme.error,
        PlatformHealthLevel.info => null,
      };
}

class DownloadsLocationSection extends ConsumerWidget {
  const DownloadsLocationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final downloadRoot = ref.watch(downloadsDirectoryProvider);
    final app = ref.watch(appServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Downloads location',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        downloadRoot.when(
          data: (path) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(path),
            subtitle: const Text(
              'Verified downloads are saved here. Android defaults to app storage.',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Open folder',
                  onPressed: () async {
                    final opened = await app.openPathInFileManager(path);
                    if (context.mounted && !opened) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open folder on this platform'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                ),
                IconButton(
                  tooltip: 'Choose folder',
                  onPressed: () async {
                    final picked = await FilePicker.getDirectoryPath();
                    if (picked == null) {
                      return;
                    }
                    await app.setDownloadsDirectory(picked);
                    ref.invalidate(downloadsDirectoryProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloads save to $picked')),
                      );
                    }
                  },
                  icon: const Icon(Icons.edit_location_alt),
                ),
              ],
            ),
          ),
          loading: () => const ListTile(title: Text('Loading…')),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
