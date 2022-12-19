import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unleash_proxy_client_flutter/in_memory_storage_provider.dart';
import 'package:unleash_proxy_client_flutter/shared_preferences_storage_provider.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'dart:async';
import 'package:fake_async/fake_async.dart';

const mockData = '''{ 
     "toggles": [
      { "name": "flutter-on", "enabled": true, "impressionData": false }, 
      { "name": "flutter-off", "enabled": false, "impressionData": false }
     ] 
  }''';

// todo: test rejecting invalid URLs
Future<dynamic> getMock(Uri url, String clientKey) async {
  final completer = Completer<String>();

  completer.complete(mockData);
}

class GetMock {
  var calledTimes = 0;
  var calledWith = [];

  Future<dynamic> call(Uri url, String clientKey) async {
    calledTimes++;
    calledWith.add([url, clientKey]);

    return mockData;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('can store toggles in memory storage', () async {
    var getMock = new GetMock();
    var storageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: 'https://app.unleash-hosted.com/demo/api/proxy',
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock,
        storageProvider: storageProvider);

    await unleash.start();
    var result = await storageProvider.get('unleash_repo');

    expect(result, mockData);
  });

  test('can store toggles in shared preferences', () async {
    SharedPreferences.setMockInitialValues({});
    var getMock = new GetMock();
    var storageProvider = await SharedPreferencesStorageProvider.init();
    final unleash = UnleashClient(
        url: 'https://app.unleash-hosted.com/demo/api/proxy',
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock,
        storageProvider: storageProvider);

    await unleash.start();
    var result = await storageProvider.get('unleash_repo');

    expect(result, mockData);
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

  test('interval should pick settings from update context', () async {
    fakeAsync((async) {
      var getMock = new GetMock();
      final unleash = UnleashClient(
          url: 'https://app.unleash-hosted.com/demo/api/proxy',
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          fetcher: getMock);

      unleash.start();
      unleash.updateContext(UnleashContext(userId: '123'));
      async.elapse(Duration(seconds: 10));
      expect(getMock.calledWith, [
        [Uri.parse('https://app.unleash-hosted.com/demo/api/proxy'), 'proxy-123'],
        [Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?userId=123'), 'proxy-123'],
        [Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?userId=123'), 'proxy-123']
      ]);

    });
  });
}
