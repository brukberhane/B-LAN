import 'package:blan/core/protocol/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HelloResponse roundtrip', () {
    const original = HelloResponse(
      protocolVersion: 1,
      peerId: 'peer-1',
      nick: 'test',
      fingerprint: 'abcd',
      capabilities: ['browse'],
    );
    final decoded = HelloResponse.fromJson(original.toJson());
    expect(decoded.peerId, original.peerId);
    expect(decoded.nick, original.nick);
    expect(decoded.capabilities, original.capabilities);
  });
}
