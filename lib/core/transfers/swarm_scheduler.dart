import '../persistence/database.dart';

/// One peer that can serve a specific chunk hash.
class SwarmChunkCandidate {
  const SwarmChunkCandidate({
    required this.sourceId,
    required this.peer,
    required this.shareId,
    required this.entryId,
    required this.hash,
    required this.chunkIndex,
    required this.offset,
    required this.length,
    this.trusted = false,
    this.failureCount = 0,
    this.avgLatencyMs,
    this.avgBytesPerSecond,
    this.lastSuccessAt,
  });

  final int sourceId;
  final Peer peer;
  final String shareId;
  final String entryId;
  final String hash;
  final int chunkIndex;
  final int offset;
  final int length;
  final bool trusted;
  final int failureCount;
  final int? avgLatencyMs;
  final int? avgBytesPerSecond;
  final DateTime? lastSuccessAt;

  String get sourceKey => '${peer.id}:$entryId:$hash';
}

/// Rarest-first chunk scheduling with per-peer concurrency caps.
class SwarmScheduler {
  SwarmScheduler(
    Map<int, List<SwarmChunkCandidate>> candidatesByIndex, {
    this.maxChunksPerPeer = 2,
  }) : _candidatesByIndex = {
          for (final entry in candidatesByIndex.entries)
            entry.key: List<SwarmChunkCandidate>.from(entry.value),
        };

  final Map<int, List<SwarmChunkCandidate>> _candidatesByIndex;
  final int maxChunksPerPeer;
  final Map<String, int> _inFlightByPeer = {};
  final Map<String, int> _runtimeFailures = {};
  final Map<String, List<Duration>> _recentDurations = {};

  List<int> sortPendingChunkIndices(Iterable<int> indices) {
    final list = indices.toList()
      ..sort((a, b) {
        final rarityA = _candidatesByIndex[a]?.length ?? 0;
        final rarityB = _candidatesByIndex[b]?.length ?? 0;
        if (rarityA != rarityB) {
          return rarityA.compareTo(rarityB);
        }
        return a.compareTo(b);
      });
    return list;
  }

  int rarityForChunk(int chunkIndex) => _candidatesByIndex[chunkIndex]?.length ?? 0;

  SwarmChunkCandidate? pickCandidate(
    int chunkIndex, {
    Set<String> excludeSourceKeys = const {},
  }) {
    final candidates = [...?_candidatesByIndex[chunkIndex]];
    candidates.sort((a, b) => _score(b).compareTo(_score(a)));
    for (final candidate in candidates) {
      if (excludeSourceKeys.contains(candidate.sourceKey)) {
        continue;
      }
      final inFlight = _inFlightByPeer[candidate.peer.id] ?? 0;
      if (inFlight >= maxChunksPerPeer) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  void beginFetch(String peerId) {
    _inFlightByPeer[peerId] = (_inFlightByPeer[peerId] ?? 0) + 1;
  }

  void endFetch(String peerId) {
    final next = (_inFlightByPeer[peerId] ?? 1) - 1;
    if (next <= 0) {
      _inFlightByPeer.remove(peerId);
    } else {
      _inFlightByPeer[peerId] = next;
    }
  }

  void recordSuccess(String peerId, Duration elapsed) {
    _runtimeFailures.putIfAbsent(peerId, () => 0);
    final samples = _recentDurations.putIfAbsent(peerId, () => <Duration>[]);
    samples.add(elapsed);
    if (samples.length > 8) {
      samples.removeAt(0);
    }
  }

  void recordFailure(String peerId, {bool hashMismatch = false}) {
    final penalty = hashMismatch ? 3 : 1;
    _runtimeFailures[peerId] = (_runtimeFailures[peerId] ?? 0) + penalty;
  }

  int _score(SwarmChunkCandidate candidate) {
    var score = 0;
    if (candidate.trusted) {
      score += 1000;
    }
    score -= candidate.failureCount * 50;
    score -= (_runtimeFailures[candidate.peer.id] ?? 0) * 40;
    final latency = candidate.avgLatencyMs ?? _averageMillis(candidate.peer.id);
    score -= latency ~/ 10;
    final speed = candidate.avgBytesPerSecond ?? 0;
    score += speed ~/ 1024;
    if (candidate.lastSuccessAt != null) {
      score += 10;
    }
    score -= (_inFlightByPeer[candidate.peer.id] ?? 0) * 25;
    return score;
  }

  int _averageMillis(String peerId) {
    final samples = _recentDurations[peerId];
    if (samples == null || samples.isEmpty) {
      return 1 << 20;
    }
    final total = samples.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return total ~/ samples.length;
  }
}
