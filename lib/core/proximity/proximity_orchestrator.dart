import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../platform/android/android_proximity_radios.dart';
import '../../platform/desktop/linux_proximity_radios.dart';
import '../../platform/desktop/macos_proximity_radios.dart';
import '../../platform/desktop/windows_proximity_radios.dart';
import '../../platform/ios/ios_proximity_radios.dart';
import '../persistence/database.dart';
import '../security/device_identity.dart';
import '../security/remembered_wifi.dart';
import '../security/shizuku_psk_gate.dart';
import 'proximity_advert.dart';
import 'proximity_control_frames.dart';
import 'proximity_invite_queue.dart';
import 'proximity_policy.dart';
import 'proximity_radios.dart';

/// Wires session policy to the local radio ports. Tests inject fakes.
/// [production] is the only constructor that opens a platform radio.
class ProximityOrchestrator {
  ProximityOrchestrator({
    required this.ble,
    required this.control,
    required this.network,
    required this.queue,
    required this.codec,
    required this.now,
    required this.readPersonalPsk,
    required this.openLan,
    this.presentInvite,
    this.trustPeer,
    this.idle = const Duration(minutes: 3),
    this.membersCanInvite = true,
    this.localFingerprint = '',
  });

  final BlePresencePort ble;
  final ControlChannelPort control;
  final PrivateNetworkPort network;
  final InviteQueue queue;
  ControlFrameCodec? codec;
  final DateTime Function() now;
  Future<OsWifiNetwork?> Function() readPersonalPsk;
  Future<void> Function(String host, int port) openLan;
  Future<void> Function(InvitePrompt prompt, {required bool foreground})?
  presentInvite;

  /// Fires when accepting "use their network" needs a PSK the OS gate could
  /// not supply. The UI must stage an offer and re-run the accept.
  Future<void> Function(InvitePrompt prompt)? needsLanPassword;
  Future<String?> Function()? readCurrentSsid;

  /// Saved personal PSK for an SSID that may not be the connected one.
  Future<OsWifiNetwork?> Function(String ssid)? readSavedPersonalPsk;

  /// Saved-SSID check that does not return a passphrase.
  Future<bool> Function(String ssid)? hasSavedSsid;

  /// STA switch onto a network this phone already saved.
  Future<void> Function(String ssid, WifiJoinStyle style)? joinSavedNetwork;

  /// True when [peerId] is trusted and [publicKeyBase64] is the key stored
  /// for that peer. The hello signature has already been checked.
  Future<bool> Function(String peerId, String publicKeyBase64)? peerIsTrusted;

  /// STA switch for a normal LAN join. Local-only joins ignore this.
  Future<WifiJoinStyle> Function()? wifiJoinStyle;
  final Future<void> Function(String peerId)? trustPeer;
  Future<void> Function()? refreshLoad;
  Duration idle;
  bool membersCanInvite;
  String localFingerprint;
  String localNick = '';

  int associatedClients = 0;
  int transfersInFlight = 0;
  bool get isPrivateNetworkUp => _privateUpSince != null;
  String? advertError;
  TrustDecision? lastTrust;
  bool? lastCanAdmit;
  String? knownPeerId;

  AttemptDevice? localDevice;
  AttemptDevice? remoteDevice;
  List<AttemptDevice> extraMembers = const [];
  ControlLink? link;
  ControlSession session = ControlSession();

  /// One session per inbound link: several initiators may connect at once,
  /// and each hello must not stomp the others' verification keys.
  final _linkSessions = <ControlLink, ControlSession>{};

  /// Invite code → the inbound link it arrived on, so replies and secrets
  /// go back over the initiator's own link with that initiator's session.
  final _inviteLinks = <String, ControlLink>{};

  List<int> Function() advertBytes = _defaultAdvert;
  List<int> Function() scanResponseBytes = _defaultScan;

  /// Also send the legacy-mode advert set when the platform supports it.
  bool dualLegacyAdvert = true;

  bool _visible = false;
  bool _foreground = false;
  final _scanResets = StreamController<void>.broadcast();

  /// Fires when a refresh drops the current scan so the list can refill.
  Stream<void> get scanResets => _scanResets.stream;
  int _advertRetries = 0;
  StreamSubscription<ControlLink>? _inboundSub;
  DateTime? _privateUpSince;
  HotspotCredentials? _hosted;
  OsWifiNetwork? _lanOffer;
  String? _peerWifiSsid;
  String? _peerId;
  String? _peerPublicKey;
  var _awaitingMyLanSecret = false;
  var _sentHello = false;
  final _helloReplied = <ControlLink>{};
  var _cancelAttempt = false;
  final _inviteNicks = <String, String>{};
  final _plans = <String, List<HostStep>>{};
  final _prompts = <String, InvitePrompt>{};

