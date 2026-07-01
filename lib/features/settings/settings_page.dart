import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/platform/platform_capabilities.dart';
import '../browse/browse_page.dart';
import '../../core/persistence/database.dart';
import '../../core/security/peer_identity.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _webHostController = TextEditingController();
  final _webPortController = TextEditingController(text: '59487');
  final _webTokenController = TextEditingController();

  @override
  void dispose() {
    _webHostController.dispose();
    _webPortController.dispose();
    _webTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nick = ref.watch(nickProvider);
    final port = ref.watch(httpPortProvider);
    final token = ref.watch(browserTokenProvider);
    final serverRunning = ref.watch(serverRunningProvider);
    final advertising = ref.watch(discoveryAdvertisingProvider);
    final fingerprint = ref.watch(deviceFingerprintProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'This device',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          nick.when(
            data: (value) => ListTile(
              title: const Text('Nickname'),
              subtitle: Text(value),
            ),
            loading: () => const ListTile(title: Text('Nickname')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          fingerprint.when(
            data: (value) => ListTile(
              title: const Text('Device fingerprint'),
              subtitle: Text(value),
            ),
            loading: () => const ListTile(title: Text('Device fingerprint')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          port.when(
            data: (value) => ListTile(
              title: const Text('HTTP port'),
              subtitle: Text('$value'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy local URL',
                onPressed: () => _copyText(
                  context,
                  ref.read(appServiceProvider).localPeerUrl(value),
                  'Local URL copied',
                ),
              ),
            ),
            loading: () => const ListTile(title: Text('HTTP port')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          ListTile(
            title: const Text('Service status'),
            subtitle: Text(
              [
                serverRunning ? 'HTTP server running' : 'HTTP server stopped',
                if (!kIsWeb)
                  advertising
                      ? 'Advertising on LAN'
                      : 'Not advertising on LAN',
              ].join(' · '),
            ),
          ),
          token.when(
            data: (value) => ListTile(
              title: const Text('Browser token'),
              subtitle: Text(value),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy token',
                    onPressed: () => _copyText(context, value, 'Token copied'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Rotate token',
                    onPressed: () async {
                      final newToken = await ref
                          .read(appServiceProvider)
                          .rotateBrowserToken();
                      ref.invalidate(browserTokenProvider);
                      if (context.mounted) {
                        _copyText(context, newToken, 'New token copied');
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.block),
                    tooltip: 'Revoke token',
                    onPressed: () async {
                      final newToken = await ref
                          .read(appServiceProvider)
                          .revokeBrowserToken();
                      ref.invalidate(browserTokenProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Browser token revoked; old tokens rejected',
                            ),
                          ),
                        );
                        _copyText(context, newToken, 'New token copied');
                      }
                    },
                  ),
                ],
              ),
            ),
            loading: () => const ListTile(title: Text('Browser token')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (!kIsWeb) ...[
            const Divider(height: 32),
            Text(
              'Web client instructions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            port.when(
              data: (value) => token.when(
                data: (tokenValue) => Text(
                  'On another machine, open B-LAN Web or use a browser with '
                  'this peer\'s LAN IP, port $value, and browser token. '
                  'CORS allows all origins by default for LAN use.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
          const Divider(height: 32),
          Text(
            'Platform capabilities',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            PlatformCapabilities.platformName,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          ...PlatformCapabilities.capabilityRows().map(
            (row) => ListTile(
              dense: true,
              leading: Icon(
                row.available ? Icons.check_circle : Icons.cancel,
                color: row.available ? Colors.green : Colors.grey,
              ),
              title: Text(row.label),
              subtitle: row.note == null ? null : Text(row.note!),
            ),
          ),
          if (PlatformCapabilities.limitationNotes().isNotEmpty) ...[
            const SizedBox(height: 8),
            ...PlatformCapabilities.limitationNotes().map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(note, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ],
          if (!kIsWeb &&
              (Platform.isLinux ||
                  Platform.isWindows ||
                  Platform.isMacOS)) ...[
            const Divider(height: 32),
            Text(
              'Firewall / manual connect',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            port.when(
              data: (value) => Text(
                PlatformCapabilities.firewallGuidance(value),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
          if (kIsWeb) ...[
            const Divider(height: 32),
            Text(
              'Web client mode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Web cannot share folders or discover peers. Connect manually to '
              'a desktop peer below.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _webHostController,
              decoration: const InputDecoration(
                labelText: 'Desktop peer host',
                hintText: '192.168.1.10',
              ),
            ),
            TextField(
              controller: _webPortController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _webTokenController,
              decoration: const InputDecoration(
                labelText: 'Browser token from desktop peer',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _connectWebPeer,
              child: const Text('Connect'),
            ),
          ],
        ],
      ),
    );
  }

  void _copyText(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _connectWebPeer() async {
    final host = _webHostController.text.trim();
    final port = int.tryParse(_webPortController.text.trim()) ?? 59487;
    final token = _webTokenController.text.trim();
    if (host.isEmpty || token.isEmpty) {
      return;
    }

    final peer = Peer(
      id: '$host:$port',
      nick: host,
      host: host,
      port: port,
      fingerprint: null,
      trusted: false,
      identityStatus: PeerIdentityStatus.normal,
      lastSeen: DateTime.now(),
      manual: true,
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrowsePage(peer: peer, token: token),
      ),
    );
  }
}
