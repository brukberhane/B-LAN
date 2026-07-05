import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/platform/platform_health.dart';

class PlatformTroubleshootingSection extends ConsumerWidget {
  const PlatformTroubleshootingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(platformHealthProvider);
    final app = ref.watch(appServiceProvider);

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
          Platform.isAndroid
              ? 'LAN sharing keeps running in the background while the '
                  'persistent notification is shown. Use Stop sharing or '
                  'swipe the app away from recents to turn it off.'
              : 'Closing the app stops the HTTP server and LAN advertising.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (Platform.isAndroid) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: app.sharingActive,
            builder: (context, active, _) {
              if (active) {
                return OutlinedButton.icon(
                  onPressed: () async {
                    await app.shutdownSharing();
                    ref.invalidate(platformHealthProvider);
                  },
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop sharing'),
                );
              }
              return FilledButton.icon(
                onPressed: () async {
                  await app.restartSharing();
                  ref.invalidate(platformHealthProvider);
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Start sharing'),
              );
            },
          ),
        ],
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
      leading: Icon(
        _iconFor(item.level),
        color: _colorFor(context, item.level),
      ),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
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
