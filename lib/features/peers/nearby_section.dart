import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../../core/platform/lan_addresses.dart';
import '../../core/proximity/proximity_advert.dart';
import '../../core/proximity/proximity_orchestrator.dart';
import '../../core/proximity/proximity_policy.dart';
import '../../core/proximity/proximity_radios.dart';
import '../../core/security/remembered_wifi.dart';

class NearbySection extends ConsumerStatefulWidget {
  const NearbySection({
    super.key,
    required this.peers,
    required this.subnets,
    this.remoteKind = ProximityDeviceKind.android,
  });

  final List<Peer> peers;
  final List<Ipv4Subnet> subnets;
  final ProximityDeviceKind remoteKind;

  @override
  ConsumerState<NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends ConsumerState<NearbySection> {
  final _hits = <String, BleScanHit>{};
  StreamSubscription<BleScanHit>? _scans;
  ProximityOrchestrator? _orch;
  ValueNotifier<InvitePrompt?>? _pending;
  var _showingInvite = false;

  @override
  void dispose() {
    _scans?.cancel();
    _pending?.removeListener(_onPending);
    super.dispose();
  }

  void _watch(ProximityOrchestrator? orch) {
    if (!identical(orch, _orch)) {
      _scans?.cancel();
      _orch = orch;
      _scans = orch?.ble.scans.listen((hit) {
        if (!mounted) {
          return;
        }
        setState(() => _hits[hit.peerHandle] = hit);
      });
    }
    final pending = ref.read(pendingInviteProvider);
    if (!identical(pending, _pending)) {
      _pending?.removeListener(_onPending);
      _pending = pending;
      _pending?.addListener(_onPending);
      _onPending();
    }
  }

  void _onPending() {
    final prompt = ref.read(pendingInviteProvider)?.value;
    final orch = _orch;
    if (prompt == null || orch == null || _showingInvite || !mounted) {
      return;
    }
    _showingInvite = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showingInvite = false;
        return;
      }
      await _showTarget(context, orch, prompt);
      _showingInvite = false;
      if (mounted) {
        _onPending();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _paint() {
    if (mounted) {
      setState(() {});
    }
  }

  void _takePrompt(InvitePrompt prompt) {
    final pending = ref.read(pendingInviteProvider);
    if (pending != null && identical(pending.value, prompt)) {
      pending.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orch = ref.watch(nearbyOrchestratorProvider);
    _watch(orch);
    if (orch == null) {
      return const SizedBox.shrink();
    }
    final addresses = ref.watch(lanAddressesProvider).valueOrNull ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (orch.advertError != null)
          MaterialBanner(
            content: Text('Nearby is blocked\n${orch.advertError}'),
            actions: const [SizedBox.shrink()],
          ),
        if (orch.isPrivateNetworkUp)
          ListTile(
            title: const Text('Hosting a private network'),
            trailing: TextButton(
              onPressed: () => _confirmDisband(context),
              child: const Text('Disband'),
            ),
          ),
        if (_hits.isNotEmpty) const ListTile(title: Text('Nearby')),
        for (final hit in _hits.values)
          _row(context, orch, hit, addresses.isNotEmpty),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ProximityOrchestrator orch,
    BleScanHit hit,
    bool localHasWifi,
  ) {
    final advert = ProximityAdvert.unpack(hit.advert);
    final host = advert.ipv4.join('.');
    final hello = widget.peers.any(
      (peer) => peer.host == host && peer.port == advert.port,
    );
    final badge = orch.badgeForHit(
      hit,
      onLocalSubnet: hostSharesLocalSubnet(host, widget.subnets),
      helloSucceeded: hello,
    );
    final nick = hit.scanResponse.isEmpty
        ? 'Nearby'
        : utf8.decode(hit.scanResponse, allowMalformed: true);
    return ListTile(
      title: Text(nick),
      subtitle: Text(_badgeLabel(badge)),
      onTap: () => _onTap(context, orch, hit, advert, badge, localHasWifi),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    ProximityOrchestrator orch,
    BleScanHit hit,
    ProximityAdvert advert,
    ProximityBadge badge,
    bool localHasWifi,
  ) async {
    final grouped =
        (advert.role == AdvertRole.owner || advert.role == AdvertRole.member) &&
        advert.groupId.any((byte) => byte != 0);
    if (grouped) {
      await orch.onScan(hit);
      return;
    }
    final trusted = widget.peers.any(
      (peer) =>
          peer.trusted == true &&
          _sameShort(peer.id, advert.shortPeerId),
    );
    final action = orch.actionFor(
      TapFacts(
        trusted: trusted,
        badge: badge,
        localHasWifi: localHasWifi,
        remoteHasWifi: advert.hasWifi,
      ),
    );
    final remote = AttemptDevice(id: hit.peerHandle, kind: widget.remoteKind);
    switch (action) {
      case TapAction.openLan:
        await orch.openSameLan(host: advert.ipv4.join('.'), port: advert.port);
      case TapAction.skipSheetStartHostChain:
        await orch.startPrivateAttempt(remote: remote, peerHandle: hit.peerHandle);
        _paint();
      case TapAction.showSheetWithCode:
      case TapAction.showSheetWithoutCode:
        if (!context.mounted) {
          return;
        }
        await _showLinkSheet(
          context,
          orch,
          hit,
          advert,
          remote,
          sheetOptions(
            TapFacts(
              trusted: trusted,
              badge: badge,
              localHasWifi: localHasWifi,
              remoteHasWifi: advert.hasWifi,
            ),
          ),
        );
    }
  }

  Future<void> _showLinkSheet(
    BuildContext context,
    ProximityOrchestrator orch,
    BleScanHit hit,
    ProximityAdvert advert,
    AttemptDevice remote,
    LinkSheetOptions options,
  ) async {
    final local = orch.localDevice;
    final code = options.showShortCode ? mintSixDigitCode(Random()) : null;
    final steps = local == null
        ? const <HostStep>[]
        : hostChain(local: local, remote: remote);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(code == null ? 'Link' : 'Code $code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final step in steps) Text(step.toString()),
            if (options.showUseLanMine) const Text('Use my LAN'),
            if (options.showUseLanTheirs) const Text('Use their LAN'),
            if (options.showPrivateNetwork) const Text('Private network'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await orch.abort(UserAbort.sheetCancel);
            },
            child: const Text('Cancel'),
          ),
          if (code != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await orch.abort(UserAbort.codeDecline);
              },
              child: const Text('Decline'),
            ),
          if (options.showUseLanMine)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _useMyLan(context, orch, remote, hit.peerHandle);
              },
              child: const Text('Use my LAN'),
            ),
          if (options.showPrivateNetwork)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await orch.startPrivateAttempt(
                  remote: remote,
                  peerHandle: hit.peerHandle,
                );
                _paint();
              },
              child: const Text('Private network'),
            ),
        ],
      ),
    );
  }

  Future<void> _useMyLan(
    BuildContext context,
    ProximityOrchestrator orch,
    AttemptDevice remote,
    String peerHandle,
  ) async {
    final known = await _readPsk(orch);
    if (known != null) {
      await orch.network.join(
        ssid: known.ssid,
        passphrase: known.passphrase,
        security: known.security,
        localOnly: false,
      );
      _paint();
      return;
    }
    if (!context.mounted) {
      return;
    }
    final remembered = await _askPassword(context);
    if (remembered == null) {
      await orch.abort(UserAbort.sheetCancel);
      return;
    }
    if (remembered.skip) {
      await orch.skipPassword(remote: remote, peerHandle: peerHandle);
      _paint();
      return;
    }
    final service = ref.read(appServiceProvider);
    await service.rememberWifi(
      ssid: remembered.ssid,
      security: remembered.security,
      passphrase: remembered.passphrase,
      remember: remembered.remember,
    );
    await orch.network.join(
      ssid: remembered.ssid,
      passphrase: remembered.passphrase,
      security: remembered.security,
      localOnly: false,
    );
    _paint();
  }

  Future<OsWifiNetwork?> _readPsk(ProximityOrchestrator orch) async {
    try {
      return await orch.readPersonalPsk();
    } catch (_) {
      return null;
    }
  }

  Future<_PasswordEntry?> _askPassword(BuildContext context) {
    return showDialog<_PasswordEntry>(
      context: context,
      builder: (context) => const _WifiPasswordDialog(),
    );
  }

  Future<void> _confirmDisband(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disband'),
        content: const Text('Stop the private network?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disband'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appServiceProvider).disbandNearby();
      _paint();
    }
  }

  Future<void> _showTarget(
    BuildContext context,
    ProximityOrchestrator orch,
    InvitePrompt prompt,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(prompt.nick),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prompt.code),
            for (final step in prompt.hostPlan) Text(step.toString()),
            if (prompt.useLanMine) const Text('Use my LAN'),
            if (prompt.useLanTheirs) const Text('Use their LAN'),
            if (prompt.usePrivateNetwork) const Text('Private network'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _takePrompt(prompt);
              await orch.applyInviteResult('decline');
            },
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _takePrompt(prompt);
              await orch.applyInviteResult('accept');
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

