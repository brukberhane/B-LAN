import '../persistence/database.dart';

/// Picks chunk download peers by trust, failures, and recent speed.
class ChunkSourceScheduler {
  ChunkSourceScheduler(this._peers);

  final List<Peer> _peers;
  final Map<String, int> _failureCounts = {};
  final Map<String, List<Duration>> _recentDurations = {};

  List<Peer> rankedPeers({Set<String> excludePeerIds = const {}}) {
    final available =
        _peers.where((peer) => !excludePeerIds.contains(peer.id)).toList();
    available.sort((a, b) {
      final trust = (b.trusted ? 1 : 0) - (a.trusted ? 1 : 0);
      if (trust != 0) {
        return trust;
      }
      final failures =
          (_failureCounts[a.id] ?? 0).compareTo(_failureCounts[b.id] ?? 0);
      if (failures != 0) {
        return failures;
      }
      return _averageMillis(a.id).compareTo(_averageMillis(b.id));
    });
    return available;
  }

  void recordSuccess(String peerId, Duration elapsed) {
    _failureCounts.putIfAbsent(peerId, () => 0);
    final samples = _recentDurations.putIfAbsent(peerId, () => <Duration>[]);
    samples.add(elapsed);
    if (samples.length > 8) {
      samples.removeAt(0);
    }
  }

  void recordFailure(String peerId, {bool hashMismatch = false}) {
    final penalty = hashMismatch ? 2 : 1;
    _failureCounts[peerId] = (_failureCounts[peerId] ?? 0) + penalty;
  }

  int _averageMillis(String peerId) {
    final samples = _recentDurations[peerId];
    if (samples == null || samples.isEmpty) {
      return 1 << 30;
    }
    final total = samples.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return total ~/ samples.length;
  }
}
