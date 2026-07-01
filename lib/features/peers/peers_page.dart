import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/ui/format.dart';
import '../browse/browse_page.dart';

class PeersPage extends ConsumerWidget {
  const PeersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peers'),
        actions: [
          IconButton(
            onPressed: () => _showManualPeerDialog(context, ref),
            icon: const Icon(Icons.add_link),
            tooltip: 'Connect manually',
          ),
        ],
      ),
      body: peers.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _emptyPeersMessage(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final peer = rows[index];
              return ListTile(
                leading: Icon(
                  peer.manual ? Icons.link : Icons.wifi,
                ),
                title: Text(peer.nick),
                subtitle: Text(_peerSubtitle(peer)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (peer.trusted)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.verified_user, size: 18),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove peer',
                      onPressed: () => _confirmRemovePeer(context, ref, peer),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openPeer(context, peer),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _emptyPeersMessage() {
    final base =
        'No peers yet. Add one manually or wait for LAN discovery.';
    if (PlatformCapabilities.supportsMdnsAdvertising) {
      return base;
    }
    final notes = PlatformCapabilities.limitationNotes();
    if (notes.isEmpty) {
      return base;
    }
    return '$base\n\n${notes.first}';
  }

  String _peerSubtitle(Peer peer) {
    final parts = <String>[
      '${peer.host}:${peer.port}',
      peer.manual ? 'Manual' : 'Discovered',
      'seen ${formatRelativeTime(peer.lastSeen)}',
    ];
    if (peer.fingerprint != null && peer.fingerprint!.isNotEmpty) {
      parts.add('fp ${peer.fingerprint!.substring(0, 8)}…');
    }
    return parts.join(' · ');
  }

  Future<void> _showManualPeerDialog(BuildContext context, WidgetRef ref) async {
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '59487');
    final nickController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to peer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostController,
              decoration: const InputDecoration(labelText: 'Host / IP'),
            ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: nickController,
              decoration: const InputDecoration(labelText: 'Nickname (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final port = int.tryParse(portController.text.trim()) ?? 59487;
    try {
      await ref.read(appServiceProvider).addManualPeer(
            hostController.text.trim(),
            port,
            nick: nickController.text.trim().isEmpty
                ? null
                : nickController.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peer connected')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session/auth failed: $error')),
        );
      }
    }
  }

  void _openPeer(BuildContext context, Peer peer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrowsePage(peer: peer),
      ),
    );
  }

  Future<void> _confirmRemovePeer(
    BuildContext context,
    WidgetRef ref,
    Peer peer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove peer?'),
        content: Text('Remove ${peer.nick} (${peer.host}:${peer.port})?'),
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
    if (confirmed != true) {
      return;
    }
    await ref.read(appServiceProvider).removePeer(peer.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${peer.nick}')),
      );
    }
  }
}
