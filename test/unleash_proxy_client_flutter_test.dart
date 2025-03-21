import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unleash_proxy_client_flutter/in_memory_storage_provider.dart';
import 'package:unleash_proxy_client_flutter/payload.dart';
import 'package:unleash_proxy_client_flutter/shared_preferences_storage_provider.dart';
import 'package:unleash_proxy_client_flutter/toggle_config.dart';
import 'package:unleash_proxy_client_flutter/unleash_context.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';

const mockData = '''{ 
     "toggles": [
      { "name": "flutter-on", "enabled": true, "impressionData": true, "variant": { "enabled": false, "name": "disabled" } }, 
      { "name": "flutter-off", "enabled": false, "impressionData": false, "variant": { "enabled": false, "name": "flutter-off-variant" } },
      { "name": "flutter-variant", "enabled": true, "impressionData": true, "variant": { "enabled": true, "name": "flutter-variant-value" } },
      { "name": "flutter-variant-payload", "enabled": true, "impressionData":
       true, "variant": { "enabled": true, "name": "flutter-variant", "payload": {"type": "string", "value": "someValue"}
       } }
     ] 
  }''';

// todo: test rejecting invalid URLs

class GetMock {
  var calledTimes = 0;
  final calledWith = [];
  final calledWithUrls = [];
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

class PostMock {
  var calledTimes = 0;
  var calledWith = [];
  var calledWithUrls = [];
  String payload;
  int status;
  Map<String, String> headers;

  PostMock({required this.payload, this.status = 200, this.headers = const {}});

  Future<Response> call(Request request) async {
    calledTimes++;
    calledWith.add([request.url, request.headers, request.body]);
    calledWithUrls.add(request.url);

    return Response(payload, status, headers: headers);
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

const storageKey = 'flutter-test._unleash_repo';
const sessionStorageKey = 'flutter-test._unleash_sessionId';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final url = Uri.parse('https://app.unleash-hosted.com/demo/api/proxy');

  test('can fetch initial toggles with ready', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    expect(unleash.isEnabled('flutter-on'), false);
    expect(unleash.isEnabled('flutter-off'), false);

    final completer = Completer<void>();
    // Ready should be registered before we start the client.
    unleash.on('ready', (_) {
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
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    var count = 0;
    unleash.on('update', (_) {
      count += 1;
    });

    await unleash.start();

    expect(count, 1);
  });

  test('store session id in storage', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        sessionIdGenerator: generateSessionId,
        fetcher: getMock);

    await unleash.start();

    final sessionId = await storageProvider.get(sessionStorageKey);
    expect(sessionId, '1234');
  });

  test('get session id from storage', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    await storageProvider.save(sessionStorageKey, '5678');
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        sessionIdGenerator: generateSessionId,
        fetcher: getMock);

