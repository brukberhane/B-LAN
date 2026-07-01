import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../browse/browse_page.dart';
import '../../core/persistence/database.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          nick.when(
            data: (value) => ListTile(
              title: const Text('Nickname'),
              subtitle: Text(value),
            ),
            loading: () => const ListTile(title: Text('Nickname')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          port.when(
            data: (value) => ListTile(
              title: const Text('HTTP port'),
              subtitle: Text('$value'),
            ),
            loading: () => const ListTile(title: Text('HTTP port')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          token.when(
            data: (value) => ListTile(
              title: const Text('Browser token'),
              subtitle: Text(value),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token copied')),
                  );
                },
              ),
            ),
            loading: () => const ListTile(title: Text('Browser token')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (kIsWeb) ...[
            const Divider(),
            const Text(
              'Web client mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
