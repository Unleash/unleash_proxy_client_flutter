import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';

void main() {
  test('sample usage of Unleash client', () {
    final unleash = UnleashClient(
      url: 'https://eu.unleash-hosted.com/hosted/proxy',
      clientKey: 'your-proxy-key',
      appName: 'my-webapp',
    );

    unleash.start();
  });
}
