import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/platform/platform_capabilities.dart';
import 'security_settings_section.dart';
import 'platform_sections.dart';
import '../browse/browse_page.dart';
import '../../core/persistence/database.dart';
import '../../core/protocol/constants.dart';
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
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Change nickname',
                onPressed: () => _editNickname(context, value),
              ),
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
            data: (value) {
              final lan = ref.watch(lanAddressesProvider);
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Browser HTTP port'),
                    subtitle: Text('$value (loopback browser API)'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy localhost URL',
                          onPressed: () => _copyText(
                            context,
                            ref.read(appServiceProvider).localBrowserUrl(value),
                            'Localhost URL copied',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.lan),
                          tooltip: 'Copy LAN URL',
                          onPressed: () async {
                            final url = await ref
                                .read(appServiceProvider)
                                .primaryLanBrowserUrl(value);
                            if (!context.mounted) {
                              return;
                            }
                            if (url == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No LAN address found'),
                                ),
                              );
                              return;
                            }
                            _copyText(context, url, 'LAN URL copied');
                          },
                        ),
                      ],
                    ),
                  ),
                  lan.when(
                    data: (addresses) => addresses.isEmpty
                        ? const ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            subtitle: Text('No LAN IPv4 address detected'),
                          )
                        : ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('LAN addresses'),
                            subtitle: Text(addresses.join(', ')),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              );
            },
            loading: () => const ListTile(title: Text('Browser HTTP port')),
            error: (_, _) => const SizedBox.shrink(),
          ),
          ListTile(
            title: const Text('Service status'),
            subtitle: Text(
              [
                serverRunning ? 'Transfer servers running' : 'Transfer servers stopped',
                if (!kIsWeb)
                  advertising
                      ? 'Advertising on LAN'
                      : 'Not advertising on LAN',
              ].join(' · '),
            ),
          ),
          ref.watch(httpsPortProvider).when(
            data: (value) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Peer HTTPS port'),
              subtitle: Text('$value (mDNS + peer transfers)'),
            ),
            loading: () => const ListTile(title: Text('Peer HTTPS port')),
            error: (_, _) => const SizedBox.shrink(),
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
            const SecuritySettingsSection(),
          ],
          if (!kIsWeb) ...[
            const Divider(height: 32),
            const DownloadsLocationSection(),
            const Divider(height: 32),
            const PlatformTroubleshootingSection(),
          ],
          if (!kIsWeb) ...[
            const Divider(height: 32),
            const _TransferLimitsSection(),
          ],
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

  Future<void> _editNickname(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change nickname'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            hintText: 'Shown to peers on the LAN',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || saved == null || saved.isEmpty || saved == current) {
      return;
    }
    try {
      await ref.read(appServiceProvider).setNick(saved);
      ref.invalidate(nickProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nickname updated to $saved')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update nickname: $error')),
      );
    }
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
      scheme: peerSchemeHttp,
      fingerprint: null,
      tlsCertFingerprint: null,
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

class _TransferLimitsSection extends ConsumerStatefulWidget {
  const _TransferLimitsSection();

  @override
  ConsumerState<_TransferLimitsSection> createState() =>
      _TransferLimitsSectionState();
}

class _TransferLimitsSectionState extends ConsumerState<_TransferLimitsSection> {
  var _loaded = false;
  double _maxUploadChunks = 4;
  double _maxDownloadChunks = 3;
  double _uploadBandwidthMbps = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final uploadChunks = await db.maxUploadChunks();
    final downloadChunks = await db.maxDownloadChunks();
    final bps = await db.uploadBandwidthBps();
    if (!mounted) {
      return;
    }
    setState(() {
      _maxUploadChunks = uploadChunks.toDouble();
      _maxDownloadChunks = downloadChunks.toDouble();
      _uploadBandwidthMbps = bps / (1024 * 1024);
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.setMaxUploadChunks(_maxUploadChunks.round());
    await db.setMaxDownloadChunks(_maxDownloadChunks.round());
    final bps = (_uploadBandwidthMbps * 1024 * 1024).round();
    await db.setUploadBandwidthBps(bps);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer limits saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Transfer limits',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Upload concurrency caps simultaneous outgoing chunk/file responses. '
          'Bandwidth cap 0 = unlimited.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ListTile(
          title: Text('Max upload slots: ${_maxUploadChunks.round()}'),
          subtitle: Slider(
            value: _maxUploadChunks,
            min: 1,
            max: 16,
            divisions: 15,
            label: '${_maxUploadChunks.round()}',
            onChanged: (value) => setState(() => _maxUploadChunks = value),
            onChangeEnd: (_) => _save(),
          ),
        ),
        ListTile(
          title: Text('Max download chunks: ${_maxDownloadChunks.round()}'),
          subtitle: Slider(
            value: _maxDownloadChunks,
            min: 1,
            max: 16,
            divisions: 15,
            label: '${_maxDownloadChunks.round()}',
            onChanged: (value) => setState(() => _maxDownloadChunks = value),
            onChangeEnd: (_) => _save(),
          ),
        ),
        ListTile(
          title: Text(
            _uploadBandwidthMbps <= 0
                ? 'Upload bandwidth cap: unlimited'
                : 'Upload bandwidth cap: ${_uploadBandwidthMbps.toStringAsFixed(1)} MB/s',
          ),
          subtitle: Slider(
            value: _uploadBandwidthMbps,
            min: 0,
            max: 100,
            divisions: 20,
            label: _uploadBandwidthMbps <= 0
                ? '0'
                : _uploadBandwidthMbps.toStringAsFixed(1),
            onChanged: (value) => setState(() => _uploadBandwidthMbps = value),
            onChangeEnd: (_) => _save(),
          ),
        ),
      ],
    );
  }
}
