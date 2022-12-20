import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unleash_proxy_client_flutter/in_memory_storage_provider.dart';
import 'package:unleash_proxy_client_flutter/shared_preferences_storage_provider.dart';
import 'package:unleash_proxy_client_flutter/unleash_context.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';

const mockData = '''{ 
     "toggles": [
      { "name": "flutter-on", "enabled": true, "impressionData": false, "variant": { "enabled": false, "name": "disabled" } }, 
      { "name": "flutter-off", "enabled": false, "impressionData": false, "variant": { "enabled": true, "name": "flutter-off-variant" } }
     ] 
  }''';

// todo: test rejecting invalid URLs

class GetMock {
  var calledTimes = 0;
  var calledWith = [];
  var calledWithUrls = [];
  String body;
  int status;
  Map<String, String> headers;

  GetMock({this.body = mockData, this.status = 200, this.headers = const {}});

  Future<Response> call(Request request) async {
    calledTimes++;
    calledWith.add([request.url, request.headers]);
    calledWithUrls.add(request.url);

    return Response(mockData, status, headers: headers);
  }
}

String generateSessionId() {
  return '1234';
}

class FailingGetMock {
  Exception error;

  FailingGetMock(this.error);

  Future<Response> call(Request request) async {
    throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var url = Uri.parse('https://app.unleash-hosted.com/demo/api/proxy');

  test('can fetch initial toggles with ready', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    expect(unleash.isEnabled('flutter-on'), false);
    expect(unleash.isEnabled('flutter-off'), false);

    final completer = Completer<void>();
    // Ready should be registered before we start the client.
    unleash.on('ready', (dynamic _) {
      completer.complete();
    });

    unleash.start();
    await completer.future;
    unleash.stop();

    expect(unleash.isEnabled('flutter-on'), true);
    expect(unleash.isEnabled('flutter-off'), false);
    expect(getMock.calledTimes, 1);
  });

