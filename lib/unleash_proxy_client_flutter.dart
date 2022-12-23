library unleash_proxy_client_flutter;

import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:events_emitter/events_emitter.dart';
import 'package:unleash_proxy_client_flutter/parse_stringify_toggles.dart';
import 'package:unleash_proxy_client_flutter/session_id_generator.dart';
import 'package:unleash_proxy_client_flutter/shared_preferences_storage_provider.dart';
import 'package:unleash_proxy_client_flutter/storage_provider.dart';
import 'package:unleash_proxy_client_flutter/toggle_config.dart';
import 'package:unleash_proxy_client_flutter/unleash_context.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';
import 'package:unleash_proxy_client_flutter/metrics.dart';

import 'event_id_generator.dart';
import 'http_toggle_client.dart';

enum ClientState {
  initializing,
  initialized,
  ready,
}

const storageKey = '_unleash_repo';
const sessionStorageKey = '_unleash_sessionId';

String storageWithApp(String appName, String key) {
  return '$appName.$key';
}

class UnleashClient extends EventEmitter {
  final Uri url;
  final String clientKey;
  final String appName;
  final int refreshInterval;
  final int metricsInterval;
  final Future<http.Response> Function(http.Request) fetcher;
  final Future<http.Response> Function(http.Request) poster;
  final String Function() sessionIdGenerator;
  final String Function() eventIdGenerator;
  final DateTime Function() clock;
  final bool disableMetrics;
  Timer? timer;
  Map<String, ToggleConfig> toggles = {};
  Map<String, ToggleConfig>? bootstrap;
  final bool bootstrapOverride;
  final bool disableRefresh;
  final String headerName;
  final Map<String, String> customHeaders;
  late StorageProvider actualStorageProvider;
  StorageProvider? storageProvider;
  String? etag;
  late Future<void> ready;
  var readyEventEmitted = false;
  var clientState = ClientState.initializing;
  var context = UnleashContext();
  late Metrics metrics;

  UnleashClient(
      {required this.url,
      required this.clientKey,
      required this.appName,
      this.metricsInterval = 30,
      this.refreshInterval = 30,
      this.fetcher = get,
      this.poster = post,
      this.sessionIdGenerator = generateSessionId,
      this.eventIdGenerator = generateEventId,
      this.clock = DateTime.now,
      this.disableMetrics = false,
      this.storageProvider,
      this.bootstrap,
      this.bootstrapOverride = true,
      this.disableRefresh = false,
      this.headerName = 'Authorization',
      this.customHeaders = const {}}) {
    ready = _init();
    metrics = Metrics(
        appName: appName,
        poster: poster,
        url: url,
        metricsInterval: metricsInterval,
        clientKey: clientKey,
        disableMetrics: disableMetrics,
        clock: clock,
        emit: emit);
    final bootstrap = this.bootstrap;
    if (bootstrap != null) {
      toggles = bootstrap;
    }
  }

  Future<void> _init() async {
    actualStorageProvider =
        storageProvider ?? await SharedPreferencesStorageProvider.init();

    final currentSessionId = context.sessionId;
    if (currentSessionId == null) {
      final sessionId = await _resolveSessionId();
      context.sessionId = sessionId;
    }

    final togglesInStorage = await _fetchTogglesFromStorage();
    final bootstrap = this.bootstrap;
    if (bootstrap != null && bootstrapOverride) {
      toggles = bootstrap;
    } else {
      toggles = togglesInStorage;
    }

    emit('initialized');
    clientState = ClientState.initialized;

    if (bootstrap != null && (bootstrapOverride || togglesInStorage.isEmpty)) {
      await actualStorageProvider.save(
          storageWithApp(appName, storageKey), stringifyToggles(bootstrap));
      toggles = bootstrap;
      emit('ready');
      clientState = ClientState.ready;
    }
  }

  Future<void> _fetchToggles() async {
    try {
      final headers = {
        'Accept': 'application/json',
        'Cache': 'no-cache',
      };
      headers[headerName] = clientKey;
      headers.addAll(customHeaders);

      final etag = this.etag;
      if (etag != null) {
        headers['If-None-Match'] = etag;
      }

      final request = http.Request(
          'GET', Uri.parse('${url.toString()}${context.toQueryParams()}'));
      request.headers.addAll(headers);
      final response = await fetcher(request);

      if (response.headers.containsKey('ETag') && response.statusCode == 200) {
        this.etag = response.headers['ETag'];
      }
      if (response.statusCode == 200) {
        await actualStorageProvider.save(
            storageWithApp(appName, storageKey), response.body);
        toggles = parseToggles(response.body);
        emit('update');
      }
      if (response.statusCode > 399) {
        emit('error', {
          "type": 'HttpError',
          "code": response.statusCode,
        });
      }
    } catch (e) {
      emit('error', e);
    }
  }

