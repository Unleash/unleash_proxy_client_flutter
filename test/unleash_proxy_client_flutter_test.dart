import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'dart:async';
import 'package:fake_async/fake_async.dart';

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
  var calledWith = [];

  Future<dynamic> call(Uri url, String clientKey) async {
    var data = '''{ 
     "toggles": [
      { "name": "flutter-on", "enabled": true, "impressionData": false }, 
      { "name": "flutter-off", "enabled": false, "impressionData": false }
     ] 
  }''';
    calledTimes++;
    calledWith.add([url, clientKey]);

    return data;
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
    unleash.stop();

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
    unleash.stop();

    expect(unleash.isEnabled('flutter-on'), true);
    expect(unleash.isEnabled('flutter-off'), false);
    expect(getMock.calledTimes, 1);
  });

  test('can refetch toggles at a regular interval', () async {
    fakeAsync((async) {
      var getMock = new GetMock();
      final unleash = UnleashClient(
          url: 'https://app.unleash-hosted.com/demo/api/proxy',
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          fetcher: getMock);

      unleash.start();
      expect(getMock.calledTimes, 1);
      async.elapse(Duration(seconds: 9));
      expect(getMock.calledTimes, 1);
      async.elapse(Duration(seconds: 1));
      expect(getMock.calledTimes, 2);
    });
  });

  test('stopping client should cancel the timer', () async {
    fakeAsync((async) {
      var getMock = new GetMock();
      final unleash = UnleashClient(
          url: 'https://app.unleash-hosted.com/demo/api/proxy',
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          fetcher: getMock);

      unleash.start();
      async.elapse(Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
      // first stop cancels the timer
      unleash.stop();
      async.elapse(Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
      // second stop should be no-op
      unleash.stop();
      async.elapse(Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
    });
  });

  test('can update context', () async {
    var getMock = new GetMock();
    final unleash = UnleashClient(
        url: 'https://app.unleash-hosted.com/demo/api/proxy',
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    await unleash.start();
    await unleash.updateContext(UnleashContext(userId: '123', remoteAddress: 'address', sessionId: 'session', properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 2);
    expect(getMock.calledWith, [
      [Uri.parse('https://app.unleash-hosted.com/demo/api/proxy'), 'proxy-123'],
      [Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&customKey=customValue'), 'proxy-123']
    ]);
  });
}
