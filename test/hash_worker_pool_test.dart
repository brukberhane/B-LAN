import 'package:blan/core/indexing/hash_worker_pool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaultHashWorkerCount is at least 1', () {
    expect(defaultHashWorkerCount(), greaterThanOrEqualTo(1));
  });
}
