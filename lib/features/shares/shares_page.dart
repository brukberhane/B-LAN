import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'share_progress_card.dart';

class SharesPage extends ConsumerWidget {
  const SharesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(sharesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared folders'),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              onPressed: () => _addSafShare(context, ref),
              icon: const Icon(Icons.folder_copy_outlined),
              tooltip: 'Add SAF folder',
            ),
          IconButton(
            onPressed: () => _addFilesystemShare(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Add folder',
          ),
        ],
      ),
      body: shares.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Text(
                Platform.isAndroid
                    ? 'Add a folder via SAF or filesystem path.'
                    : 'Add a folder to share on your LAN.',
              ),
            );
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final share = rows[index];
              return ListTile(
                leading: Icon(
                  share.storageType == 'saf'
                      ? Icons.android
                      : Icons.folder,
                ),
                title: Text(share.displayName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${share.storageType} · ${share.localPath}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    ShareProgressCard(share: share),
                  ],
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(appServiceProvider).removeShare(share.id),
                ),
                onTap: () =>
                    ref.read(appServiceProvider).rescanShare(share.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _addFilesystemShare(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.getDirectoryPath();
    if (result == null) {
      return;
    }
    await ref.read(appServiceProvider).addShare(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing $result')),
      );
    }
  }

  Future<void> _addSafShare(BuildContext context, WidgetRef ref) async {
    await ref.read(appServiceProvider).addSafShare();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SAF folder added')),
      );
    }
  }
}
