import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/database.dart';
import '../browse/browse_page.dart';
import '../../core/platform/lan_addresses.dart';
import '../../core/proximity/proximity_advert.dart';
import '../../core/proximity/proximity_orchestrator.dart';
import '../../core/proximity/proximity_policy.dart';
import '../../core/proximity/proximity_radios.dart';
import '../../core/security/lan_psk_acquire.dart';
import '../../core/security/remembered_wifi.dart';
import '../../platform/android/android_proximity_radios.dart';
import '../settings/nearby_settings_section.dart';

class NearbySection extends ConsumerStatefulWidget {
  const NearbySection({
    super.key,
    required this.peers,
    required this.subnets,
    this.remoteKind = ProximityDeviceKind.android,
    this.onAdvert,
  });

  final List<Peer> peers;
  final List<Ipv4Subnet> subnets;
  final ProximityDeviceKind remoteKind;

  /// Fresh BLE address. The peers page uses it to drop a trusted row that
  /// left the subnet. Tests omit it.
  final void Function(ProximityAdvert advert)? onAdvert;

  @override
  ConsumerState<NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends ConsumerState<NearbySection> {
  final _hits = <String, BleScanHit>{};
  StreamSubscription<BleScanHit>? _scans;
  StreamSubscription<void>? _resets;
  ProximityOrchestrator? _orch;
  ValueNotifier<InvitePrompt?>? _pending;
  ValueNotifier<InvitePrompt?>? _pendingLanPassword;
  StateController<Set<String>>? _lanIds;
  StateController<int>? _hitCount;
  Set<String> _published = const {};
  final _notedAdvert = <String>{};
  var _publishedCount = 0;
  var _showingInvite = false;
  var _showingPsk = false;

  @override
  void dispose() {
    _scans?.cancel();
    _resets?.cancel();
    _pending?.removeListener(_onPending);
    _pendingLanPassword?.removeListener(_onPendingLanPassword);
    if (_lanIds != null && _lanIds!.state.isNotEmpty) {
      _lanIds!.state = const {};
    }
    if (_hitCount != null && _hitCount!.state != 0) {
      _hitCount!.state = 0;
    }
    super.dispose();
  }

  void _watch(ProximityOrchestrator? orch) {
    if (!identical(orch, _orch)) {
      _scans?.cancel();
      _resets?.cancel();
      _orch = orch;
      _scans = orch?.ble.scans.listen((hit) {
        if (!mounted) {
          return;
        }
        setState(() => _hits[hit.peerHandle] = hit);
        _noteAdvert(hit);
      });
      _resets = orch?.scanResets.listen((_) {
        if (!mounted) {
          return;
        }
        _notedAdvert.clear();
        setState(_hits.clear);
      });
    }
    _lanIds ??= ref.read(nearbyLanPeerIdsProvider.notifier);
    _hitCount ??= ref.read(nearbyHitCountProvider.notifier);
    final pending = ref.read(pendingInviteProvider);
    if (!identical(pending, _pending)) {
      _pending?.removeListener(_onPending);
      _pending = pending;
      _pending?.addListener(_onPending);
      _onPending();
    }
    final lanPassword = ref.read(pendingLanPasswordProvider);
    if (!identical(lanPassword, _pendingLanPassword)) {
      _pendingLanPassword?.removeListener(_onPendingLanPassword);
      _pendingLanPassword = lanPassword;
      _pendingLanPassword?.addListener(_onPendingLanPassword);
      _onPendingLanPassword();
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

  void _takeLanPassword(InvitePrompt prompt) {
    final pending = ref.read(pendingLanPasswordProvider);
    if (pending != null && identical(pending.value, prompt)) {
      pending.value = null;
    }
  }

  void _onPendingLanPassword() {
    final prompt = ref.read(pendingLanPasswordProvider)?.value;
    final orch = _orch;
    if (prompt == null || orch == null || _showingPsk || !mounted) {
      return;
    }
    _showingPsk = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showingPsk = false;
        return;
      }
      final outcome = await _acquireLanPsk(context, orch, verb: 'Share');
      _takeLanPassword(prompt);
      if (outcome.network != null) {
        orch.stageLanOffer(outcome.network!);
        await orch.applyInviteResult('accept');
      } else {
        await orch.applyInviteResult('decline');
      }
      _showingPsk = false;
      if (mounted) {
        _onPendingLanPassword();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final orch = ref.watch(nearbyOrchestratorProvider);
    _watch(orch);
    if (orch == null) {
      return const SizedBox.shrink();
    }
    final visible = _dedupe(
      _hits.values.where((hit) => _peerForHit(hit) == null),
    ).toList();
    _scheduleMatches();
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
        if (visible.isNotEmpty) const ListTile(title: Text('Nearby')),
        for (final hit in visible)
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
    final reached = _reachedOnLan(advert, host);
    final badge = orch.badgeForHit(
      hit,
      onLocalSubnet: reached,
      helloSucceeded: reached,
    );
    final shortId = _shortLabel(advert.shortPeerId);
    final nick = hit.scanResponse.isEmpty
        ? shortId
        : utf8.decode(hit.scanResponse, allowMalformed: true);
    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: Text(nick),
      subtitle: Text('${_badgeLabel(badge)} · $shortId'),
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
      try {
        await orch.onScan(hit);
      } catch (_) {
        _showAttemptError(_reachCopy);
      }
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
        remoteHasWifi: advert.hasWifi || advert.ipv4.any((byte) => byte != 0),
      ),
    );
    final remote = AttemptDevice(id: hit.peerHandle, kind: widget.remoteKind);
    switch (action) {
      case TapAction.openLan:
        final peer = _peerForHit(hit) ?? _peerAtAdvert(advert);
        if (peer != null) {
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BrowsePage(peer: peer)),
          );
          return;
        }
        try {
          await orch.openSameLan(host: advert.ipv4.join('.'), port: advert.port);
        } catch (_) {
          _showAttemptError(_reachCopy);
        }
      case TapAction.skipSheetStartHostChain:
        try {
          await orch.startPrivateAttempt(remote: remote, peerHandle: hit.peerHandle);
        } catch (_) {
          _showAttemptError(_reachCopy);
        }
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
              remoteHasWifi:
                  advert.hasWifi || advert.ipv4.any((byte) => byte != 0),
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
    final nick = hit.scanResponse.isEmpty
        ? _shortLabel(advert.shortPeerId)
        : utf8.decode(hit.scanResponse, allowMalformed: true);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(nick),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Private network starts a hotspot. That is the usual choice.',
            ),
            if (options.showPrivateNetwork) ...[
              const SizedBox(height: 12),
              FilledButton(
                autofocus: true,
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    final end = await orch.startPrivateAttempt(
                      remote: remote,
                      peerHandle: hit.peerHandle,
                    );
                    if (end != AttemptEndReason.running) {
                      _showAttemptError("Couldn't start the private network.");
                    }
                  } catch (_) {
                    _showAttemptError(_reachCopy);
                  }
                  _paint();
                },
                child: const Text('Private network'),
              ),
            ],
            if (options.showUseLanTheirs) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _useTheirNetwork(
                    context,
                    orch,
                    remote,
                    hit.peerHandle,
                  );
                },
                child: const Text('Use their network'),
              ),
            ],
            if (options.showUseLanMine) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _useMyLan(context, orch, remote, hit.peerHandle);
                },
                child: const Text('Use my LAN'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await orch.abort(UserAbort.sheetCancel);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

Future<void> _useTheirNetwork(
    BuildContext context,
    ProximityOrchestrator orch,
    AttemptDevice remote,
    String peerHandle,
  ) async {
    final code = mintSixDigitCode(Random());
    final joinGate = Completer<void>();
    final inviteGate = Completer<void>();
    final result = orch.requestTheirLan(
      remote: remote,
      peerHandle: peerHandle,
      code: code,
      onInvite: () {
        if (!inviteGate.isCompleted) {
          inviteGate.complete();
        }
      },
      onBeforeJoin: () {
        if (!joinGate.isCompleted) {
          joinGate.complete();
        }
      },
    );
    // The attempt can fail before the waiting dialog builds; keep the
    // future "handled" so the zone does not report it early.
    unawaited(result.catchError((_) => AttemptEndReason.abortedSheetCancel));
    await Future.any<void>([
      inviteGate.future,
      result.then((_) {}, onError: (_) {}),
    ]);
    if (!context.mounted) {
      return;
    }
    // A saved network joins here with no invite, so there is no code to show.
    if (inviteGate.isCompleted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _WaitingCodeDialog(
          future: Future.any<void>([joinGate.future, result]),
          code: code,
          title: 'Use their network',
          message: 'Ask them to accept code $code.',
          onCancel: () => orch.abort(UserAbort.sheetCancel),
        ),
      );
    }
    try {
      await result;
    } catch (error) {
      _showAttemptError(_joinCopy(error));
    }
    _paint();
  }

  Future<void> _useMyLan(
    BuildContext context,
    ProximityOrchestrator orch,
    AttemptDevice remote,
    String peerHandle,
  ) async {
    final code = mintSixDigitCode(Random());
    final shareGate = Completer<void>();
    final trustGate = Completer<bool>();
    final result = orch.requestMyLan(
      remote: remote,
      peerHandle: peerHandle,
      code: code,
      onPeerTrust: (verified) {
        if (!trustGate.isCompleted) {
          trustGate.complete(verified);
        }
      },
      sharePassword: () async {
        if (!shareGate.isCompleted) {
          shareGate.complete();
        }
        await WidgetsBinding.instance.endOfFrame;
        if (!context.mounted) {
          return null;
        }
        debugPrint('blan-prox: my lan share ask');
        final outcome = await _acquireLanPsk(context, orch, verb: 'Share');
        return outcome.network;
      },
    );
    unawaited(result.catchError((_) => AttemptEndReason.abortedSheetCancel));
    final trustDone = Completer<bool>();
    final trustTimer = Timer(const Duration(seconds: 8), () {
      if (!trustDone.isCompleted) {
        trustDone.complete(false);
      }
    });
    trustGate.future.then((trusted) {
      trustTimer.cancel();
      if (!trustDone.isCompleted) {
        trustDone.complete(trusted);
      }
    });
    bool mutual = false;
    try {
      final winner = await Future.any<Object?>([result, trustDone.future]);
      trustTimer.cancel();
      if (winner is AttemptEndReason) {
        if (winner != AttemptEndReason.running &&
            winner != AttemptEndReason.abortedSheetCancel &&
            context.mounted) {
          _showAttemptError(_reachCopy);
        }
        return;
      }
      mutual = winner == true;
    } catch (error) {
      trustTimer.cancel();
      if (context.mounted) {
        _showAttemptError(_joinCopy(error));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    // Mutual trust plus a saved network finishes before this wait. A password
    // share still needs the code, so the dialog opens when the quiet path
    // does not settle.
    final quiet = mutual &&
        await Future.any<bool>([
          result.then((_) => true, onError: (_) => true),
          Future<bool>.delayed(const Duration(seconds: 4), () => false),
        ]);
    if (!quiet && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _WaitingCodeDialog(
          future: Future.any<void>([shareGate.future, result]),
          code: code,
          title: 'Use my LAN',
          message: 'Ask them to join code $code.',
          onCancel: () => orch.abort(UserAbort.sheetCancel),
        ),
      );
    }
    try {
      final end = await result;
      if (end != AttemptEndReason.running &&
          end != AttemptEndReason.abortedSheetCancel) {
        _showAttemptError(_reachCopy);
      }
    } catch (error) {
      _showAttemptError(_joinCopy(error));
    }
    _paint();
  }

  Future<OsWifiNetwork?> _lanOffer(
    BuildContext context,
    ProximityOrchestrator orch,
  ) async {
    return (await _acquireLanPsk(context, orch, verb: 'Share')).network;
  }

  /// Resolves the local Wi-Fi credentials.
  ///
  /// Android: a Shizuku read that is already allowed runs silently and ends
  /// in a confirmation dialog; otherwise the sheet asks once whether to use
  /// Shizuku. Desktop reads the OS passphrase store and also confirms. Manual
  /// entry is the fallback everywhere; its Skip is surfaced for callers that
  /// can start a private network instead.
  Future<_LanPskOutcome> _acquireLanPsk(
    BuildContext context,
    ProximityOrchestrator orch, {
    required String verb,
  }) async {
    final android = !kIsWeb && Platform.isAndroid;
    if (android) {
      try {
        await AndroidShizukuConsent().startListening();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } catch (_) {}
    }
    final choice = android ? await _shizukuChoice() : true;
    debugPrint('blan-prox: lan psk choice=$choice');
    if (choice == true) {
      final got = await LanPskAcquire.existing(
        readPsk: () => _readPsk(orch),
        currentSsid: () => _currentSsid(orch),
      );
      debugPrint(
        'blan-prox: lan psk silent ssid=${got.ssidHint ?? "-"} hasPass=${got.hasPassphrase}',
      );
      if (got.network != null) {
        final confirmed =
            context.mounted && await _confirmLanPsk(context, verb, got.network!);
        return _LanPskOutcome(network: confirmed ? got.network : null);
      }
      if (!context.mounted) {
        return const _LanPskOutcome();
      }
      return _askManual(context, got.ssidHint);
    } else if (android && choice == null && context.mounted) {
      final useShizuku = await _askUseShizuku(context);
      if (useShizuku == null) {
        return const _LanPskOutcome();
      }
      await ref.read(appServiceProvider).setNearbyShizukuAllowed(useShizuku);
      if (useShizuku) {
        final got = await LanPskAcquire.existing(
          readPsk: () => _readPsk(orch),
          currentSsid: () => _currentSsid(orch),
        );
        debugPrint(
          'blan-prox: lan psk after ask ssid=${got.ssidHint ?? "-"} hasPass=${got.hasPassphrase}',
        );
        if (got.network != null) {
          final confirmed =
              context.mounted && await _confirmLanPsk(context, verb, got.network!);
          return _LanPskOutcome(network: confirmed ? got.network : null);
        }
        if (!context.mounted) {
          return const _LanPskOutcome();
        }
        return _askManual(context, got.ssidHint);
      }
    }
    if (!context.mounted) {
      return const _LanPskOutcome();
    }
    final ssid = await _currentSsid(orch);
    if (!context.mounted) {
      return const _LanPskOutcome();
    }
    return _askManual(context, ssid);
  }

  Future<_LanPskOutcome> _askManual(BuildContext context, String? ssid) async {
    debugPrint('blan-prox: lan psk manual ssid=${ssid ?? "-"}');
    if (!context.mounted) {
      return const _LanPskOutcome();
    }
    final entered = await _askPassword(context, ssid);
    if (entered == null) {
      return const _LanPskOutcome();
    }
    if (entered.skip) {
      return const _LanPskOutcome(skip: true);
    }
    if (entered.ssid.isEmpty || entered.passphrase.isEmpty) {
      return const _LanPskOutcome();
    }
    await ref.read(appServiceProvider).rememberWifi(
      ssid: entered.ssid,
      security: entered.security,
      passphrase: entered.passphrase,
      remember: entered.remember,
    );
    return _LanPskOutcome(
      network: OsWifiNetwork(
        ssid: entered.ssid,
        passphrase: entered.passphrase,
        security: entered.security,
      ),
    );
  }

  Future<bool?> _shizukuChoice() async {
    try {
      return await ref.read(appServiceProvider).nearbyShizukuChoice();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _currentSsid(ProximityOrchestrator orch) async {
    try {
      final ssid = await orch.readCurrentSsid?.call();
      if (ssid == null || ssid.isEmpty) {
        return null;
      }
      return ssid;
    } catch (_) {
      return null;
    }
  }

  /// Show the extracted SSID and ask before it is used. The passphrase stays
  /// hidden — only its origin is named.
  Future<bool> _confirmLanPsk(
    BuildContext context,
    String verb,
    OsWifiNetwork psk,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$verb Wi-Fi'),
        content: Text("Use the saved password for '${psk.ssid}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(verb),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  /// Ask once whether Shizuku may read the current Wi-Fi password.
  /// Returns null when the dialog was dismissed.
  Future<bool?> _askUseShizuku(BuildContext context) async {
    final state = await AndroidShizukuConsent().state();
    if (!context.mounted) {
      return null;
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wi-Fi password'),
        content: Text(
          state == 'ready'
              ? 'Read the current Wi-Fi password with Shizuku?'
              : 'Read the current Wi-Fi password with Shizuku?\n'
                    '${shizukuSettingsCopy(state)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Enter manually'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Shizuku'),
          ),
        ],
      ),
    );
  }

  Future<OsWifiNetwork?> _readPsk(ProximityOrchestrator orch) async {
    try {
      return await orch.readPersonalPsk();
    } catch (_) {
      return null;
    }
  }

  Future<_PasswordEntry?> _askPassword(BuildContext context, String? ssid) {
    return showDialog<_PasswordEntry>(
      context: context,
      builder: (context) => _WifiPasswordDialog(initialSsid: ssid),
    );
  }

  static const _reachCopy = "Couldn't reach the device. Scan again and retry.";

  String _joinCopy(Object error) {
    final text = error.toString();
    if (text.contains('shizukuDead')) {
      return 'Shizuku is not running on this phone, so it cannot switch Wi-Fi.';
    }
    if (text.contains('joinFailed')) {
      return "Couldn't switch Wi-Fi.";
    }
    return _reachCopy;
  }

  void _showAttemptError(String message) {
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nearby failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(prompt.nick, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(prompt.code, style: Theme.of(sheetContext).textTheme.headlineSmall),
              if (_targetCopy(prompt).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_targetCopy(prompt)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _takePrompt(prompt);
                      unawaited(orch.applyInviteResult('decline'));
                    },
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      _takePrompt(prompt);
                      if (prompt.useLanTheirs) {
                        if (!context.mounted) {
                          await orch.applyInviteResult('decline');
                          return;
                        }
                        final offer = await _lanOffer(context, orch);
                        if (offer == null) {
                          await orch.applyInviteResult('decline');
                          return;
                        }
                        orch.stageLanOffer(offer);
                      }
                      await orch.applyInviteResult('accept');
                    },
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleMatches() {
    final ids = <String>{
      for (final hit in _dedupe(_hits.values))
        if (_peerForHit(hit) case final peer?) peer.id,
    };
    final visible = _dedupe(
      _hits.values.where((hit) => _peerForHit(hit) == null),
    ).length;
    if (setEquals(ids, _published) && visible == _publishedCount) {
      return;
    }
    _published = ids;
    _publishedCount = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _lanIds?.state = ids;
      _hitCount?.state = visible;
    });
  }

  /// One row per device: the same peer can surface under several addresses
  /// (dual advert sets, rotating BLE private addresses). Group by advert
  /// identity (port + short peer id) and keep the newest hit that carries a
  /// scan response (nick) — a nick-bearing hit always displaces the previous
  /// one so the row points at the device's current address. A hit without a
  /// scan response never displaces a nick-bearing row.
  Iterable<BleScanHit> _dedupe(Iterable<BleScanHit> hits) {
    final byIdentity = <String, BleScanHit>{};
    for (final hit in hits) {
      final advert = ProximityAdvert.unpack(hit.advert);
      final key =
          '${advert.port}:${_shortLabel(advert.shortPeerId)}';
      final existing = byIdentity[key];
      if (existing == null || hit.scanResponse.isNotEmpty) {
        byIdentity[key] = hit;
      }
    }
    return byIdentity.values;
  }

  Peer? _peerForHit(BleScanHit hit) {
    final advert = ProximityAdvert.unpack(hit.advert);
    for (final peer in widget.peers) {
      if (peer.port == advert.port && _sameShort(peer.id, advert.shortPeerId)) {
        return peer;
      }
    }
    return null;
  }

  Peer? _peerAtAdvert(ProximityAdvert advert) {
    final host = advert.ipv4.join('.');
    for (final peer in widget.peers) {
      if (peer.host == host && peer.port == advert.port) {
        return peer;
      }
    }
    return null;
  }

  void _noteAdvert(BleScanHit hit) {
    final ProximityAdvert advert;
    try {
      advert = ProximityAdvert.unpack(hit.advert);
    } on FormatException {
      return;
    }
    final key =
        '${advert.ipv4.join('.')}:${advert.port}:${_shortLabel(advert.shortPeerId)}';
    if (!_notedAdvert.add(key)) {
      return;
    }
    widget.onAdvert?.call(advert);
  }

  bool _reachedOnLan(ProximityAdvert advert, String host) {
    final hasIpv4 = advert.ipv4.any((byte) => byte != 0);
    final advertLocal = hasIpv4 && hostSharesLocalSubnet(host, widget.subnets);
    for (final peer in widget.peers) {
      if (peer.port != advert.port) {
        continue;
      }
      final sameHost = peer.host == host;
      final sameDevice = _sameShort(peer.id, advert.shortPeerId);
      if (!sameHost && !sameDevice) {
        continue;
      }
      return sameLanReachable(
        advertHasIpv4: hasIpv4,
        advertOnSubnet: advertLocal,
        storedOnSubnet: hostSharesLocalSubnet(peer.host, widget.subnets),
        peerStale: peer.stale,
      );
    }
    return false;
  }

}

String _targetCopy(InvitePrompt prompt) {
  final lines = <String>[];
  if (prompt.useLanTheirs) {
    lines.add('They want to join your Wi-Fi.');
  }
  if (prompt.useLanMine) {
    lines.add('They want you on their Wi-Fi.');
  }
  if (prompt.usePrivateNetwork) {
    lines.add('They want a private network.');
  }
  return lines.join('\n');
}

String _shortLabel(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String _badgeLabel(ProximityBadge badge) {
  return switch (badge) {
    ProximityBadge.sameLan => 'Same LAN',
    ProximityBadge.otherLan => 'Other LAN',
    ProximityBadge.bleOnly => 'BLE only',
  };
}

bool _sameShort(String peerId, List<int> shortId) {
  final List<int> mine;
  try {
    mine = shortPeerIdFromUuid(peerId);
  } on FormatException {
    return false;
  }
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

class _LanPskOutcome {
  const _LanPskOutcome({this.network, this.skip = false});

  final OsWifiNetwork? network;
  final bool skip;
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

/// Shows the minted code while the request is in flight and closes itself
/// when the attempt settles, so a fast failure cannot strand the dialog.
class _WaitingCodeDialog extends StatefulWidget {
  const _WaitingCodeDialog({
    required this.future,
    required this.code,
    required this.title,
    required this.message,
    required this.onCancel,
  });

  final Future<void> future;
  final String code;
  final String title;
  final String message;
  final Future<void> Function() onCancel;

  @override
  State<_WaitingCodeDialog> createState() => _WaitingCodeDialogState();
}

class _WaitingCodeDialogState extends State<_WaitingCodeDialog> {
  var _closing = false;

  @override
  void initState() {
    super.initState();
    widget.future.whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _closing) {
          return;
        }
        _closing = true;
        Navigator.of(context).pop();
      });
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.message),
      actions: [
        TextButton(
          onPressed: () {
            _closing = true;
            Navigator.pop(context);
            widget.onCancel();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _WifiPasswordDialog extends StatefulWidget {
  const _WifiPasswordDialog({this.initialSsid});

  final String? initialSsid;

  @override
  State<_WifiPasswordDialog> createState() => _WifiPasswordDialogState();
}

class _WifiPasswordDialogState extends State<_WifiPasswordDialog> {
  late final TextEditingController _ssid;
  final _passphrase = TextEditingController();
  var _remember = false;
  var _security = WifiSecurity.wpa2Psk;

  @override
  void initState() {
    super.initState();
    _ssid = TextEditingController(text: widget.initialSsid ?? '');
    _passphrase.addListener(() => setState(() {}));
  }

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
          onPressed: _passphrase.text.isEmpty
              ? null
              : () => Navigator.pop(
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