  static ProximityOrchestrator production(AppDatabase db) {
    if (kIsWeb) {
      throw UnsupportedError('proximity radios are not available on web');
    }
    final radios = _platformRadios();
    final consent = Platform.isAndroid ? AndroidShizukuConsent() : null;
    final psk = radios as OsPassphrasePort;
    final androidInvite = Platform.isAndroid ? AndroidInvitePresenter() : null;
    final orch = ProximityOrchestrator(
      ble: radios as BlePresencePort,
      control: radios as ControlChannelPort,
      network: radios as PrivateNetworkPort,
      queue: InviteQueue(),
      codec: null,
      now: DateTime.now,
      presentInvite: (prompt, {required bool foreground}) {
        if (androidInvite != null) {
          return androidInvite
              .showInvite(
                nick: prompt.nick,
                code: prompt.code,
                foreground: foreground,
                useLanTheirs: prompt.useLanTheirs,
                useLanMine: prompt.useLanMine,
                usePrivateNetwork: prompt.usePrivateNetwork,
              )
              .then((_) {});
        }
        return _present();
      },
      readPersonalPsk: () {
        if (radios is AndroidProximityRadios && consent != null) {
          return ShizukuPskGate.read(
            choice: db.nearbyShizukuChoice,
            persist: db.setNearbyShizukuAllowed,
            state: consent.state,
            requestPermission: () async {
              await consent.requestPermission();
            },
            ask: consent.confirm,
            read: radios.readCurrentPersonalPsk,
          );
        }
        return psk.readCurrentPersonalPsk();
      },
      openLan: (_, _) async {},
    );
    orch.readCurrentSsid = psk.readCurrentSsid;
    if (radios is AndroidProximityRadios) {
      orch.readSavedPersonalPsk = radios.readSavedPersonalPsk;
      orch.hasSavedSsid = radios.hasSavedSsid;
      orch.joinSavedNetwork = (ssid, style) =>
          radios.joinSaved(ssid: ssid, style: style);
    }
    orch.peerIsTrusted = (peerId, publicKey) async {
      final row = await db.peerById(peerId);
      return trustedKeyMatches(
        trusted: row?.trusted == true,
        storedFingerprint: row?.fingerprint,
        publicKeyBase64: publicKey,
      );
    };
    orch.wifiJoinStyle = () async {
      final choice = await db.nearbyWifiJoinChoice();
      if (choice == 'direct') {
        return WifiJoinStyle.direct;
      }
      if (choice == 'panel') {
        return WifiJoinStyle.panel;
      }
      if (consent != null &&
          await db.nearbyShizukuAllowed() &&
          await consent.state() == 'ready') {
        return WifiJoinStyle.direct;
      }
      return WifiJoinStyle.panel;
    };
    if (consent != null) {
      unawaited(consent.startListening());
    }
    if (androidInvite != null) {
      androidInvite.inviteResults.listen((result) {
        unawaited(orch.applyInviteResult(result));
      });
    }
    return orch;
  }

  Future<void> start({required bool foreground}) {
    return setVisible(true, foreground: foreground);
  }

  Future<void> setVisible(bool visible, {required bool foreground}) async {
    _visible = visible;
    _foreground = foreground;
    if (!visible) {
      await ble.stopAdvert();
      await ble.stopScan();
      return;
    }
    await _startAdvert();
    debugPrint('blan-prox: advert up');
    try {
      await control.startListening();
      debugPrint('blan-prox: listening');
      _listenInbound();
    } catch (error) {
      debugPrint('blan-prox: listen error $error');
      _noteRadio(error);
    }
    if (foreground) {
      try {
        await ble.startScan();
        debugPrint('blan-prox: scanning');
      } catch (error) {
        debugPrint('blan-prox: scan error $error');
        _noteRadio(error);
      }
    } else {
      await ble.stopScan();
    }
  }

  Future<void> onForeground() async {
    _foreground = true;
    if (_visible) {
      await ble.startScan();
    }
  }

  Future<void> onBackground() async {
    _foreground = false;
    if (_visible) {
      await ble.stopScan();
    }
  }

  /// Restart the advert and the scan. Same idea as an mDNS re-browse.
  Future<void> refreshRadio() async {
    if (!_visible) {
      return;
    }
    await _startAdvert();
    if (!_foreground) {
      return;
    }
    _scanResets.add(null);
    try {
      await ble.stopScan();
    } catch (error) {
      _noteRadio(error);
    }
    try {
      await ble.startScan();
    } catch (error) {
      _noteRadio(error);
    }
  }

  Future<void> stopRadios({required bool keepPrivateNetwork}) async {
    await refreshLoad?.call();
    await _inboundSub?.cancel();
    _inboundSub = null;
    await ble.stopAdvert();
    await ble.stopScan();
    await control.stopListening();
    if (!keepPrivateNetwork) {
      await _stopPrivate();
    }
  }

  Future<void> retryAdvert() async {
    if (_advertRetries >= 1) {
      return;
    }
    _advertRetries++;
    await _startAdvert();
  }

  Future<void> disband() => _stopPrivate();

  void checkIdle(DateTime at) {
    final previous = queue.active?.id;
    final expiredCode = queue.active?.code;
    final expiredPlan = _plans[queue.active?.code];
    final expired = queue.tick(at);
    if (expired != null) {
      lastTrust = onInviteRejected();
      final activeLink = expiredCode == null ? null : _inviteLinks[expiredCode];
      final activeSession = activeLink == null
          ? session
          : _linkSessions[activeLink] ?? session;
      if (expiredPlan != null && activeLink != null && codec != null) {
        unawaited(_failOwned(expiredPlan, activeLink, activeSession));
      }
      _presentActive(previous);
    }
    final since = _privateUpSince;
    if (since == null) {
      return;
    }
    if (associatedClients > 0 || transfersInFlight > 0) {
      return;
    }
    if (at.isBefore(since.add(idle))) {
      return;
    }
    unawaited(_stopPrivate());
  }

