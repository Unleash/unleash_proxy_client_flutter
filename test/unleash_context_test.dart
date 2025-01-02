import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/unleash_context.dart';

void main() {
  test('returns consistent key for same values', () {
    final context1 = UnleashContext(
        userId: 'user1',
        sessionId: 'session1',
        remoteAddress: '192.168.1.1',
        properties: {'key1': 'value1'}
    );

    expect(context1.getKey(), "dXNlcklkPXVzZXIxO3Nlc3Npb25JZD1zZXNzaW9uMTtyZW1vdGVBZGRyZXNzPTE5Mi4xNjguMS4xO2tleTE9dmFsdWUxOw==");
  });
}
