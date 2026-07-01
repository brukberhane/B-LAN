import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/protocol/models.dart';
import '../../core/protocol/path_safety.dart';
import '../../core/security/peer_identity.dart';
import '../../core/ui/format.dart';

class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({
    super.key,
    required this.peer,
    this.token,
  });

  final Peer peer;
  final String? token;

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  List<ShareSummary> _shares = const [];
  ShareSummary? _selectedShare;
  List<EntryDto> _entries = const [];
  String _path = '';
  var _loading = true;
  String? _error;
  String? _authToken;
  String? _downloadRoot;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _downloadRoot = await ref.read(appServiceProvider).downloadsDirectory();
    _authToken = widget.token;
    if (_authToken == null) {
      try {
        _authToken =
            await ref.read(appServiceProvider).ensurePeerSession(widget.peer);
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = 'Session/auth failed: $error';
          _loading = false;
        });
        return;
      }
    }
    await _loadShares();
  }

  Future<void> _loadShares() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(appServiceProvider).client;
      final baseUrl = 'http://${widget.peer.host}:${widget.peer.port}';
      final shares = await client.listShares(baseUrl, token: _authToken);
      if (!mounted) {
        return;
      }
      setState(() {
        _shares = shares;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _loadEntries({String? path}) async {
    final share = _selectedShare;
    if (share == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _path = path ?? '';
    });
    try {
      final client = ref.read(appServiceProvider).client;
      final baseUrl = 'http://${widget.peer.host}:${widget.peer.port}';
      final entries = await client.listEntries(
        baseUrl,
        shareId: share.id,
        path: _path,
        token: _authToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peer.nick),
            if (_selectedShare != null)
              Text(
                _selectedShare!.name,
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
        leading: _selectedShare == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_path.isNotEmpty) {
                    final parts = _path.split('/');
                    parts.removeLast();
                    _loadEntries(path: parts.join('/'));
                  } else {
                    setState(() {
                      _selectedShare = null;
                      _entries = const [];
                    });
                  }
                },
              ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedShare != null) _BreadcrumbBar(path: _path),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_selectedShare == null) {
      if (_shares.isEmpty) {
        return const Center(child: Text('Peer has no shared folders.'));
      }
      return ListView.separated(
        itemCount: _shares.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final share = _shares[index];
          return ListTile(
            leading: Icon(
              share.enabled ? Icons.folder_shared : Icons.folder_off_outlined,
            ),
            title: Text(share.name),
            subtitle: Text(
              share.enabled
                  ? '${share.entryCount} files · ${formatBytes(share.totalBytes)} · ${share.scanStatus}'
                  : 'Share disabled on remote peer',
            ),
            enabled: share.enabled,
            onTap: share.enabled
                ? () {
                    setState(() => _selectedShare = share);
                    _loadEntries();
                  }
                : null,
          );
        },
      );
    }

    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final canDownload = entry.isDirectory || entry.hashReady;
        return ListTile(
          leading: Icon(
            entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
          ),
          title: Text(entry.name),
          subtitle: entry.isDirectory
              ? null
              : Text(
                  entry.hashReady
                      ? formatBytes(entry.size)
                      : '${formatBytes(entry.size)} · indexing on peer',
                ),
          trailing: entry.isDirectory
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'Download folder',
                      onPressed: () => _download(entry),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: entry.hashReady
                      ? 'Download file'
                      : 'File not ready to download',
                  onPressed: canDownload ? () => _download(entry) : null,
                ),
          onTap: entry.isDirectory ? () => _loadEntries(path: entry.path) : null,
        );
      },
    );
  }

  Future<void> _download(EntryDto entry) async {
    final share = _selectedShare;
    if (share == null) {
      return;
    }
    if (!entry.isDirectory && !entry.hashReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remote peer is still indexing this file'),
        ),
      );
      return;
    }

    final downloadRoot = _downloadRoot;
    if (downloadRoot == null) {
      return;
    }

    String targetPath;
    try {
      targetPath = localTargetPath(
        downloadRoot,
        normalizeRemoteEntryPath(entry.path),
      );
    } on PathSafetyException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unsafe path: $error')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.isDirectory ? 'Download folder?' : 'Download file?'),
        content: Text(
          'Save to:\n$targetPath\n\n'
          'Download runs now and blocks until finished.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    if (!await _ensureDownloadAllowed()) {
      return;
    }

    try {
      final count = await ref.read(appServiceProvider).queueDownload(
            peer: widget.peer,
            shareId: share.id,
            entry: entry,
            token: _authToken,
          );
      if (mounted) {
        final message = entry.isDirectory
            ? count == 0
                ? 'Saved empty folder ${entry.name}'
                : 'Saved $count file${count == 1 ? '' : 's'} from ${entry.name}'
            : 'Saved ${entry.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $error')),
        );
      }
    }
  }

  Future<bool> _ensureDownloadAllowed() async {
    final fresh =
        await ref.read(databaseProvider).peerById(widget.peer.id) ?? widget.peer;

    if (fresh.identityStatus == PeerIdentityStatus.identityChanged) {
      final trust = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Peer identity changed'),
          content: Text(
            '${fresh.nick} fingerprint changed. Trust again before downloading.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trust peer'),
            ),
          ],
        ),
      );
      if (trust == true) {
        await ref.read(appServiceProvider).trustPeer(fresh.id);
        return true;
      }
      return false;
    }

    if (fresh.trusted) {
      return true;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Untrusted peer'),
        content: Text(
          '${fresh.nick} is not trusted. Download once or trust this peer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'once'),
            child: const Text('Download once'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'trust'),
            child: const Text('Trust'),
          ),
        ],
      ),
    );
    if (choice == 'trust') {
      await ref.read(appServiceProvider).trustPeer(fresh.id);
      return true;
    }
    return choice == 'once';
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = path.isEmpty ? '/' : '/${path.replaceAll('\\', '/')}';

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(label, style: theme.textTheme.bodySmall),
      ),
    );
  }
}
