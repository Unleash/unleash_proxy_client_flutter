import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'dart:async';

// todo: test rejecting invalid URLs

void main() {
  test('sample usage of Unleash client', () async {
    final unleash = UnleashClient(
      url: 'https://app.unleash-hosted.com/demo/api/proxy',
      clientKey: 'proxy-123',
      appName: 'flutter-test',
    );

    expect(unleash.isEnabled('flutter-on'), false);
    expect(unleash.isEnabled('flutter-off'), false);

    final completer = Completer<void>();
    unleash.on('ready', (String message) {
      completer.complete();
    });

    unleash.start();
    await completer.future;

    expect(unleash.isEnabled('flutter-on'), true);
    expect(unleash.isEnabled('flutter-off'), false);
  });
}