String _badgeLabel(ProximityBadge badge) {
  return switch (badge) {
    ProximityBadge.sameLan => 'Same LAN',
    ProximityBadge.otherLan => 'Other LAN',
    ProximityBadge.bleOnly => 'BLE only',
  };
}

bool _sameShort(String peerId, List<int> shortId) {
  final mine = shortPeerIdFromUuid(peerId);
  if (mine.length != shortId.length) {
    return false;
  }
  for (var i = 0; i < mine.length; i++) {
    if (mine[i] != shortId[i]) {
      return false;
    }
  }
  return true;
}

class _PasswordEntry {
  const _PasswordEntry({
    required this.ssid,
    required this.passphrase,
    required this.security,
    required this.remember,
  }) : skip = false;

  const _PasswordEntry.skip()
    : skip = true,
      ssid = '',
      passphrase = '',
      security = WifiSecurity.wpa2Psk,
      remember = false;

  final bool skip;
  final String ssid;
  final String passphrase;
  final WifiSecurity security;
  final bool remember;
}

class _WifiPasswordDialog extends StatefulWidget {
  const _WifiPasswordDialog();

  @override
  State<_WifiPasswordDialog> createState() => _WifiPasswordDialogState();
}

class _WifiPasswordDialogState extends State<_WifiPasswordDialog> {
  final _ssid = TextEditingController();
  final _passphrase = TextEditingController();
  var _remember = false;
  var _security = WifiSecurity.wpa2Psk;

  @override
  void dispose() {
    _ssid.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wi-Fi password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ssid,
            decoration: const InputDecoration(labelText: 'SSID'),
          ),
          TextField(
            controller: _passphrase,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          DropdownButton<WifiSecurity>(
            value: _security,
            items: const [
              DropdownMenuItem(
                value: WifiSecurity.wpa2Psk,
                child: Text('WPA2'),
              ),
              DropdownMenuItem(
                value: WifiSecurity.wpa3Sae,
                child: Text('WPA3'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _security = value);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remember'),
            value: _remember,
            onChanged: (value) => setState(() => _remember = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _PasswordEntry.skip(),
          ),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _PasswordEntry(
              ssid: _ssid.text.trim(),
              passphrase: _passphrase.text,
              security: _security,
              remember: _remember,
            ),
          ),
          child: const Text('Join'),
        ),
      ],
    );
  }
}
