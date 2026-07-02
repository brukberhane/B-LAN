import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/transfers/swarm_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

Peer _peer(String id, {bool trusted = false}) => Peer(
      id: id,
      nick: id,
      host: '127.0.0.1',
      port: 1,
      fingerprint: null,
      trusted: trusted,
      identityStatus: 'normal',
      lastSeen: DateTime.now(),
      manual: true,
    );

SwarmChunkCandidate _candidate({
  required int sourceId,
  required Peer peer,
  required int chunkIndex,
  String hash = 'hash',
}) =>
    SwarmChunkCandidate(
      sourceId: sourceId,
      peer: peer,
      shareId: 'share',
      entryId: 'entry-$sourceId',
      hash: '$hash-$chunkIndex',
      chunkIndex: chunkIndex,
      offset: chunkIndex * 5,
      length: 5,
      trusted: peer.trusted,
    );

void main() {
  test('sortPendingChunkIndices prefers rarest chunks first', () {
    final scheduler = SwarmScheduler({
      0: [
        _candidate(sourceId: 1, peer: _peer('a'), chunkIndex: 0),
        _candidate(sourceId: 2, peer: _peer('b'), chunkIndex: 0),
      ],
      1: [_candidate(sourceId: 3, peer: _peer('c'), chunkIndex: 1)],
      2: [
        _candidate(sourceId: 4, peer: _peer('d'), chunkIndex: 2),
        _candidate(sourceId: 5, peer: _peer('e'), chunkIndex: 2),
        _candidate(sourceId: 6, peer: _peer('f'), chunkIndex: 2),
      ],
    });

    expect(scheduler.sortPendingChunkIndices([2, 0, 1]), [1, 0, 2]);
  });

  test('pickCandidate respects per-peer concurrency cap', () {
    final peer = _peer('fast');
    final scheduler = SwarmScheduler(
      {
        0: [_candidate(sourceId: 1, peer: peer, chunkIndex: 0)],
        1: [_candidate(sourceId: 2, peer: peer, chunkIndex: 1)],
        2: [_candidate(sourceId: 3, peer: peer, chunkIndex: 2)],
      },
      maxChunksPerPeer: 1,
    );

    final first = scheduler.pickCandidate(0);
    expect(first, isNotNull);
    scheduler.beginFetch(peer.id);

    expect(scheduler.pickCandidate(1), isNull);
    scheduler.endFetch(peer.id);
    expect(scheduler.pickCandidate(1), isNotNull);
  });

  test('trusted peer outranks untrusted peer for same chunk', () {
    final trusted = _peer('trusted', trusted: true);
    final untrusted = _peer('other');
    final scheduler = SwarmScheduler({
      0: [
        _candidate(sourceId: 1, peer: untrusted, chunkIndex: 0),
        _candidate(sourceId: 2, peer: trusted, chunkIndex: 0),
      ],
    });

    expect(scheduler.pickCandidate(0)?.peer.id, 'trusted');
  });
}
