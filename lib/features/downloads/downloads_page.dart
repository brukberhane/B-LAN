import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: downloads.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No downloads yet.'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final download = rows[index];
              final progress = download.totalBytes == 0
                  ? null
                  : download.downloadedBytes / download.totalBytes;
              return ListTile(
                title: Text(download.relativePath),
                subtitle: Text(download.state),
                trailing: progress == null
                    ? null
                    : SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(value: progress),
                      ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
