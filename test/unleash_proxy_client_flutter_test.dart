import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'dart:async';

// todo: test rejecting invalid URLs
Future<dynamic> getMock(Uri url, String clientKey) async {
  final completer = Completer<String>();

  var data = '''{ 
     "toggles": [
      { "name": "flutter-on", "enabled": true, "impressionData": false }, 
      { "name": "flutter-off", "enabled": false, "impressionData": false }, 
     ] 
  }''';

  completer.complete(data);
}

class GetMock {
  var calledTimes = 0;

  Future<dynamic> call(Uri url, String clientKey) async {
    var data = '''{ 
     "toggles": [
      { "name": "flutter-on", "enabled": true, "impressionData": false }, 
      { "name": "flutter-off", "enabled": false, "impressionData": false }
     ] 
  }''';
    calledTimes++;

    return  data;
  }
}

void main() {
  test('can fetch initial toggles with ready', () async {
    var getMock = new GetMock();
    final unleash = UnleashClient(
        url: 'https://app.unleash-hosted.com/demo/api/proxy',
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

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
    expect(getMock.calledTimes, 1);
  });

  test('can fetch initial toggles with await', () async {
    var getMock = new GetMock();
    final unleash = UnleashClient(
        url: 'https://app.unleash-hosted.com/demo/api/proxy',
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    await unleash.start();

    expect(unleash.isEnabled('flutter-on'), true);
    expect(unleash.isEnabled('flutter-off'), false);
    expect(getMock.calledTimes, 1);
  });
}
