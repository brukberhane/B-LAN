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
    _promoteNext(DateTime.now());
    return TrustDecision.mutual(
      localFingerprint: current.initiatorFingerprint,
      remoteFingerprint: current.targetFingerprint,
    );
  }

  TrustDecision declineActive() {
    _requireActive();
    _promoteNext(DateTime.now());
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
    _promoteNext(now);
    return const TrustDecision.none();
  }

  InviteRequest _requireActive() {
    final current = _active;
    if (current == null) {
      throw StateError('no active invite');
    }
    return current;
  }

  void _promoteNext(DateTime now) {
    if (_waiting.isEmpty) {
      _active = null;
      return;
    }
    final next = _waiting.removeAt(0);
    _active = InviteRequest(
      id: next.id,
      initiatorFingerprint: next.initiatorFingerprint,
      targetFingerprint: next.targetFingerprint,
      code: next.code,
      enqueuedAt: now,
    );
  }
}
