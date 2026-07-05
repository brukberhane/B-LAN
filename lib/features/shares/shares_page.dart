import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/app_service.dart';
import '../../core/persistence/database.dart';
import '../../core/platform/platform_capabilities.dart';
import 'share_progress_card.dart';
import 'search_index_banner.dart';

class SharesPage extends ConsumerWidget {
  const SharesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(sharesProvider);
    final serverRunning = ref.watch(serverRunningProvider);
    final advertising = ref.watch(discoveryAdvertisingProvider);
    final supportsAdvertising = ref.watch(discoverySupportsAdvertisingProvider);

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServiceStatusBanner(
            serverRunning: serverRunning,
            advertising: advertising,
            supportsAdvertising: supportsAdvertising,
          ),
          const SearchIndexProgressBanner(),
          Expanded(
            child: shares.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        Platform.isAndroid
                            ? 'Add a folder via SAF or filesystem path.'
                            : 'Add a folder to share on your LAN.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final share = rows[index];
                    return _ShareTile(share: share);
                  },
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

  Future<void> _addFilesystemShare(BuildContext context, WidgetRef ref) async {
    // FilePicker returns a translated path without persistable SAF permission.
    if (Platform.isAndroid) {
      await _addSafShare(context, ref);
      return;
    }
    final result = await FilePicker.getDirectoryPath();
    if (result == null) {
      return;
    }
    await ref.read(appServiceProvider).addShare(result);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sharing $result')));
    }
  }

  Future<void> _addSafShare(BuildContext context, WidgetRef ref) async {
    final service = ref.read(appServiceProvider);
    final uri = await service.pickSafTree();
    if (!context.mounted || uri == null) {
      return;
    }
    final defaultName = AppService.safDisplayNameFromPath(uri);
    final name = await _promptShareName(
      context,
      title: 'Name SAF folder',
      initialName: defaultName,
    );
    if (!context.mounted || name == null) {
      return;
    }
    await service.addSafShareFromUri(uri, displayName: name);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sharing $name')));
    }
  }
}

Future<String?> _promptShareName(
  BuildContext context, {
  required String title,
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _ShareNameDialog(title: title, initialName: initialName),
  );
}

class _ShareNameDialog extends StatefulWidget {
  const _ShareNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_ShareNameDialog> createState() => _ShareNameDialogState();
}

class _ShareNameDialogState extends State<_ShareNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Display name',
          hintText: 'Shown to peers on the LAN',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ServiceStatusBanner extends StatelessWidget {
  const _ServiceStatusBanner({
    required this.serverRunning,
    required this.advertising,
    required this.supportsAdvertising,
  });

  final bool serverRunning;
  final bool advertising;
  final bool supportsAdvertising;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[
      serverRunning ? 'HTTP server running' : 'HTTP server stopped',
      if (supportsAdvertising)
        advertising ? 'Advertising on LAN' : 'Not advertising on LAN'
      else
        'LAN advertise not supported on ${PlatformCapabilities.platformName}',
    ];

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(lines.join(' · '), style: theme.textTheme.bodySmall),
      ),
    );
  }
}

class _ShareTile extends ConsumerWidget {
  const _ShareTile({required this.share});

  final Share share;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(appServiceProvider);
    final isServed = share.enabled && share.scanStatus == 'ready';

    return ValueListenableBuilder<SearchIndexState>(
      valueListenable: service.searchIndexStatus,
      builder: (context, searchIndexState, _) {
        return ListTile(
          leading: Icon(
            share.storageType == 'saf' ? Icons.android : Icons.folder,
            color: share.enabled ? null : Theme.of(context).disabledColor,
          ),
          title: Row(
            children: [
              Expanded(child: Text(share.displayName)),
              if (!share.enabled)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Chip(
                    label: Text('Disabled'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_storageLabel(share.storageType)} · ${share.localPath}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                isServed
                    ? 'Discoverable when peers can reach this device'
                    : 'Not served until indexing completes and share is enabled',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ShareProgressCard(
                share: share,
                searchIndexState: searchIndexState,
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (share.storageType != 'saf')
                IconButton(
                  tooltip: 'Open share folder',
                  onPressed: () async {
                    final opened = await service.openPathInFileManager(
                      share.localPath,
                    );
                    if (context.mounted && !opened) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open folder')),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                ),
              Switch(
                value: share.enabled,
                onChanged: (value) => service.setShareEnabled(share.id, value),
              ),
              PopupMenuButton<_ShareAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _ShareAction.rename:
                      final renamed = await _promptShareName(
                        context,
                        title: 'Rename share',
                        initialName: share.displayName,
                      );
                      if (!context.mounted || renamed == null) {
                        return;
                      }
                      await service.renameShare(share.id, renamed);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Renamed to $renamed')),
                        );
                      }
                    case _ShareAction.rescan:
                      await service.rescanShare(share.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rescanning ${share.displayName}'),
                          ),
                        );
                      }
                    case _ShareAction.remove:
                      final confirmed = await _confirmRemove(context, share);
                      if (confirmed == true) {
                        await service.removeShare(share.id);
                      }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ShareAction.rename,
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: _ShareAction.rescan,
                    child: Text('Rescan'),
                  ),
                  PopupMenuItem(
                    value: _ShareAction.remove,
                    child: Text('Remove'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _storageLabel(String storageType) =>
      storageType == 'saf' ? 'SAF' : 'Filesystem';

  Future<bool?> _confirmRemove(BuildContext context, Share share) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove share?'),
        content: Text(
          'Stop sharing ${share.displayName} and clear its local index?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

enum _ShareAction { rename, rescan, remove }