  ProximityBadge badgeForHit(
    BleScanHit hit, {
    required bool onLocalSubnet,
    required bool helloSucceeded,
  }) {
    final advert = ProximityAdvert.unpack(hit.advert);
    return badgeFor(
      BadgeFacts(
        hasAdvertisedIpv4: advert.ipv4.any((byte) => byte != 0),
        onLocalSubnet: onLocalSubnet,
        helloSucceeded: helloSucceeded,
      ),
    );
  }

  TapAction actionFor(TapFacts facts) => tapAction(facts);

  Future<AttemptEndReason> openSameLan({
    required String host,
    required int port,
  }) async {
    await openLan(host, port);
    return AttemptEndReason.running;
  }

  Future<AttemptEndReason> abort(UserAbort event) async {
    if (!isAbort(event)) {
      throw ArgumentError(event);
    }
    _cancelAttempt = true;
    final active = link;
    if (active != null) {
      await active.close();
    }
    return switch (event) {
      UserAbort.sheetCancel => AttemptEndReason.abortedSheetCancel,
      UserAbort.codeDecline => AttemptEndReason.abortedCodeDecline,
      UserAbort.inviteTimeout => AttemptEndReason.abortedInviteTimeout,
    };
  }

  Future<AttemptEndReason> passwordMiss() async {
    if (!passwordMissingFallsThrough()) {
      return AttemptEndReason.abortedSheetCancel;
    }
    final local = localDevice;
    final remote = remoteDevice;
    final activeLink = link;
    if (local == null || remote == null || activeLink == null) {
      throw StateError('password miss without an attempt');
    }
    return runHostPlan(
      local: local,
      remote: remote,
      extraMembers: extraMembers,
      link: activeLink,
      session: session,
    );
  }

  Future<void> bindPeer({
    required AttemptDevice remote,
    required String peerHandle,
  }) async {
    if (localDevice == null) {
      throw StateError('local device unset');
    }
    remoteDevice = remote;
    _sentHello = false;
    _helloReplied.clear();
    // Fresh session per attempt: the previous attempt's peer keys and
    // accepted flag must not leak into a new invitation.
    session = ControlSession();
    link = await _connect(peerHandle);
  }

  void stageLanOffer(OsWifiNetwork network) {
    _lanOffer = network;
  }

  /// Ask [remote] to share the Wi-Fi it is already on, then join that network.
  Future<AttemptEndReason> requestTheirLan({
    required AttemptDevice remote,
    required String peerHandle,
    required String code,
    VoidCallback? onBeforeJoin,
    VoidCallback? onInvite,
  }) async {
    _cancelAttempt = false;
    if (codec == null) {
      throw StateError('codec not bound');
    }
    await bindPeer(remote: remote, peerHandle: peerHandle);
    final activeLink = link;
    if (activeLink == null) {
      throw StateError('local device unset');
    }
    await _sendHello(activeLink);
    var invited = false;
    try {
      await for (final frame in activeLink.incoming) {
        if (_cancelAttempt) {
          return AttemptEndReason.abortedSheetCancel;
        }
        final body = await _requireCodec().decode(frame, session: session);
        if (body is ControlHelloBody && !invited) {
          final theirs = body.wifiSsid;
          final mine = await _wifiSsid();
          final saved = theirs != null && theirs.isNotEmpty && theirs != mine
              ? await _savedFor(theirs)
              : null;
          if (saved != null) {
            debugPrint('blan-prox: their lan saved join ssid=$theirs');
            onBeforeJoin?.call();
            if (onBeforeJoin != null) {
              await Future<void>.delayed(const Duration(milliseconds: 300));
            }
            await _joinLan(saved);
            return AttemptEndReason.running;
          }
          invited = true;
          debugPrint('blan-prox: their lan invite ssid=${theirs ?? "-"}');
          onInvite?.call();
          await _send(
            activeLink,
            await _requireCodec().encode(
              ControlInviteBody(
                nick: localNick.isEmpty ? localDevice!.id : localNick,
                code: code,
                hostPlan: const [],
                useLanMine: false,
                useLanTheirs: true,
                usePrivateNetwork: false,
              ),
              session: session,
            ),
          );
        } else if (body is ControlDeclineBody) {
          return AttemptEndReason.abortedCodeDecline;
        } else if (body is ControlSecretBody && body.kind == 'lan') {
          debugPrint('blan-prox: their lan secret join ssid=${body.ssid}');
          onBeforeJoin?.call();
          if (onBeforeJoin != null) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          await _joinLan(
            OsWifiNetwork(
              ssid: body.ssid,
              passphrase: body.psk,
              security: WifiSecurity.fromWire(body.security),
            ),
          );
          return AttemptEndReason.running;
        }
      }
    } catch (_) {
      if (_cancelAttempt) {
        return AttemptEndReason.abortedSheetCancel;
      }
      rethrow;
    }
    if (_cancelAttempt) {
      return AttemptEndReason.abortedSheetCancel;
    }
    return AttemptEndReason.hostChainExhausted;
  }

