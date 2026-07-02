import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/protocol/models.dart';
import '../../core/ui/format.dart';
import '../shares/search_index_banner.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  var _type = 'all';
  var _loading = false;
  String? _error;
  List<SearchResultDto> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(appServiceProvider).searchService.search(
            query: query,
            type: _type,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
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

  Future<void> _download(SearchResultDto result) async {
    if (result.isDirectory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder download: use Browse for now')),
      );
      return;
    }
    if (!result.hashReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remote peer is still indexing this file')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final peer = await db.peerById(result.peerId);
    if (peer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peer not found')),
        );
      }
      return;
    }

    final app = ref.read(appServiceProvider);
    String? token;
    try {
      token = await app.ensurePeerSession(peer);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session failed: $error')),
        );
      }
      return;
    }

    try {
      await app.searchService.preloadManifestForDownload(
        result: result,
        token: token,
      );
      final entry = EntryDto(
        id: result.entryId,
        name: result.name,
        path: result.path,
        isDirectory: result.isDirectory,
        size: result.size,
        mtimeMs: result.mtimeMs,
        hashReady: result.hashReady,
      );
      await app.queueDownload(
        peer: peer,
        shareId: result.shareId,
        entry: entry,
        token: token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Queued ${result.name}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Search LAN',
                      hintText: 'filename or path fragment',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _loading ? null : _runSearch,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'file', label: Text('Files')),
                ButtonSegment(value: 'directory', label: Text('Folders')),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          const SearchIndexProgressBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Searching peers...'),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: Text('Search across local shares and online peers.'));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        final canDownload = !result.isDirectory && result.hashReady;
        return ListTile(
          leading: Icon(
            result.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
          ),
          title: Text(result.name),
          subtitle: Text(
            '${result.peerNick} · ${result.shareName}\n'
            '${result.path.isEmpty ? '/' : result.path} · ${formatBytes(result.size)}'
            '${result.sourceCount > 1 ? ' · ${result.sourceCount} sources' : ''}'
            '${result.stale ? ' · stale' : ''}',
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.trusted)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.verified_user_outlined, size: 18),
                ),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Download',
                onPressed: canDownload ? () => _download(result) : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
