import 'package:blan/core/discovery/mdns_service_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeMdnsServiceName strips invalid chars', () {
    expect(
      sanitizeMdnsServiceName(
        'My PC #1',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      ),
      'My-PC-1-aaaaaaaa',
    );
  });

  test('sanitizeMdnsServiceName falls back when nick empty', () {
    expect(
      sanitizeMdnsServiceName('!!!', 'peer-id-123'),
      'blan-peerid12',
    );
  });
}