    await unleash.start();

    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?sessionId=5678&appName=flutter-test&environment=default')
    ]);
  });

  test('can set custom headers', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        headerName: 'CustomHeader',
        customHeaders: {
          'CustomHeader': 'CustomHeaderValue',
          'Accept': 'AcceptType',
          'X-Custom': 'CustomExtension'
        },
        storageProvider: InMemoryStorageProvider(),
        sessionIdGenerator: generateSessionId,
        idGenerator: () => '1234',
        sdkName: 'unleash-client-flutter:1.0.0',
        fetcher: getMock);

    await unleash.start();

    expect(getMock.calledWith, [
      [
        Uri.parse(
            'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
        {
          'Accept': 'AcceptType',
          'Cache': 'no-cache',
          'unleash-appname': 'flutter-test',
          'unleash-connection-id': '1234',
          'unleash-sdk': 'unleash-client-flutter:1.0.0',
          'CustomHeader': 'CustomHeaderValue',
          'X-Custom': 'CustomExtension'
        }
      ]
    ]);
  });

  test('can set custom client id header', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        headerName: 'CustomHeader',
        storageProvider: InMemoryStorageProvider(),
        sessionIdGenerator: generateSessionId,
        sdkName: 'unleash-client-flutter:1.0.0',
        idGenerator: () => '1234',
        fetcher: getMock);

    await unleash.start();

    expect(getMock.calledWith, [
      [
        Uri.parse(
            'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
        {
          'Accept': 'application/json',
          'Cache': 'no-cache',
          'unleash-appname': 'flutter-test',
          'unleash-connection-id': '1234',
          'unleash-sdk': 'unleash-client-flutter:1.0.0',
          'CustomHeader': 'proxy-123',
        }
      ]
    ]);
  });

  test('should not emit update on 304', () async {
    final getMock = GetMock(status: 304);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    var count = 0;
    unleash.on('update', (_) {
      count += 1;
    });

    await unleash.start();

    expect(count, 0);
  });

  test('should emit error on error HTTP codes', () async {
    final getMock = GetMock(status: 400);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    final completer = Completer<dynamic>();
    unleash.on('error', (dynamic event) {
      completer.complete(event);
    });

    unleash.start();

    final value = await completer.future;

    expect(value, {
      'type': 'HttpError',
      'code': 400,
    });
  });

  test('should emit error on failing HTTP client', () async {
    final exception = Exception('unexpected exception');
    final getMock = FailingGetMock(exception);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    final completer = Completer<dynamic>();
    unleash.on('error', (dynamic event) {
      completer.complete(event);
    });

    unleash.start();

    final value = await completer.future;

    expect(value, exception);
  });

  test('should only call ready event once', () async {
    var count = 0;
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    // Ready should be registered before we start the client.
    unleash.on('ready', (_) {
      count += 1;
    });

    await unleash.start();
    await unleash.start();

    expect(count, 1);
  });

  test('can fetch initial toggles with await', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    await unleash.start();
    unleash.stop();

    expect(unleash.isEnabled('flutter-on'), true);
    expect(unleash.isEnabled('flutter-off'), false);
    expect(getMock.calledTimes, 1);
  });

  test('skip initial fetch when TTL not exceeded and 200 code', () async {
    final getMock = GetMock();
    final sharedStorageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: getMock,
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));

    await unleash.start();

    final anotherGetMock = GetMock();
    final anotherUnleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: anotherGetMock,
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));

    await anotherUnleash.start();

    expect(anotherUnleash.isEnabled('flutter-on'), true);
    expect(anotherUnleash.isEnabled('flutter-off'), false);
    expect(anotherGetMock.calledTimes, 0);
  });

  test('skip initial fetch when TTL not exceeded and 304 code', () async {
    final getMock = GetMock(status: 304);
    final sharedStorageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: getMock,
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));

    await unleash.start();

    final anotherGetMock = GetMock(status: 304);
    final anotherUnleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: anotherGetMock,
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));

    await anotherUnleash.start();

    expect(anotherGetMock.calledTimes, 0);
  });

  test('skip initial fetch when bootstrap is provided and TTL not expired',
      () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        fetcher: getMock,
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: true,
              impressionData: false,
              variant: Variant(
                  enabled: true,
                  name: 'variant-name',
                  payload: Payload(type: "string", value: "someValue")))
        },
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));

    await unleash.start();

    expect(unleash.isEnabled('flutter-on'), true);
    expect(getMock.calledTimes, 0);
  });

  test('do not skip initial fetch when context is different', () async {
    final getMock = GetMock();
    final sharedStorageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: getMock,
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));
    unleash.updateContext(
        UnleashContext(properties: {'customKey': 'customValue'}));

    await unleash.start();

    final anotherGetMock = GetMock();
    final anotherUnleash = UnleashClient(
      url: url,
      clientKey: 'proxy-123',
      appName: 'flutter-test',
      storageProvider: sharedStorageProvider,
      fetcher: anotherGetMock,
      experimental: const ExperimentalConfig(togglesStorageTTL: 10),
    );
    unleash.updateContext(UnleashContext(
        properties: {'customKey': 'anotherCustomValue'})); // different context

    await anotherUnleash.start();

    expect(anotherGetMock.calledTimes, 1);
  });

  test('skip initial fetch when context is identical with updateContext',
      () async {
    final getMock = GetMock();
    final sharedStorageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: getMock,
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));
    unleash.updateContext(UnleashContext(userId: '123'));

    await unleash.start();

    final anotherGetMock = GetMock();
    final anotherUnleash = UnleashClient(
      url: url,
      clientKey: 'proxy-123',
      appName: 'flutter-test',
      storageProvider: sharedStorageProvider,
      fetcher: anotherGetMock,
      experimental: const ExperimentalConfig(togglesStorageTTL: 10),
    );
    anotherUnleash.updateContext(UnleashContext(userId: '123'));

    await anotherUnleash.start();

    expect(anotherGetMock.calledTimes, 0);
  });

  test('skip initial fetch when context is identical with setContextFields',
      () async {
    final getMock = GetMock();
    final sharedStorageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: getMock,
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));
    unleash.setContextFields({'userId': '123'});

    await unleash.start();

    final anotherGetMock = GetMock();
    final anotherUnleash = UnleashClient(
      url: url,
      clientKey: 'proxy-123',
      appName: 'flutter-test',
      storageProvider: sharedStorageProvider,
      fetcher: anotherGetMock,
      experimental: const ExperimentalConfig(togglesStorageTTL: 10),
    );
    anotherUnleash.setContextFields({'userId': '123'});

    await anotherUnleash.start();

    expect(anotherGetMock.calledTimes, 0);
  });

  test('do not skip initial fetch when TTL exceeded', () async {
    final getMock = GetMock();
    final sharedStorageProvider = InMemoryStorageProvider();
    final originalTime = DateTime.utc(2000);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        clock: () => originalTime,
        fetcher: getMock);

    await unleash.start();

    final anotherGetMock = GetMock();
    final anotherUnleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: anotherGetMock,
        clock: () => originalTime.add(const Duration(seconds: 11)),
        experimental: const ExperimentalConfig(togglesStorageTTL: 10));

    await anotherUnleash.start();

    expect(anotherUnleash.isEnabled('flutter-on'), true);
    expect(anotherUnleash.isEnabled('flutter-off'), false);
    expect(anotherGetMock.calledTimes, 1);
  });

  test('do not skip initial fetch when TTL is 0', () async {
    final getMock = GetMock();
    final sharedStorageProvider = InMemoryStorageProvider();
    final originalTime = DateTime.utc(2000);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        clock: () => originalTime,
        fetcher: getMock);

    await unleash.start();

    final anotherGetMock = GetMock();
    final anotherUnleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: sharedStorageProvider,
        fetcher: anotherGetMock,
        clock: () => originalTime,
        experimental: const ExperimentalConfig(togglesStorageTTL: 0));

    await anotherUnleash.start();

    expect(anotherGetMock.calledTimes, 1);
  });

  test('can store toggles in memory storage', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock,
        storageProvider: storageProvider);

    await unleash.start();
    final result = await storageProvider.get(storageKey);

    expect(result, mockData);
  });

  test('can read initial toggles from in memory storage', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    await storageProvider.save(storageKey, mockData);
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        fetcher: getMock,
        storageProvider: storageProvider);

    expect(unleash.isEnabled('flutter-on'), false);

    final completer = Completer<void>();
    unleash.on('initialized', (_) {
      completer.complete();
    });
    await completer.future;

    expect(unleash.isEnabled('flutter-on'), true);
    expect(getMock.calledTimes, 0);
  });

  test('can store toggles in shared preferences by default', () async {
    final getMock = GetMock();
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      SharedPreferences.setMockInitialValues({});
    });
    final storageProvider = await SharedPreferencesStorageProvider.init();
    final unleash = UnleashClient(
      url: url,
      clientKey: 'proxy-123',
      appName: 'flutter-test',
      sessionIdGenerator: generateSessionId,
      fetcher: getMock,
    );

    await unleash.start();
    final result = await storageProvider.get(storageKey);
    final sessionId = await storageProvider.get(sessionStorageKey);

    expect(result, mockData);
    expect(sessionId, '1234');
  });

  test('can refetch toggles at a regular interval', () {
    fakeAsync((async) {
      final getMock = GetMock();
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock);

      var updateEventCount = 0;
      unleash.on('update', (_) {
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

  test('can disable refresh at a regular interval', () {
    fakeAsync((async) {
      final getMock = GetMock();
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          disableRefresh: true,
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock);

      var updateEventCount = 0;
      unleash.on('update', (_) {
        updateEventCount += 1;
      });

      unleash.start();
      expect(getMock.calledTimes, 0);
      async.elapse(const Duration(seconds: 1));
      expect(getMock.calledTimes, 1);
      async.elapse(const Duration(seconds: 100));
      expect(getMock.calledTimes, 1);
      expect(updateEventCount, 1);
    });
  });

  test('can manually update toggles', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        disableRefresh: true,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    var updateEventCount = 0;
    unleash.on('update', (_) {
      updateEventCount += 1;
    });

    await unleash.start();
    expect(getMock.calledTimes, 1);
    expect(updateEventCount, 1);

    await unleash.updateToggles();
    expect(getMock.calledTimes, 2);
    expect(updateEventCount, 2);

    await unleash.updateToggles();
    expect(getMock.calledTimes, 3);
    expect(updateEventCount, 3);
  });

  test('should not update toggles when not started', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        refreshInterval: 0,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    unleash.updateToggles();
    expect(getMock.calledTimes, 0);
  });

  test('update toggles should wait on asynchronous start', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        refreshInterval: 0,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    final completer = Completer<void>();
    // Ready should be registered before we start the client.
    unleash.on('ready', (_) {
      completer.complete();
    });

    unleash.start();
    unleash.updateToggles();

    await completer.future;

    expect(getMock.calledTimes, 1);

    await unleash.updateToggles();

    expect(getMock.calledTimes, 3);
  });

  test('can manually send metrics', () async {
    var postMock = PostMock(payload: '''{}''', status: 200, headers: {});
    final getMock = GetMock(body: mockData, status: 200, headers: {});
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        refreshInterval: 0,
        metricsInterval: 0,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock,
        poster: postMock);

    await unleash.start();

    // no buckets to send
    await unleash.sendMetrics();
    expect(postMock.calledTimes, 0);

    unleash.isEnabled('flutter-on');
    await unleash.sendMetrics();
    expect(postMock.calledTimes, 1);
  });

  test('stopping client should cancel the timer', () {
    fakeAsync((async) {
      final getMock = GetMock();
      var payload =
          '''{start: 2022-12-21T14:18:38.953834, stop: 2022-12-21T14:18:48.953834, toggles: {}}''';
      final postMock = PostMock(payload: payload, status: 200, headers: {});
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          metricsInterval: 10,
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock,
          poster: postMock);

      unleash.start();
      unleash.isEnabled('flutter-on');
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
      expect(postMock.calledTimes, 1);
      // first stop cancels the timer
      unleash.stop();
      unleash.isEnabled('flutter-on');
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
      expect(postMock.calledTimes, 1);
      // second stop should be no-op
      unleash.stop();
      unleash.isEnabled('flutter-on');
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledTimes, 2);
      expect(postMock.calledTimes, 1);
    });
  });

  test('can update context', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        environment: 'production',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    await unleash.start();
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));
    await unleash.setContextField('userId', '456');
    await unleash.setContextField('anotherCustomKey', 'anotherCustomValue');
    await unleash
        .setContextFields({'userId': '789', 'mapCustomKey': 'mapCustomValue'});

    expect(getMock.calledTimes, 5);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=production'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&appName=flutter-test&environment=production'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=456&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&appName=flutter-test&environment=production'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=456&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&properties%5BanotherCustomKey%5D=anotherCustomValue&appName=flutter-test&environment=production'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=789&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue'
          '&properties%5BanotherCustomKey%5D=anotherCustomValue&properties%5BmapCustomKey%5D=mapCustomValue&appName=flutter-test&environment=production')
    ]);
  });

  test('can update single context fields', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    await unleash.start();
    await unleash.setContextField('userId', '123');
    await unleash.setContextField('sessionId', 'session');
    await unleash.setContextField('remoteAddress', 'address');
    await unleash.setContextField('anotherCustomKey', 'anotherCustomValue');

    expect(getMock.calledTimes, 5);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&sessionId=1234&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&sessionId=session&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BanotherCustomKey%5D=anotherCustomValue&appName=flutter-test&environment=default')
    ]);
  });

  test('update context should wait on asynchronous start', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    unleash.start();
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 2);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&appName=flutter-test&environment=default')
    ]);
  });

  test('update context with await', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));
    await unleash.start();

    expect(getMock.calledTimes, 1);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&appName=flutter-test&environment=default')
    ]);
  });

  test(
      'set and update context with the same value will not trigger new fetch call',
      () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));
    // update whole context before start but keep data identical
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));
    // set standard property before start
    unleash.setContextField('userId', '123');
    // set standard an custom property before start
    unleash.setContextFields({'customKey': 'customValue', 'userId': '123'});
    await unleash.start();

    // set standard properties after start
    await unleash.setContextField('userId', '123');
    await unleash.setContextField('remoteAddress', 'address');
    await unleash.setContextField('sessionId', 'session');
    // set custom property after start
    await unleash.setContextField('customKey', 'customValue');
    // set standard and custom property after start
    await unleash
        .setContextFields({'customKey': 'customValue', 'userId': '123'});
    // update whole context after start
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 1);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&appName=flutter-test&environment=default')
    ]);
  });

  test('update context removing fields triggers new flag update', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);
    // ignore this one
    unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {
          'customKey': 'customValue',
          'remove1': 'val1',
          'remove2': 'val2'
        }));
    // first call
    unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue', 'remove1': 'val1'}));
    await unleash.start();

    // remove another field and second call
    await unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 2);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&properties%5Bremove1%5D=val1&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&appName=flutter-test&environment=default')
    ]);
  });

  test('update context without await', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));
    await unleash.start();

    expect(getMock.calledTimes, 1);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123&remoteAddress=address&sessionId=session&properties%5BcustomKey%5D=customValue&appName=flutter-test&environment=default')
    ]);
  });

  test('set context field should wait on asynchronous start', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    unleash.start();
    await unleash.setContextField('userId', '456');

    expect(getMock.calledTimes, 2);
    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=456&sessionId=1234&appName=flutter-test&environment=default')
    ]);
  });

  test('update context should not invoke HTTP without start', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    unleash.updateContext(UnleashContext(
        userId: '123',
        remoteAddress: 'address',
        sessionId: 'session',
        properties: {'customKey': 'customValue'}));

    expect(getMock.calledTimes, 0);
  });

  test('should encode query parameters', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        sessionIdGenerator: generateSessionId,
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    await unleash.start();
    await unleash.updateContext(UnleashContext(
        userId: '123??',
        remoteAddress: '192.168.0.10',
        sessionId: 'session',
        properties: {'custom?Key': 'customValue?'}));

    expect(getMock.calledWithUrls, [
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
      Uri.parse(
          'https://app.unleash-hosted.com/demo/api/proxy?userId=123%3F%3F&remoteAddress=192.168.0.10&sessionId=session&properties%5Bcustom%3FKey%5D=customValue%3F&appName=flutter-test&environment=default')
    ]);
  });

  test('interval should pick settings from update context', () {
    fakeAsync((async) {
      final getMock = GetMock();
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          sessionIdGenerator: generateSessionId,
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock);

      unleash.start();
      unleash.updateContext(UnleashContext(userId: '123'));
      async.elapse(const Duration(seconds: 10));
      expect(getMock.calledWithUrls, [
        Uri.parse(
            'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
        Uri.parse(
            'https://app.unleash-hosted.com/demo/api/proxy?userId=123&sessionId=1234&appName=flutter-test&environment=default'),
        Uri.parse(
            'https://app.unleash-hosted.com/demo/api/proxy?userId=123&sessionId=1234&appName=flutter-test&environment=default')
      ]);
    });
  });

  test('should store ETag locally', () {
    fakeAsync((async) {
      final getMock =
          GetMock(body: mockData, status: 200, headers: {'ETag': 'ETagValue'});
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          sessionIdGenerator: generateSessionId,
          idGenerator: () => '1234',
          sdkName: 'unleash-client-flutter:1.0.0',
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock);

      unleash.start();
      async.elapse(const Duration(seconds: 10));

      expect(getMock.calledWith, [
        [
          Uri.parse(
              'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'unleash-appname': 'flutter-test',
            'unleash-connection-id': '1234',
            'unleash-sdk': 'unleash-client-flutter:1.0.0',
            'Authorization': 'proxy-123',
          }
        ],
        [
          Uri.parse(
              'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'unleash-appname': 'flutter-test',
            'unleash-connection-id': '1234',
            'unleash-sdk': 'unleash-client-flutter:1.0.0',
            'Authorization': 'proxy-123',
            'If-None-Match': 'ETagValue'
          }
        ]
      ]);
    });
  });

  test('should not store ETag on codes other than 200', () {
    fakeAsync((async) {
      final getMock = GetMock(
          body: mockData, status: 500, headers: {'ETag': 'ETagValueIgnore'});
      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          sessionIdGenerator: generateSessionId,
          idGenerator: () => '1234',
          sdkName: 'unleash-client-flutter:1.0.0',
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock);

      unleash.start();
      async.elapse(const Duration(seconds: 10));

      expect(getMock.calledWith, [
        [
          Uri.parse(
              'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'unleash-appname': 'flutter-test',
            'unleash-connection-id': '1234',
            'unleash-sdk': 'unleash-client-flutter:1.0.0',
            'Authorization': 'proxy-123',
          }
        ],
        [
          Uri.parse(
              'https://app.unleash-hosted.com/demo/api/proxy?sessionId=1234&appName=flutter-test&environment=default'),
          {
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'unleash-appname': 'flutter-test',
            'unleash-connection-id': '1234',
            'unleash-sdk': 'unleash-client-flutter:1.0.0',
            'Authorization': 'proxy-123',
          }
        ]
      ]);
    });
  });

  test('can get default variant from API', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);
    await unleash.start();

    final variant = unleash.getVariant('flutter.on');

    expect(variant, Variant(name: 'disabled', enabled: false));
  });

  test('can get default variant for non-existent toggle', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);
    await unleash.start();

    final variant = unleash.getVariant('non.existent.toggle');

    expect(variant, Variant(name: 'disabled', enabled: false));
  });

  test('can get variant', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);
    await unleash.start();

    final variant = unleash.getVariant('flutter-variant');

    expect(variant, Variant(name: 'flutter-variant-value', enabled: true));
  });

  test('should not send metrics on an interval if bucket is empty', () {
    fakeAsync((async) {
      var payload =
          '''{start: 2022-12-21T14:18:38.953834, stop: 2022-12-21T14:18:48.953834, toggles: {}}''';

      var getMock = GetMock(body: mockData, status: 200, headers: {});
      var postMock = PostMock(payload: payload, status: 200, headers: {});

      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          metricsInterval: 10,
          sessionIdGenerator: generateSessionId,
          fetcher: getMock,
          poster: postMock);

      unleash.start();
      async.elapse(const Duration(seconds: 10));

      expect(postMock.calledTimes, 0);
    });
  });

  test('should not send metrics on an interval if disableMetrics is set', () {
    fakeAsync((async) {
      var payload =
          '''{start: 2022-12-21T14:18:38.953834, stop: 2022-12-21T14:18:48.953834, toggles: {}}''';

      var getMock = GetMock(body: mockData, status: 200, headers: {});
      var postMock = PostMock(payload: payload, status: 200, headers: {});

      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          metricsInterval: 10,
          disableMetrics: true,
          sessionIdGenerator: generateSessionId,
          fetcher: getMock,
          poster: postMock);

      unleash.start();
      async.elapse(const Duration(seconds: 50));

      expect(postMock.calledTimes, 0);
    });
  });

  test('should send metrics on interval if metrics are observed', () {
    fakeAsync((async) {
      var payload =
          '''{"appName":"flutter-test","instanceId":"flutter","bucket":{"start":"2000-01-01T00:00:00.000Z","stop":"2000-01-01T00:00:00.000Z","toggles":{"flutter-on":{"yes":1,"no":0,"variants":{}}}}}''';

      var getMock = GetMock(body: mockData, status: 200, headers: {});
      var postMock = PostMock(payload: payload, status: 200, headers: {});

      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          metricsInterval: 10,
          sessionIdGenerator: generateSessionId,
          idGenerator: () => '1234',
          sdkName: 'unleash-client-flutter:1.0.0',
          storageProvider: InMemoryStorageProvider(),
          clock: () => DateTime.utc(2000),
          fetcher: getMock,
          poster: postMock);

      unleash.start();
      async.elapse(const Duration(seconds: 1));
      expect(unleash.isEnabled('flutter-on'), true);
      async.elapse(const Duration(seconds: 10));

      expect(postMock.calledTimes, 1);
      expect(postMock.calledWith, [
        [
          Uri.parse(
              'https://app.unleash-hosted.com/demo/api/proxy/client/metrics'),
          {
            'content-type': 'application/json',
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'Authorization': 'proxy-123',
            'unleash-appname': 'flutter-test',
            'unleash-connection-id': '1234',
            'unleash-sdk': 'unleash-client-flutter:1.0.0',
          },
          payload
        ],
      ]);
    });
  });

  test('should record metrics for getVariant', () {
    fakeAsync((async) {
      var payload =
          '''{"appName":"flutter-test","instanceId":"flutter","bucket":{"start":"2000-01-01T00:00:00.000Z","stop":"2000-01-01T00:00:00.000Z","toggles":{"flutter-variant":{"yes":3,"no":0,"variants":{"flutter-variant-value":2}},"nonexistent":{"yes":0,"no":1,"variants":{"disabled":1}}}}}''';

      var getMock = GetMock(body: mockData, status: 200, headers: {});
      var postMock = PostMock(payload: payload, status: 200, headers: {});

      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          metricsInterval: 10,
          clock: () => DateTime.utc(2000),
          sessionIdGenerator: generateSessionId,
          idGenerator: () => '1234',
          sdkName: 'unleash-client-flutter:1.0.0',
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock,
          poster: postMock);

      unleash.start();

      async.elapse(const Duration(
          seconds: 0)); // call elapse to execute the async function call.
      expect(unleash.isEnabled('flutter-variant'), true);
      expect(unleash.getVariant('flutter-variant').enabled, true);
      expect(unleash.getVariant('flutter-variant').enabled, true);
      expect(unleash.getVariant('nonexistent').enabled, false);

      async.elapse(const Duration(seconds: 10));

      expect(postMock.calledTimes, 1);
      expect(postMock.calledWith, [
        [
          Uri.parse(
              'https://app.unleash-hosted.com/demo/api/proxy/client/metrics'),
          {
            'content-type': 'application/json',
            'Accept': 'application/json',
            'Cache': 'no-cache',
            'Authorization': 'proxy-123',
            'unleash-appname': 'flutter-test',
            'unleash-connection-id': '1234',
            'unleash-sdk': 'unleash-client-flutter:1.0.0',
          },
          payload
        ],
      ]);
    });
  });

  test('should emit an error posting and getting a status code above 399', () {
    fakeAsync((async) {
      var payload =
          '''{start: 2022-12-21T14:18:38.953834Z, stop: 2022-12-21T14:18:48.953834Z, toggles: {}}''';

      var getMock = GetMock(body: mockData, status: 200, headers: {});
      var postMock = PostMock(payload: payload, status: 400, headers: {});

      final unleash = UnleashClient(
          url: url,
          clientKey: 'proxy-123',
          appName: 'flutter-test',
          refreshInterval: 10,
          metricsInterval: 10,
          sessionIdGenerator: generateSessionId,
          storageProvider: InMemoryStorageProvider(),
          fetcher: getMock,
          poster: postMock);

      dynamic value;
      unleash.on('error', (payload) {
        value = payload;
      });

      unleash.start();
      async.elapse(const Duration(seconds: 0));
      expect(unleash.isEnabled('flutter-variant'), true);
      async.elapse(const Duration(seconds: 10));
      expect(postMock.calledTimes, 1);
      expect(value, {
        "type": 'HttpError',
        "code": 400,
      });
    });
  });

  test('can provide initial bootstrap', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: true,
              impressionData: false,
              variant: Variant(
                  enabled: true,
                  name: 'variant-name',
                  payload: Payload(type: "string", value: "someValue")))
        },
        fetcher: getMock);

    expect(unleash.isEnabled('flutter-on'), true);
    expect(unleash.isEnabled('flutter-off'), false);

    final events = [];
    final initialized = Completer<void>();
    unleash.on('initialized', (_) {
      events.add('initialized');
      initialized.complete();
    });
    final ready = Completer<void>();
    unleash.on('ready', (_) {
      events.add('ready');
      ready.complete();
    });

    await Future.wait([initialized.future, ready.future]);
    final storageToggles = await storageProvider.get(storageKey);

    expect(events, ['initialized', 'ready']);
    expect(storageToggles,
        '{"toggles":[{"name":"flutter-on","enabled":true,"impressionData":false,"variant":{"name":"variant-name","enabled":true,"payload":{"type":"string","value":"someValue"}}}]}');
  });

  test('should not emit ready event twice when using bootstrap', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: true,
              impressionData: false,
              variant: Variant(enabled: true, name: 'variant-name'))
        },
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    var count = 0;
    unleash.on('ready', (_) {
      count += 1;
    });

    await unleash.start();

    expect(count, 1);
  });

  test('clientState should be ready when ready event is emitted', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: true,
              impressionData: false,
              variant: Variant(enabled: true, name: 'variant-name'))
        },
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    unleash.on('initialized', (_) {
      expect(unleash.clientState, ClientState.initialized);
    });
    unleash.on('ready', (_) {
      expect(unleash.clientState, ClientState.ready);
    });

    await unleash.start();
  });

  test('API should override bootstrap after fetching data', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: false,
              impressionData: true,
              variant: Variant(enabled: false, name: 'variant-name'))
        },
        storageProvider: InMemoryStorageProvider(),
        fetcher: getMock);

    expect(unleash.getVariant('flutter-on'),
        Variant(enabled: false, name: 'variant-name'));

    await unleash.start();

    expect(unleash.getVariant('flutter-on'),
        Variant(enabled: false, name: 'disabled'));
  });

  test('by default bootstrap overrides local storage', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    await storageProvider.save(storageKey,
        '{"toggles":[{"name":"flutter-on","enabled":true,"impressionData":false,"variant":{"name":"storage-variant-name","enabled":true}}]}');
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: false,
              impressionData: false,
              variant: Variant(enabled: true, name: 'bootstrap-variant-name'))
        },
        fetcher: getMock);

    final initialized = Completer<void>();
    unleash.on('initialized', (_) {
      initialized.complete();
    });
    await initialized.future;

    expect(unleash.getVariant('flutter-on').name, 'bootstrap-variant-name');
  });

  test('prevent bootstrap overrides on non-empty storage', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    await storageProvider.save(storageKey,
        '{"toggles":[{"name":"flutter-on","enabled":true,"impressionData":false,"variant":{"name":"storage-variant-name","enabled":true}}]}');
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        bootstrapOverride: false,
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: false,
              impressionData: false,
              variant: Variant(enabled: true, name: 'bootstrap-variant-name'))
        },
        fetcher: getMock);

    final initialized = Completer<void>();
    unleash.on('initialized', (_) {
      initialized.complete();
    });
    await initialized.future;

    expect(unleash.getVariant('flutter-on').name, 'storage-variant-name');
  });

  test('bootstrap overrides on empty storage', () async {
    final getMock = GetMock();
    final storageProvider = InMemoryStorageProvider();
    await storageProvider.save(storageKey, '{"toggles":[]}');
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: storageProvider,
        bootstrapOverride: false,
        bootstrap: {
          'flutter-on': ToggleConfig(
              enabled: true,
              impressionData: false,
              variant: Variant(enabled: true, name: 'variant-name'))
        },
        fetcher: getMock);

    final initialized = Completer<void>();
    unleash.on('ready', (_) {
      initialized.complete();
    });
    await initialized.future;

    expect(unleash.getVariant('flutter-on').name, 'variant-name');
  });

  test('emits impression event on isEnabled when impressionData allows',
      () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        idGenerator: () => '1234',
        sessionIdGenerator: () => '5678',
        fetcher: getMock);

    List<Map<String, dynamic>> impressions = [];
    unleash.on('impression', (Map<String, dynamic> impression) {
      impressions.add(impression);
    });

    await unleash.start();

    unleash.isEnabled('flutter-on'); // has impressionData
    unleash.isEnabled('flutter-on');
    unleash.isEnabled('flutter-off'); // does not have impressionData

    expect(impressions, [
      {
        'eventType': 'isEnabled',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': true,
        'featureName': 'flutter-on',
        'impressionData': true
      },
      {
        'eventType': 'isEnabled',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': true,
        'featureName': 'flutter-on',
        'impressionData': true
      }
    ]);
  });

  test('emits impression event on getVariant when impressionData allows',
      () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        idGenerator: () => '1234',
        sessionIdGenerator: () => '5678',
        fetcher: getMock);

    List<Map<String, dynamic>> impressions = [];
    unleash.on('impression', (Map<String, dynamic> impression) {
      impressions.add(impression);
    });

    await unleash.start();

    unleash.getVariant('flutter-variant'); // has impressionData
    unleash.getVariant('flutter-variant');
    unleash.getVariant('flutter-off'); // does not have impressionData
    unleash.getVariant('flutter-on'); // test disabled variant

    expect(impressions, [
      {
        'eventType': 'getVariant',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': true,
        'featureName': 'flutter-variant',
        'impressionData': true,
        'variant': 'flutter-variant-value'
      },
      {
        'eventType': 'getVariant',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': true,
        'featureName': 'flutter-variant',
        'impressionData': true,
        'variant': 'flutter-variant-value'
      },
      {
        'eventType': 'getVariant',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': true,
        'featureName': 'flutter-on',
        'impressionData': true,
        'variant': 'disabled'
      },
    ]);
  });

  test('emits impression event with impressionDataAll', () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        idGenerator: () => '1234',
        sessionIdGenerator: () => '5678',
        impressionDataAll: true,
        fetcher: getMock);

    List<Map<String, dynamic>> impressions = [];
    unleash.on('impression', (Map<String, dynamic> impression) {
      impressions.add(impression);
    });

    await unleash.start();

    unleash.isEnabled('flutter-off'); // does not have impressionData
    unleash.getVariant('flutter-off'); // does not have impressionData

    expect(impressions, [
      {
        'eventType': 'isEnabled',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': false,
        'featureName': 'flutter-off',
        'impressionData': false
      },
      {
        'eventType': 'getVariant',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': false,
        'featureName': 'flutter-off',
        'impressionData': false,
        'variant': 'flutter-off-variant'
      }
    ]);
  });

  test(
      'emits impression event with impressionDataAll and unknown feature toggle',
      () async {
    final getMock = GetMock();
    final unleash = UnleashClient(
        url: url,
        clientKey: 'proxy-123',
        appName: 'flutter-test',
        storageProvider: InMemoryStorageProvider(),
        idGenerator: () => '1234',
        sessionIdGenerator: () => '5678',
        impressionDataAll: true,
        fetcher: getMock);

    List<Map<String, dynamic>> impressions = [];
    unleash.on('impression', (Map<String, dynamic> impression) {
      impressions.add(impression);
    });

    await unleash.start();

    unleash.isEnabled('unknown-feature');
    unleash.getVariant('unknown-feature');

    expect(impressions, [
      {
        'eventType': 'isEnabled',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': false,
        'featureName': 'unknown-feature',
        'impressionData': null
      },
      {
        'eventType': 'getVariant',
        'eventId': '1234',
        'context': {
          'sessionId': '5678',
          'appName': 'flutter-test',
          'environment': 'default'
        },
        'enabled': false,
        'featureName': 'unknown-feature',
        'impressionData': null
      }
    ]);
  });
}

abstract class UnleashConfig {
  /// Flag that will be used to control the image details feature in the app
  bool get isDetailsPageEnabled;
}

class UnleashConfigImpl extends UnleashConfig {
  final UnleashClient unleash;

  UnleashConfigImpl(this.unleash);

  /// After setting up the client
  @override
  bool get isDetailsPageEnabled => unleash.isEnabled('isImageDetailsEnabled');
}