  test('emits update event on initial data fetch', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    var count = 0;
    unleash.on('update', (dynamic _) {
      count += 1;
    });

    await unleash.start();

    expect(count, 1);
  });

  test('store session id in storage', () async {
    var getMock = GetMock();
    var storageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        sessionIdGenerator: generateSessionId,
        fetcher: getMock);

    await unleash.start();

    var sessionId = await storageProvider.get('sessionId');
    expect(sessionId, '1234');
  });

  test('get session id from storage', () async {
    var getMock = GetMock();
    var storageProvider = InMemoryStorageProvider();
    await storageProvider.save('sessionId', '5678');
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        sessionIdGenerator: generateSessionId,
        fetcher: getMock);

    await unleash.start();

    expect(getMock.calledWithUrls, [
      Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=5678')
    ]);
  });

  test('should not emit update on 304', () async {
    var getMock = GetMock(status: 304);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    var count = 0;
    unleash.on('update', (dynamic _) {
      count += 1;
    });

    await unleash.start();

    expect(count, 0);
  });

  test('should emit error on error HTTP codes', () async {
    var getMock = GetMock(status: 400);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    final completer = Completer<dynamic>();
    unleash.on('error', (dynamic event) {
      completer.complete(event);
    });

    unleash.start();

    var value = await completer.future;

    expect(value, {
      'type': 'HttpError',
      'code': 400,
    });
  });

  test('should emit error on failing HTTP client', () async {
    var exception = Exception('unexpected exception');
    var getMock = FailingGetMock(exception);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    final completer = Completer<dynamic>();
    unleash.on('error', (dynamic event) {
      completer.complete(event);
    });

    unleash.start();

    var value = await completer.future;

    expect(value, exception);
  });

  test('should only call ready event once', () async {
    var count = 0;
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    // Ready should be registered before we start the client.
    unleash.on('ready', (dynamic _) {
      count += 1;
    });

    await unleash.start();
    await unleash.start();

    expect(count, 1);
  });

  test('can fetch initial toggles with await', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
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
    var getMock = GetMock();
    var storageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock,
        storageProvider: storageProvider);

    await unleash.start();
    var result = await storageProvider.get('unleash_repo');

    expect(result, mockData);
  });

  test('can read initial toggles from in memory storage', () async {
    var getMock = GetMock();
    var storageProvider = InMemoryStorageProvider();
    await storageProvider.save('unleash_repo', mockData);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock,
        storageProvider: storageProvider);

    expect(unleash.isEnabled('flutter-on'), false);

    final completer = Completer<void>();
    unleash.on('initialized', (dynamic _) {
      completer.complete();
    });
    await completer.future;

    expect(unleash.isEnabled('flutter-on'), true);
    expect(getMock.calledTimes, 0);
  });

  test('can store toggles in shared preferences', () async {
    SharedPreferences.setMockInitialValues({});
    var getMock = GetMock();
    var storageProvider = await SharedPreferencesStorageProvider.init();
    final unleash = UnleashClient(
        url: url,
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
      var getMock = GetMock();
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          fetcher: getMock);

      var updateEventCount = 0;
      unleash.on('update', (dynamic _) {
        updateEventCount += 1;
      });

      unleash.start();
      expect(getMock.calledTimes, 0);
      async.elapse(const Duration(seconds: 9));
      expect(getMock.calledTimes, 1);
      async.elapse(const Duration(seconds: 1));
      expect(getMock.calledTimes, 2);
      expect(updateEventCount, 2);
    });
  });

  test('stopping client should cancel the timer', () async {
    fakeAsync((async) {
      var getMock = GetMock();
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          fetcher: getMock);

      unleash.start();
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
      // first stop cancels the timer
      unleash.stop();
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
      // second stop should be no-op
      unleash.stop();
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
    });
  });

  test('can update context', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        fetcher: getMock);

    await unleash.start();
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 2);
    expect(getMock.calledWithUrls, [
      Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&customKey=customValue')
    ]);
  });

  test('update context should wait on asynchronous start', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        fetcher: getMock);

    unleash.start();
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 2);
    expect(getMock.calledWithUrls, [
      Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&customKey=customValue')
    ]);
  });

  test('update context should not invoke HTTP without start', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);

    unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 0);
  });

  test('should encode query parameters', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        fetcher: getMock);

    await unleash.start();
    await unleash.updateContext(UnleashContext(
        userId: '123??',
        remoteAddress: '192.168.0.10',
        sessionId: 'session',
        properties: {'custom?Key': 'customValue?'}));

    expect(getMock.calledWithUrls, [
      Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123%3F%3F&remoteAddress=192.168.0.10&sessionId=session&custom%3FKey=customValue%3F')
    ]);
  });

  test('interval should pick settings from update context', () async {
    fakeAsync((async) {
      var getMock = GetMock();
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          sessionIdGenerator: generateSessionId,
          fetcher: getMock);

      unleash.start();
      unleash.updateContext(UnleashContext(userId: '123'));
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledWithUrls, [
        Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
        Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?userId=123&sessionId=1234'),
        Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?userId=123&sessionId=1234')
      ]);
    });
  });

  test('should store ETag locally', () async {
    fakeAsync((async) {
      var getMock =
          GetMock(body: mockData, status: 200, headers: {'ETag': 'ETagValue'});
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          sessionIdGenerator: generateSessionId,
          fetcher: getMock);

      unleash.start();
      async.elapse(const Duration(seconds: 10));

      expect(getMock.calledWith, [
        [
          Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'Authorization': 'proxy-123',
          }
        ],
        [
          Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'Authorization': 'proxy-123',
            'If-None-Match': 'ETagValue'
          }
        ]
      ]);
    });
  });

  test('should not store ETag on codes other than 200', () async {
    fakeAsync((async) {
      var getMock = GetMock(
          body: mockData, status: 500, headers: {'ETag': 'ETagValueIgnore'});
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          sessionIdGenerator: generateSessionId,
          fetcher: getMock);

      unleash.start();
      async.elapse(const Duration(seconds: 10));

      expect(getMock.calledWith, [
        [
          Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'Authorization': 'proxy-123',
          }
        ],
        [
          Uri.parse('https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'Authorization': 'proxy-123',
          }
        ]
      ]);
    });
  });

  test('can get default variant from API', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);
    await unleash.start();

    var variant = unleash.getVariant('flutter.on');

    expect(variant, Variant(name: 'disabled', enabled: false));
  });

  test('can get default variant for non-existent toggle', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);
    await unleash.start();

    var variant = unleash.getVariant('non.existent.toggle');

    expect(variant, Variant(name: 'disabled', enabled: false));
  });

  test('can get variant', () async {
    var getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock);
    await unleash.start();

    var variant = unleash.getVariant('flutter-off');

    expect(variant, Variant(name: 'flutter-off-variant', enabled: true));
  });
}
