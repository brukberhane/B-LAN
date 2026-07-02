import 'dart:io';

import 'package:blan/core/persistence/db_benchmark_runner.dart';

Future<void> main(List<String> args) async {
  final quick = args.contains('--quick');
  final inMemory = !args.contains('--file');
  final scale = quick ? DbBenchmarkScale.quick : DbBenchmarkScale.full;

  String? filePath;
  if (!inMemory) {
    final dir = await Directory.systemTemp.createTemp('blan-db-bench-run');
    filePath = '${dir.path}/bench.db';
    stderr.writeln('Using temp db file: $filePath');
  }

  final runner = DbBenchmarkRunner(
    scale: scale,
    inMemory: inMemory,
    filePath: filePath,
  );

  stderr.writeln(
    'Running ${quick ? 'quick' : 'full'} SQLite benchmark '
    '(${scale.entryCount} entries, ${scale.totalChunks} chunks)...',
  );

  final report = await runner.run();
  stdout.writeln(report.toJsonString());
}
