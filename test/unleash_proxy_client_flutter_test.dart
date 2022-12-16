import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'dart:async';

void main() {
  test('sample usage of Unleash client', () async {
    final unleash = UnleashClient(
      url: 'https://eu.unleash-hosted.com/hosted/proxy',
      clientKey: 'your-proxy-key',
      appName: 'my-webapp',
    );

    final completer = Completer<void>();
    unleash.on('ready', (String message) {
      if (unleash.isEnabled('proxy.demo')) {
        print('proxy.demo is enabled');
        expect(true, false);
      } else {
        print('proxy.demo is disabled');
        expect(true, true);
      }
      completer.complete();
    });

    unleash.start();
    await completer.future;
  });
}