  /// Stay on this Wi-Fi and ask [remote] to join it.
  ///
  /// The receiver switches with a saved password when it has one. Otherwise
  /// [sharePassword] runs and the secret is sent after accept.
  Future<AttemptEndReason> requestMyLan({
    required AttemptDevice remote,
    required String peerHandle,
    required String code,
    required Future<OsWifiNetwork?> Function() sharePassword,
    void Function(bool theyTrust)? onPeerTrust,
  }) async {
    _cancelAttempt = false;
    if (codec == null) {
      throw StateError('codec not bound');
    }
    await bindPeer(remote: remote, peerHandle: peerHandle);
    final activeLink = link;
    if (activeLink == null) {
      throw StateError('local device unset');
    }
    await _sendHello(activeLink);
    var invited = false;
    try {
      await for (final frame in activeLink.incoming) {
        if (_cancelAttempt) {
          return AttemptEndReason.abortedSheetCancel;
        }
        final body = await _requireCodec().decode(frame, session: session);
        if (body is ControlHelloBody && !invited) {
          invited = true;
          onPeerTrust?.call(
            await _weTrust(body.peerId, body.publicKeyBase64),
          );
          await _send(
            activeLink,
            await _requireCodec().encode(
              ControlInviteBody(
                nick: localNick.isEmpty ? localDevice!.id : localNick,
                code: code,
                hostPlan: const [],
                useLanMine: true,
                useLanTheirs: false,
                usePrivateNetwork: false,
              ),
              session: session,
            ),
          );
        } else if (body is ControlDeclineBody) {
          return AttemptEndReason.abortedCodeDecline;
        } else if (body is ControlLanStatusBody) {
          if (!body.needPsk) {
            return AttemptEndReason.running;
          }
          final shared = await sharePassword();
          if (_cancelAttempt) {
            return AttemptEndReason.abortedSheetCancel;
          }
          if (shared == null) {
            return AttemptEndReason.abortedSheetCancel;
          }
          await _send(
            activeLink,
            await _requireCodec().encode(
              ControlSecretBody(
                ssid: shared.ssid,
                psk: shared.passphrase,
                security: shared.security.wire,
                kind: 'lan',
              ),
              session: session,
            ),
          );
          return AttemptEndReason.running;
        }
      }
    } catch (_) {
      if (_cancelAttempt) {
        return AttemptEndReason.abortedSheetCancel;
      }
      rethrow;
    }
    if (_cancelAttempt) {
      return AttemptEndReason.abortedSheetCancel;
    }
    return AttemptEndReason.hostChainExhausted;
  }

  Future<AttemptEndReason> startPrivateAttempt({
    required AttemptDevice remote,
    required String peerHandle,
  }) async {
    _cancelAttempt = false;
    if (codec == null) {
      throw StateError('codec not bound');
    }
    await bindPeer(remote: remote, peerHandle: peerHandle);
    final local = localDevice;
    final activeLink = link;
    if (local == null || activeLink == null) {
      throw StateError('local device unset');
    }
    // One subscription for the whole attempt. A second listen drops the
    // accept that arrives while the invite is still being written.
    final frames = StreamIterator(activeLink.incoming);
    await _sendHello(activeLink);
    String? remotePeerId;
    while (await frames.moveNext()) {
      if (_cancelAttempt) {
        return AttemptEndReason.abortedSheetCancel;
      }
      final body = await _requireCodec().decode(
        frames.current,
        session: session,
      );
      if (body is ControlHelloBody) {
        remotePeerId = body.peerId;
        break;
      }
    }
    if (remotePeerId == null || remotePeerId.isEmpty) {
      return AttemptEndReason.hostChainExhausted;
    }
    final remoteDevice = AttemptDevice(id: remotePeerId, kind: remote.kind);
    final plan = hostChain(local: local, remote: remoteDevice);
    debugPrint('blan-prox: private invite peer=$remotePeerId');
    await _send(
      activeLink,
      await _requireCodec().encode(
        ControlInviteBody(
          nick: localNick.isEmpty ? local.id : localNick,
          code: mintSixDigitCode(Random()),
          hostPlan: plan,
          useLanMine: false,
          useLanTheirs: false,
          usePrivateNetwork: true,
        ),
        session: session,
      ),
    );
    return runHostPlan(
      local: local,
      remote: remoteDevice,
      extraMembers: extraMembers,
      link: activeLink,
      session: session,
      frames: frames,
    );
  }

  Future<AttemptEndReason> skipPassword({
    required AttemptDevice remote,
    required String peerHandle,
  }) async {
    await bindPeer(remote: remote, peerHandle: peerHandle);
    return passwordMiss();
  }

