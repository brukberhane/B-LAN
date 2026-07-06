import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

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
            subtitle: Text(
              Platform.isAndroid
                  ? 'Files save to the system Downloads folder by default.'
                  : 'Verified downloads are saved here.',
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
                          content: Text(
                            'Could not open folder on this platform',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                ),
                IconButton(
                  tooltip: 'Choose folder',
                  onPressed: () => _chooseFolder(context, ref),
                  icon: const Icon(Icons.edit_location_alt),
                ),
                IconButton(
                  tooltip: 'Reset to default',
                  onPressed: () async {
                    await app.resetDownloadsDirectory();
                    ref.invalidate(downloadsDirectoryProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Downloads location reset'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore),
                ),
              ],
            ),
          ),
          loading: () => const ListTile(title: Text('Loading…')),
          error: (error, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Could not resolve downloads folder'),
            subtitle: Text('$error'),
            trailing: IconButton(
              tooltip: 'Choose folder',
              onPressed: () => _chooseFolder(context, ref),
              icon: const Icon(Icons.edit_location_alt),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
    final app = ref.read(appServiceProvider);
    final picked = await app.pickDownloadsDirectory();
    if (picked == null) {
      return;
    }
    await app.setDownloadsDirectory(picked);
    ref.invalidate(downloadsDirectoryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloads save to $picked')));
    }
  }
}
