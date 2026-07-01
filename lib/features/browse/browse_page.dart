import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/protocol/models.dart';

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
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
          _error = 'Session failed: $error';
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
        title: Text(widget.peer.nick),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
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
            leading: const Icon(Icons.folder_shared),
            title: Text(share.name),
            subtitle: Text(
              '${share.entryCount} files · ${_formatBytes(share.totalBytes)}',
            ),
            onTap: () {
              setState(() => _selectedShare = share);
              _loadEntries();
            },
          );
        },
      );
    }

    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return ListTile(
          leading: Icon(
            entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
          ),
          title: Text(entry.name),
          subtitle: entry.isDirectory ? null : Text(_formatBytes(entry.size)),
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
                  onPressed: () => _download(entry),
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