  Future<AttemptEndReason> runHostPlan({
    required AttemptDevice local,
    required AttemptDevice remote,
    List<AttemptDevice> extraMembers = const [],
    required ControlLink link,
    required ControlSession session,
    StreamIterator<Map<String, dynamic>>? frames,
  }) async {
    final allowed = {local.id, remote.id, ...extraMembers.map((d) => d.id)};
    final steps = hostChain(
      local: local,
      remote: remote,
      extraMembers: extraMembers,
    ).where((step) => allowed.contains(step.hostId));
    StreamIterator<Map<String, dynamic>>? open = frames;
    for (final step in steps) {
      if (step.hostId == local.id) {
        final recorder = _RecordingNetwork(network);
        final hosted = await walkHostChain(
          steps: [step],
          portsByHostId: {local.id: recorder},
        );
        if (hosted == null) {
          await _send(
            link,
            await _requireCodec().encode(
              ControlHostFailedBody(hostId: step.hostId, method: step.method),
              session: session,
            ),
          );
          continue;
        }
        _hosted = recorder.last;
        _privateUpSince = now();
        final delivered = await _finishHosted(step, link, session);
        if (!delivered) {
          await _releaseStep(step);
          continue;
        }
        return AttemptEndReason.running;
      }
      open ??= StreamIterator(link.incoming);
      final remoteBody = await _waitRemote(open, session, step);
      if (remoteBody is ControlDeclineBody) {
        return AttemptEndReason.abortedCodeDecline;
      }
      if (remoteBody is ControlSecretBody) {
        debugPrint('blan-prox: private join ssid=${remoteBody.ssid}');
        await network.join(
          ssid: remoteBody.ssid,
          passphrase: remoteBody.psk,
          security: WifiSecurity.fromWire(remoteBody.security),
          localOnly: true,
        );
        if (associatedClients < 1) {
          associatedClients = 1;
        }
        _privateUpSince = now();
        return AttemptEndReason.running;
      }
    }
    return AttemptEndReason.hostChainExhausted;
  }

  Future<void> onInbound(ControlLink link) async {
    final linkSession = _linkSessions.putIfAbsent(link, ControlSession.new);
    try {
      await for (final frame in link.incoming) {
        await _handleFrame(link, linkSession, frame);
      }
    } catch (error) {
      debugPrint('blan-prox: inbound link dropped: $error');
    }
  }

  Future<void> applyInviteResult(String result) async {
    final active = queue.active;
    if (active == null) {
      return;
    }
    final previous = active.id;
    final plan = _plans[active.code];
    final prompt = _prompts[active.code];
    final activeLink = _inviteLinks[active.code] ?? link;
    final activeSession =
        activeLink == null ? session : _linkSessions[activeLink] ?? session;
    if (result == 'accept') {
      if (prompt != null && prompt.useLanTheirs && _lanOffer == null) {
        // Native / background accept has no staged offer. Hand the prompt
        // to the UI for Shizuku / typed entry instead of popping a second
        // accept dialog or a silent Shizuku consent sheet.
        await needsLanPassword?.call(prompt);
        return;
      }
      lastTrust = onInviteAccepted(
        localFingerprint: localFingerprint,
        remoteFingerprint: activeSession.peerFingerprint ?? '',
      );
      queue.acceptActive();
      final peerId = knownPeerId;
      if (peerId != null) {
        await trustPeer?.call(peerId);
      }
      if (activeLink != null && codec != null) {
        await _send(
          activeLink,
          await _requireCodec().encode(
            const ControlAcceptBody(),
            session: activeSession,
          ),
        );
        if (prompt != null && prompt.useLanTheirs) {
          // Initiator joins this phone's Wi-Fi. This phone must not switch.
          _awaitingMyLanSecret = false;
          debugPrint('blan-prox: their lan offer');
          await _sendLanOffer(activeLink, activeSession);
          _presentActive(previous);
          return;
        }
        if (prompt != null && prompt.useLanMine) {
          debugPrint('blan-prox: my lan answer ssid=${_peerWifiSsid ?? "-"}');
          await _answerMyLan(activeLink, activeSession);
          _presentActive(previous);
          return;
        }
        if (plan != null) {
          await _hostOwned(plan, activeLink, activeSession);
        }
        await _sendLanOffer(activeLink, activeSession);
      }
    } else if (result == 'decline') {
      _lanOffer = null;
      lastTrust = onInviteRejected();
      queue.declineActive();
      if (activeLink != null && plan != null) {
        await _failOwned(plan, activeLink, activeSession);
      }
    }
    _presentActive(previous);
  }

  Future<AttemptEndReason> onScan(BleScanHit hit) async {
    final advert = ProximityAdvert.unpack(hit.advert);
    final inGroup =
        (advert.role == AdvertRole.owner || advert.role == AdvertRole.member) &&
        advert.groupId.any((byte) => byte != 0);
    if (!inGroup) {
      return AttemptEndReason.running;
    }
    lastCanAdmit = canAdmit(
      admitterRole: advert.role == AdvertRole.owner
          ? ProximityRole.owner
          : ProximityRole.member,
      network: PrivateNetworkKind.wifiDirect,
      membersCanInvite: membersCanInvite,
    );
    final connected = await _connect(hit.peerHandle);
    link = connected;
    unawaited(onInbound(connected));
    return AttemptEndReason.running;
  }

  void _noteRadio(Object error) {
    final text = error.toString();
    final current = advertError;
    advertError = current == null || current.isEmpty ? text : '$current\n$text';
  }

  Future<void> _startAdvert() async {
    try {
      await ble.startAdvert(
        payload: advertBytes(),
        scanResponse: scanResponseBytes(),
        dualLegacy: dualLegacyAdvert,
      );
      advertError = null;
    } catch (error) {
      advertError = error.toString();
    }
  }

  Future<ControlLink> _connect(String peerHandle) async {
    // Scan handles are always LE addresses (rotating RPAs): classic RFCOMM
    // cannot route them, so GATT goes first and RFCOMM is the fallback for
    // peers that expose a classic address.
    try {
      return await control.connect(
        peerHandle,
        transport: ControlTransport.gatt,
      );
    } on StateError {
      return control.connect(peerHandle, transport: ControlTransport.rfcomm);
    }
  }

