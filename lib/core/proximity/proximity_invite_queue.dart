import 'proximity_types.dart';

class InviteRequest {
  InviteRequest({
    required this.id,
    required this.initiatorFingerprint,
    required this.targetFingerprint,
    required this.code,
    required this.enqueuedAt,
  });
  final String id;
  final String initiatorFingerprint;
  final String targetFingerprint;
  final String code;
  final DateTime enqueuedAt;
}

class InviteQueue {
  InviteQueue({this.timeout = const Duration(seconds: 60)});
  final Duration timeout;

  InviteRequest? _active;
  final List<InviteRequest> _waiting = [];

  InviteRequest? get active => _active;
  List<InviteRequest> get waiting => List.unmodifiable(_waiting);

  void enqueue(InviteRequest request) {
    if (_active == null) {
      _active = request;
      return;
    }
    _waiting.add(request);
  }

  TrustDecision acceptActive() {
    final current = _requireActive();
    _promoteNext();
    return TrustDecision.mutual(
      localFingerprint: current.initiatorFingerprint,
      remoteFingerprint: current.targetFingerprint,
    );
  }

  TrustDecision declineActive() {
    _requireActive();
    _promoteNext();
    return const TrustDecision.none();
  }

  TrustDecision? tick(DateTime now) {
    final current = _active;
    if (current == null) {
      return null;
    }
    if (now.isBefore(current.enqueuedAt.add(timeout))) {
      return null;
    }
    _promoteNext();
    return const TrustDecision.none();
  }

  InviteRequest _requireActive() {
    final current = _active;
    if (current == null) {
      throw StateError('no active invite');
    }
    return current;
  }

  void _promoteNext() {
    if (_waiting.isEmpty) {
      _active = null;
      return;
    }
    _active = _waiting.removeAt(0);
  }
}