  Future<String> _resolveSessionId() async {
    final sessionId = context.sessionId;
    if (sessionId != null) {
      return sessionId;
    } else {
      final existingSessionId = await actualStorageProvider
          .get(storageWithApp(appName, sessionStorageKey));
      if (existingSessionId == null) {
        final newSessionId = sessionIdGenerator();
        await actualStorageProvider.save(
            storageWithApp(appName, sessionStorageKey), newSessionId);
        return newSessionId;
      }
      return existingSessionId;
    }
  }

  Future<Map<String, ToggleConfig>> _fetchTogglesFromStorage() async {
    final toggles =
        await actualStorageProvider.get(storageWithApp(appName, storageKey));

    if (toggles == null) {
      return {};
    }

    return parseToggles(toggles);
  }

  Future<void> updateContext(UnleashContext unleashContext) async {
    if (clientState == ClientState.ready) {
      _updateContextFields(unleashContext);
      await _fetchToggles();
    } else {
      await _waitForEvent('ready');
      _updateContextFields(unleashContext);
      await _fetchToggles();
    }
  }

  void _updateContextFields(UnleashContext unleashContext) {
    if (unleashContext.sessionId == null) {
      final oldSessionId = context.sessionId;
      context = unleashContext;
      context.sessionId = oldSessionId;
    } else {
      context = unleashContext;
    }
  }

  Future<void> setContextField(String field, String value) async {
    if (clientState == ClientState.ready) {
      _updateContextField(field, value);
      await _fetchToggles();
    } else {
      await _waitForEvent('ready');
      _updateContextField(field, value);
      await _fetchToggles();
    }
  }

  void _updateContextField(String field, String value) {
    if (field == 'userId') {
      context.userId = value;
    } else if (field == 'sessionId') {
      context.sessionId = value;
    } else if (field == 'remoteAddress') {
      context.remoteAddress = value;
    } else {
      context.properties[field] = value;
    }
  }

  Future<void> _waitForEvent(String eventName) async {
    final completer = Completer<void>();
    void listener(dynamic value) async {
      off(type: eventName, callback: listener);
      completer.complete();
    }

    once(eventName, listener);
    await completer.future;
  }

  Future<void> start() async {
    if (clientState == ClientState.initializing) {
      await _waitForEvent('initialized');
    }

    metrics.start();
    await _fetchToggles();

    if (clientState != ClientState.ready) {
      emit('ready');
      clientState = ClientState.ready;
    }

    if (!disableRefresh) {
      timer = Timer.periodic(Duration(seconds: refreshInterval), (timer) {
        _fetchToggles();
      });
    }
  }

  stop() {
    final Timer? timer = this.timer;
    if (timer != null && timer.isActive) {
      timer.cancel();
    }
  }

  bool isEnabled(String featureName) {
    final toggle = toggles[featureName];
    var enabled = toggle?.enabled ?? false;
    metrics.count(featureName, enabled);

    if (toggle != null && toggle.impressionData) {
      final contextWithAppName = context.toMap();
      contextWithAppName['appName'] = appName;

      emit('impression', {
        'eventType': 'isEnabled',
        'eventId': eventIdGenerator(),
        'context': contextWithAppName,
        'enabled': enabled,
        'featureName': featureName,
        'impressionData': toggle.impressionData
      });
    }

    return enabled;
  }

  Variant getVariant(String featureName) {
    final toggle = toggles[featureName];

    if (toggle != null && toggle.impressionData) {
      final contextWithAppName = context.toMap();
      contextWithAppName['appName'] = appName;

      emit('impression', {
        'eventType': 'getVariant',
        'eventId': eventIdGenerator(),
        'context': contextWithAppName,
        'enabled': toggle.enabled,
        'featureName': featureName,
        'impressionData': toggle.impressionData
      });
    }

    if (toggle != null) {
      metrics.count(featureName, toggle.enabled);
      return toggle.variant;
    } else {
      return Variant.defaultVariant;
    }
  }
}