  Future<Object> _waitRemote(
    StreamIterator<Map<String, dynamic>> frames,
    ControlSession session,
    HostStep step,
  ) async {
    while (await frames.moveNext()) {
      final body = await _requireCodec().decode(frames.current, session: session);
      if (body is ControlDeclineBody || body is ControlSecretBody) {
        return body;
      }
      if (body is ControlHostFailedBody &&
          body.hostId == step.hostId &&
          body.method == step.method) {
        return body;
      }
    }
    throw StateError('control link closed');
  }

  Future<void> _handleFrame(
    ControlLink link,
    ControlSession linkSession,
    Map<String, dynamic> frame,
  ) async {
    final body = await _requireCodec().decode(frame, session: linkSession);
    if (body is ControlHelloBody) {
      debugPrint('blan-prox: inbound hello link=$link');
      final ssid = body.wifiSsid;
      if (ssid != null && ssid.isNotEmpty) {
        _peerWifiSsid = ssid;
      }
      _peerId = body.peerId;
      _peerPublicKey = body.publicKeyBase64;
      await _replyHello(link, linkSession);
      return;
    }
    if (body is ControlInviteBody) {
      if (body.useLanMine &&
          !body.useLanTheirs &&
          !body.usePrivateNetwork &&
          await _weTrust(_peerId, _peerPublicKey)) {
        final saved = await _savedFor(_peerWifiSsid);
        if (saved != null) {
          debugPrint('blan-prox: my lan trusted join ssid=${saved.ssid}');
          await _answerMyLan(link, linkSession);
          return;
        }
      }
      _inviteNicks[body.code] = body.nick;
      _plans[body.code] = body.hostPlan;
      _inviteLinks[body.code] = link;
      final prompt = InvitePrompt(
        nick: body.nick,
        code: body.code,
        hostPlan: body.hostPlan,
        useLanMine: body.useLanMine,
        useLanTheirs: body.useLanTheirs,
        usePrivateNetwork: body.usePrivateNetwork,
      );
      _prompts[body.code] = prompt;
      final request = InviteRequest(
        id: body.code,
        initiatorFingerprint: linkSession.peerFingerprint ?? '',
        targetFingerprint: localFingerprint,
        code: body.code,
        enqueuedAt: now(),
      );
      final wasActive = queue.active?.id;
      queue.enqueue(request);
      if (queue.active?.id == request.id && queue.active?.id != wasActive) {
        await presentInvite?.call(prompt, foreground: _foreground);
      }
      return;
    }
    if (body is ControlAcceptBody) {
      lastTrust = onInviteAccepted(
        localFingerprint: localFingerprint,
        remoteFingerprint: linkSession.peerFingerprint ?? '',
      );
      final peerId = knownPeerId;
      if (peerId != null) {
        await trustPeer?.call(peerId);
      }
      final plan = _plans[queue.active?.code];
      if (plan != null) {
        await _hostOwned(plan, link, linkSession);
      }
      return;
    }
    if (body is ControlSecretBody &&
        (body.kind == 'hotspot' || body.kind == 'wifiDirect')) {
      debugPrint('blan-prox: private secret join ssid=${body.ssid}');
      await network.join(
        ssid: body.ssid,
        passphrase: body.psk,
        security: WifiSecurity.fromWire(body.security),
        localOnly: true,
      );
      if (associatedClients < 1) {
        associatedClients = 1;
      }
      _privateUpSince = now();
      return;
    }
    if (body is ControlSecretBody &&
        body.kind == 'lan' &&
        _awaitingMyLanSecret) {
      _awaitingMyLanSecret = false;
      await _joinLan(
        OsWifiNetwork(
          ssid: body.ssid,
          passphrase: body.psk,
          security: WifiSecurity.fromWire(body.security),
        ),
      );
      return;
    }
    if (body is ControlDeclineBody) {
      final previous = queue.active?.id;
      final plan = _plans[queue.active?.code];
      lastTrust = onInviteRejected();
      queue.declineActive();
      if (plan != null) {
        await _failOwned(plan, link, linkSession);
      }
      _presentActive(previous);
    }
  }

  Future<void> _hostOwned(
    List<HostStep> plan,
    ControlLink link,
    ControlSession session,
  ) async {
    final local = localDevice;
    if (local == null) {
      return;
    }
    for (final step in plan) {
      if (step.hostId != local.id) {
        continue;
      }
      final recorder = _RecordingNetwork(network);
      final hosted = await walkHostChain(
        steps: [step],
        portsByHostId: {local.id: recorder},
      );
      if (hosted == null) {
        await _sendFailure(step, link, session);
        continue;
      }
      _hosted = recorder.last;
      _privateUpSince = now();
      final delivered = await _finishHosted(step, link, session);
      if (!delivered) {
        await _releaseStep(step);
        continue;
      }
      return;
    }
  }

  Future<void> _failOwned(
    List<HostStep> plan,
    ControlLink link,
    ControlSession session,
  ) async {
    final local = localDevice;
    if (local == null) {
      return;
    }
    for (final step in plan) {
      if (step.hostId == local.id) {
        await _sendFailure(step, link, session);
      }
    }
  }

  void _listenInbound() {
    _inboundSub ??= control.inbound.listen((link) {
      unawaited(onInbound(link));
    });
  }

