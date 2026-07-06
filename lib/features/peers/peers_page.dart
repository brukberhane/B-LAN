import 'package:blan/core/protocol/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/platform/lan_addresses.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/security/peer_identity.dart';
import '../../core/ui/format.dart';
import '../browse/browse_page.dart';

class PeersPage extends ConsumerWidget {
  const PeersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peersProvider);
    final filterEnabled = ref.watch(peerSubnetFilterProvider).valueOrNull ?? true;
    final localSubnets =
        ref.watch(lanSubnetsProvider).valueOrNull ?? const <Ipv4Subnet>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peers'),
        actions: [
          IconButton(
            onPressed: () => _refreshLanDiscovery(context, ref),
            icon: const Icon(Icons.wifi_find),
            tooltip: 'Refresh LAN discovery',
          ),
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
                  _emptyPeersMessage(filterEnabled: filterEnabled),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: [
              if (!filterEnabled)
                _SubnetFilterOffBanner(subnets: localSubnets),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final peer = rows[index];
                    final warning =
                        PeerIdentityStatus.isWarning(peer.identityStatus);
                    final offSubnet = !filterEnabled &&
                        !hostSharesLocalSubnet(peer.host, localSubnets);
                    return ListTile(
                      leading: Icon(
                        peer.identityStatus ==
                                PeerIdentityStatus.identityChanged
                            ? Icons.warning_amber
                            : peer.identityStatus ==
                                    PeerIdentityStatus.suspicious
                                ? Icons.gpp_bad_outlined
                                : peer.manual
                                    ? Icons.link
                                    : Icons.wifi,
                        color: warning ? Colors.orange : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(peer.nick)),
                          if (offSubnet)
                            const Chip(
                              label: Text('Off-subnet'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          if (peer.identityStatus ==
                              PeerIdentityStatus.identityChanged)
                            const Chip(
                              label: Text('Identity changed'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          if (peer.identityStatus ==
                              PeerIdentityStatus.suspicious)
                            const Chip(
                              label: Text('Suspicious'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          if (peer.stale)
                            const Chip(
                              label: Text('Stale'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                      subtitle: Text(
                        _peerSubtitle(
                          peer,
                          filterEnabled: filterEnabled,
                          localSubnets: localSubnets,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (peer.trusted)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.verified_user, size: 18),
                            ),
                          PopupMenuButton<_PeerAction>(
                            onSelected: (action) async {
                              final service = ref.read(appServiceProvider);
                              switch (action) {
                                case _PeerAction.trust:
                                  await service.trustPeer(peer.id);
                                case _PeerAction.forgetTrust:
                                  await service.forgetPeerTrust(peer.id);
                                case _PeerAction.reauthenticate:
                                  await service.reauthenticatePeer(peer.id);
                                case _PeerAction.revokeSessions:
                                  await service.revokePeerSessions(peer.id);
                                case _PeerAction.remove:
                                  await _confirmRemovePeer(context, ref, peer);
                              }
                            },
                            itemBuilder: (context) => [
                              if (!peer.trusted)
                                const PopupMenuItem(
                                  value: _PeerAction.trust,
                                  child: Text('Trust peer'),
                                ),
                              if (peer.trusted)
                                const PopupMenuItem(
                                  value: _PeerAction.forgetTrust,
                                  child: Text('Forget trust'),
                                ),
                              const PopupMenuItem(
                                value: _PeerAction.reauthenticate,
                                child: Text('Re-authenticate'),
                              ),
                              const PopupMenuItem(
                                value: _PeerAction.revokeSessions,
                                child: Text('Revoke sessions'),
                              ),
                              const PopupMenuItem(
                                value: _PeerAction.remove,
                                child: Text('Remove'),
                              ),
                            ],
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _openPeer(context, peer),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _emptyPeersMessage({required bool filterEnabled}) {
    final base =
        'No peers yet. Add one manually (+) or wait for LAN discovery.';
    final hints = <String>[
      if (filterEnabled)
        'Peers on other subnets are hidden — disable in Settings → LAN peer filter.',
      if (!PlatformCapabilities.supportsMdnsAdvertising)
        ...PlatformCapabilities.limitationNotes(),
      'Check Settings → Network health if discovery fails.',
    ];
    if (hints.isEmpty) {
      return base;
    }
    return '$base\n\n${hints.join('\n\n')}';
  }

  String _peerSubtitle(
    Peer peer, {
    required bool filterEnabled,
    required List<Ipv4Subnet> localSubnets,
  }) {
    final parts = <String>[
      '${peer.host}:${peer.port}',
      peer.scheme,
      peer.manual ? 'Manual' : 'Discovered',
      if (peer.stale) 'stale',
      'seen ${formatRelativeTime(peer.lastSeen)}',
    ];
    if (!filterEnabled) {
      parts.add(describePeerSubnetMatch(peer.host, localSubnets));
    }
    if (peer.tlsCertFingerprint != null && peer.tlsCertFingerprint!.isNotEmpty) {
      parts.add('TLS ${peer.tlsCertFingerprint!.substring(0, 8)}…');
    }
    if (peer.fingerprint != null && peer.fingerprint!.isNotEmpty) {
      parts.add('fp ${peer.fingerprint!.substring(0, 8)}…');
    }
    return parts.join(' · ');
  }

  Future<void> _showManualPeerDialog(BuildContext context, WidgetRef ref) async {
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '59488');
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
              decoration: const InputDecoration(
                labelText: 'Peer HTTPS port',
                helperText: 'Default 59488 — not browser HTTP (59487)',
              ),
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

    final port =
        int.tryParse(portController.text.trim()) ?? defaultPeerHttpsPort;
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

  Future<void> _refreshLanDiscovery(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appServiceProvider).refreshLanDiscovery();
      ref.invalidate(lanAddressesProvider);
      ref.invalidate(lanSubnetsProvider);
      ref.invalidate(peerSubnetFilterProvider);
      ref.invalidate(peersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LAN advertise and scan refreshed')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $error')),
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

enum _PeerAction {
  trust,
  forgetTrust,
  reauthenticate,
  revokeSessions,
  remove,
}

class _SubnetFilterOffBanner extends StatelessWidget {
  const _SubnetFilterOffBanner({required this.subnets});

  final List<Ipv4Subnet> subnets;

  @override
  Widget build(BuildContext context) {
    final localLabel = subnets.isEmpty
        ? 'none detected'
        : subnets.map(formatIpv4Subnet).join(', ');
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          'Subnet filter off — showing all peers. Local subnets: $localLabel. '
          'Re-enable in Settings → LAN peer filter.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
