import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'chunker.dart';
import 'hash_isolate.dart';
import 'hash_messages.dart';

int defaultHashWorkerCount() => Platform.isAndroid ? 1 : 2;

/// Fixed pool of isolates that hash files off the UI thread.
///
/// On Android, hashing runs in-process because worker isolates cannot reliably
/// open SAF-backed file paths.
class HashWorkerPool {
  HashWorkerPool({int? workerCount, bool? hashInProcess})
      : _workerCount = workerCount ?? defaultHashWorkerCount(),
        _hashInProcess = hashInProcess ?? Platform.isAndroid;

  final int _workerCount;
  final bool _hashInProcess;
  final List<Isolate> _isolates = [];
  final List<SendPort> _workerPorts = [];
  var _nextWorker = 0;
  var _nextJobId = 0;
  var _started = false;

  int get workerCount => _workerCount;

  Future<void> start() async {
    if (_started) {
      return;
    }
    if (_hashInProcess) {
      _started = true;
      return;
    }
    for (var i = 0; i < _workerCount; i++) {
      final initPort = ReceivePort();
      final isolate = await Isolate.spawn(hashWorkerMain, initPort.sendPort);
      _isolates.add(isolate);
      _workerPorts.add(await initPort.first as SendPort);
      initPort.close();
    }
    _started = true;
  }

  Future<List<ChunkDescriptor>> hashFile({
    required String path,
    required int chunkSize,
    void Function(int hashedBytes, int totalBytes)? onProgress,
  }) async {
    if (!_started) {
      throw StateError('HashWorkerPool not started');
    }

    if (_hashInProcess) {
      final file = File(path);
      if (!await file.exists()) {
        throw StateError('missing');
      }
      return hashFileChunks(
        file: file,
        chunkSize: chunkSize,
        onProgress: onProgress,
      );
    }

    if (_workerPorts.isEmpty) {
      throw StateError('HashWorkerPool not started');
    }

    final jobId = _nextJobId++;
    final replyPort = ReceivePort();
    final completer = Completer<List<ChunkDescriptor>>();
    late final StreamSubscription<dynamic> sub;

    sub = replyPort.listen((message) {
      if (message is HashProgress && message.jobId == jobId) {
        onProgress?.call(message.hashedBytes, message.totalBytes);
        return;
      }
      if (message is HashComplete && message.jobId == jobId) {
        sub.cancel();
        replyPort.close();
        if (message.error != null) {
          completer.completeError(StateError(message.error!));
        } else {
          completer.complete(message.chunks);
        }
      }
    });

    final worker = _workerPorts[_nextWorker];
    _nextWorker = (_nextWorker + 1) % _workerPorts.length;
    worker.send(
      HashJob(
        jobId: jobId,
        path: path,
        chunkSize: chunkSize,
        replyPort: replyPort.sendPort,
      ),
    );

    return completer.future;
  }

  Future<void> dispose() async {
    for (final port in _workerPorts) {
      port.send(const HashShutdown());
    }
    for (final isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    _isolates.clear();
    _workerPorts.clear();
    _started = false;
  }
}