  Future<void> _releaseStep(HostStep step) async {
    _hosted = null;
    _privateUpSince = null;
    if (step.method == HostMethod.wifiDirect) {
      await network.stopWifiDirect();
    } else {
      await network.stopHotspot();
    }
  }

  Future<bool> _finishHosted(
    HostStep step,
    ControlLink link,
    ControlSession session,
  ) async {
    if (codec == null) {
      return true;
    }
    final creds = _hosted;
    if (creds == null || !session.accepted) {
      await _sendFailure(step, link, session);
      return false;
    }
    final kind = step.method == HostMethod.wifiDirect
        ? PrivateNetworkKind.wifiDirect
        : PrivateNetworkKind.hotspot;
    final deliver =
        kind == PrivateNetworkKind.wifiDirect ||
        mayForwardHotspotCredentials(
          accepted: session.accepted,
          network: kind,
          canAdmit: canAdmit(
            admitterRole: ProximityRole.owner,
            network: kind,
            membersCanInvite: membersCanInvite,
          ),
        );
    if (!deliver) {
      await _sendFailure(step, link, session);
      return false;
    }
    if (associatedClients < 1) {
      associatedClients = 1;
    }
    await _send(
      link,
      await _requireCodec().encode(
        ControlSecretBody(
          ssid: creds.ssid,
          psk: creds.passphrase,
          security: creds.security.wire,
          kind: kind.name,
        ),
        session: session,
      ),
    );
    return true;
  }

  /// Responder path: a peer's hello always gets our hello back, over that
  /// peer's own link and session. The initiator-only [_sentHello] guard
  /// must never suppress this reply. While an invite is active, extra hellos
  /// are ignored so the two ends cannot ping-pong. After the invite finishes,
  /// a new hello must be answered or a retry never sends invite.
  Future<void> _replyHello(ControlLink link, ControlSession linkSession) async {
    if (codec == null || localDevice == null) {
      debugPrint(
        'blan-prox: hello reply skipped codec=${codec != null} '
        'local=${localDevice != null}',
      );
      return;
    }
    if (_helloReplied.contains(link) && queue.active != null) {
      debugPrint('blan-prox: hello reply skipped invite-active');
      return;
    }
    final identity = await _requireCodec().identity.ensureIdentity();
    _helloReplied.add(link);
    await _send(
      link,
      await _requireCodec().encode(
        ControlHelloBody(
          peerId: localDevice!.id,
          nick: localNick.isEmpty ? localDevice!.id : localNick,
          publicKeyBase64: identity.publicKeyBase64,
          wifiSsid: await _wifiSsid(),
        ),
        session: linkSession,
      ),
    );
  }

  Future<void> _sendHello(ControlLink link) async {
    if (_sentHello || codec == null || localDevice == null) {
      debugPrint(
        'blan-prox: hello skipped sent=$_sentHello codec=${codec != null} '
        'local=${localDevice != null}',
      );
      return;
    }
    final identity = await _requireCodec().identity.ensureIdentity();
    _sentHello = true;
    await _send(
      link,
      await _requireCodec().encode(
        ControlHelloBody(
          peerId: localDevice!.id,
          nick: localNick.isEmpty ? localDevice!.id : localNick,
          publicKeyBase64: identity.publicKeyBase64,
          wifiSsid: await _wifiSsid(),
        ),
        session: session,
      ),
    );
  }

  Future<bool> _weTrust(String? peerId, String? publicKey) async {
    if (peerId == null ||
        peerId.isEmpty ||
        publicKey == null ||
        publicKey.isEmpty) {
      return false;
    }
    return await peerIsTrusted?.call(peerId, publicKey) ?? false;
  }

  Future<OsWifiNetwork?> _savedFor(String? ssid) async {
    if (ssid == null || ssid.isEmpty) {
      return null;
    }
    if (await hasSavedSsid?.call(ssid) == true) {
      final detailed = await readSavedPersonalPsk?.call(ssid);
      if (detailed != null &&
          detailed.ssid == ssid &&
          detailed.passphrase.isNotEmpty) {
        return detailed;
      }
      return OsWifiNetwork(
        ssid: ssid,
        passphrase: '',
        security: WifiSecurity.wpa2Psk,
      );
    }
    final saved = await readSavedPersonalPsk?.call(ssid);
    if (saved == null || saved.ssid != ssid || saved.passphrase.isEmpty) {
      return null;
    }
    return saved;
  }

  Future<WifiJoinStyle> _lanStyle() async {
    return await wifiJoinStyle?.call() ?? WifiJoinStyle.panel;
  }

  Future<void> _joinLan(OsWifiNetwork network) async {
    final joinSaved = joinSavedNetwork;
    if (network.passphrase.isEmpty && joinSaved != null) {
      await joinSaved(network.ssid, await _lanStyle());
      return;
    }
    await this.network.join(
      ssid: network.ssid,
      passphrase: network.passphrase,
      security: network.security,
      localOnly: false,
      style: await _lanStyle(),
    );
  }

