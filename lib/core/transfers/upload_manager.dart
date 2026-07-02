import 'dart:async';

import 'package:shelf/shelf.dart';

import '../persistence/database.dart';

/// Tracks outgoing uploads, enforces concurrency, and meters bandwidth.
class UploadManager {
  UploadManager(this._db);

  final AppDatabase _db;
  int _activeSlots = 0;
  int _maxSlots = 4;

  Future<void> refreshLimits() async {
    _maxSlots = await _db.maxUploadChunks();
  }

  Future<bool> tryAcquireSlot() async {
    await refreshLimits();
    if (_activeSlots >= _maxSlots) {
      return false;
    }
    _activeSlots++;
    return true;
  }

  void releaseSlot() {
    if (_activeSlots > 0) {
      _activeSlots--;
    }
  }

  String? peerIdFromToken(String? authHeader, String? browserToken) {
    if (authHeader == null) {
      return null;
    }
    final token = authHeader.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    if (browserToken != null && token == browserToken) {
      return null;
    }
    final underscore = token.lastIndexOf('_');
    if (underscore <= 0) {
      return null;
    }
    return token.substring(0, underscore);
  }

  String? remoteAddress(Request request) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded.split(',').first.trim();
    }
    return request.headers['host'];
  }

  Future<int> startUpload({
    String? peerId,
    String? remoteAddress,
    String? entryId,
    String? chunkHash,
    required int bytesTotal,
  }) =>
      _db.createUploadTransfer(
        peerId: peerId,
        remoteAddress: remoteAddress,
        entryId: entryId,
        chunkHash: chunkHash,
        bytesTotal: bytesTotal,
      );

  Stream<List<int>> wrapStream({
    required Stream<List<int>> source,
    required int transferId,
    required int bytesTotal,
    required int bandwidthBps,
  }) async* {
    var sent = 0;
    var budgetUsed = 0;
    var windowStart = DateTime.now();
    try {
      await for (final chunk in source) {
        if (bandwidthBps > 0) {
          budgetUsed += chunk.length;
          final elapsedMs =
              DateTime.now().difference(windowStart).inMilliseconds;
          final allowed = (bandwidthBps * elapsedMs) ~/ 1000;
          if (budgetUsed > allowed) {
            final over = budgetUsed - allowed;
            final delayMs = (over * 1000) ~/ bandwidthBps;
            if (delayMs > 0) {
              await Future<void>.delayed(Duration(milliseconds: delayMs));
            }
          }
        }
        sent += chunk.length;
        if (sent % 65536 < chunk.length || sent >= bytesTotal) {
          await _db.updateTransferProgress(transferId, sent);
        }
        yield chunk;
      }
      await _db.completeTransfer(transferId, sent);
    } catch (error) {
      await _db.failTransfer(transferId, '$error');
      rethrow;
    } finally {
      releaseSlot();
    }
  }

  Response streamResponse({
    required Stream<List<int>> body,
    required int transferId,
    required int bytesTotal,
    required int bandwidthBps,
    required Map<String, String> headers,
    int statusCode = 200,
  }) {
    final wrapped = wrapStream(
      source: body,
      transferId: transferId,
      bytesTotal: bytesTotal,
      bandwidthBps: bandwidthBps,
    );
    return Response(statusCode, body: wrapped, headers: headers);
  }
}