  /// Receiver of "use my LAN": switch with a saved password, or ask for one.
  Future<void> _answerMyLan(ControlLink link, ControlSession session) async {
    final saved = await _savedFor(_peerWifiSsid);
    if (saved != null) {
      try {
        debugPrint('blan-prox: my lan saved join ssid=${saved.ssid}');
        // Close the initiator's waiting dialog before the STA move. The
        // notify that would close it afterwards is easy to drop once the
        // radio starts switching.
        await _sendLanStatus(link, session, needPsk: false);
        await _joinLan(saved);
        return;
      } catch (error) {
        debugPrint('blan-prox: my lan saved join failed $error');
        await _send(
          link,
          await _requireCodec().encode(
            const ControlDeclineBody(reason: 'joinFailed'),
            session: session,
          ),
        );
        return;
      }
    }
    debugPrint('blan-prox: my lan need psk ssid=${_peerWifiSsid ?? "-"}');
    _awaitingMyLanSecret = true;
    await _sendLanStatus(link, session, needPsk: true);
  }

  Future<void> _sendLanStatus(
    ControlLink link,
    ControlSession session, {
    required bool needPsk,
  }) async {
    await _send(
      link,
      await _requireCodec().encode(
        ControlLanStatusBody(needPsk: needPsk),
        session: session,
      ),
    );
  }

  Future<String?> _wifiSsid() async {
    try {
      final ssid = await readCurrentSsid?.call();
      if (ssid == null || ssid.isEmpty) {
        return null;
      }
      return ssid;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendLanOffer(ControlLink link, ControlSession session) async {
    final offer = _lanOffer;
    _lanOffer = null;
    if (offer == null || codec == null) {
      return;
    }
    await _send(
      link,
      await _requireCodec().encode(
        ControlSecretBody(
          ssid: offer.ssid,
          psk: offer.passphrase,
          security: offer.security.wire,
          kind: 'lan',
        ),
        session: session,
      ),
    );
  }

  Future<void> _sendFailure(
    HostStep step,
    ControlLink link,
    ControlSession session,
  ) async {
    await _send(
      link,
      await _requireCodec().encode(
        ControlHostFailedBody(hostId: step.hostId, method: step.method),
        session: session,
      ),
    );
  }

  void _presentActive(String? previousId) {
    final active = queue.active;
    if (active == null || active.id == previousId) {
      return;
    }
    final present = presentInvite;
    if (present == null) {
      return;
    }
    final prompt = _prompts[active.code];
    if (prompt == null) {
      return;
    }
    unawaited(present(prompt, foreground: _foreground));
  }

  Future<void> _stopPrivate() async {
    _privateUpSince = null;
    _hosted = null;
    associatedClients = 0;
    await network.stopHotspot();
    await network.stopWifiDirect();
    await network.leaveJoined();
  }

  Future<void> _send(ControlLink link, Map<String, dynamic> frame) async {
    try {
      await link.send(frame);
    } catch (_) {
      await link.close();
      rethrow;
    }
  }

  ControlFrameCodec _requireCodec() {
    final bound = codec;
    if (bound == null) {
      throw StateError('codec not bound');
    }
    return bound;
  }

  /// Session bound to an inbound link. Tests use it to prime or manipulate
  /// a specific initiator's session.
  @visibleForTesting
  ControlSession sessionFor(ControlLink link) =>
      _linkSessions.putIfAbsent(link, ControlSession.new);

  static Object _platformRadios() {
    if (Platform.isAndroid) {
      return AndroidProximityRadios();
    }
    if (Platform.isLinux) {
      return LinuxProximityRadios.production();
    }
    if (Platform.isMacOS) {
      return MacosProximityRadios.production();
    }
    if (Platform.isWindows) {
      return WindowsProximityRadios.production();
    }
    if (Platform.isIOS) {
      return IosProximityRadios.production();
    }
    throw UnsupportedError('no proximity radios for this OS');
  }

  static Future<void> _present() {
    if (Platform.isLinux) {
      return LinuxInvitePresenter().present();
    }
    if (Platform.isMacOS) {
      return MacosInvitePresenter().present();
    }
    if (Platform.isWindows) {
      return WindowsInvitePresenter().present();
    }
    if (Platform.isIOS) {
      return IosInvitePresenter().present();
    }
    return Future<void>.value();
  }
}

List<int> _defaultAdvert() => const ProximityAdvert(
  hasWifi: false,
  ipv4: [0, 0, 0, 0],
  port: 0,
  shortPeerId: [0, 0, 0, 0],
  role: AdvertRole.none,
  groupId: [0, 0, 0, 0],
).pack();

List<int> _defaultScan() => const [];

class _RecordingNetwork implements PrivateNetworkPort {
  _RecordingNetwork(this.inner);
  final PrivateNetworkPort inner;
  HotspotCredentials? last;

  @override
  Future<HotspotCredentials> startHotspot() async {
    final creds = await inner.startHotspot();
    last = creds;
    return creds;
  }

  @override
  Future<void> stopHotspot() => inner.stopHotspot();

  @override
  Future<HotspotCredentials> startWifiDirect() async {
    final creds = await inner.startWifiDirect();
    last = creds;
    return creds;
  }

  @override
  Future<void> stopWifiDirect() => inner.stopWifiDirect();

  @override
  Future<void> join({
    required String ssid,
    required String passphrase,
    required WifiSecurity security,
    required bool localOnly,
    WifiJoinStyle style = WifiJoinStyle.panel,
  }) {
    return inner.join(
      ssid: ssid,
      passphrase: passphrase,
      security: security,
      localOnly: localOnly,
      style: style,
    );
  }

  @override
  Future<void> leaveJoined() => inner.leaveJoined();
}
