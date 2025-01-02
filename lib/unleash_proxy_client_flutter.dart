library unleash_proxy_client_flutter;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:events_emitter/events_emitter.dart';
import 'package:unleash_proxy_client_flutter/client_events.dart';
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
import 'last_update_terms.dart';

enum ClientState {
  initializing,
  initialized,
  ready,
}

const storageKey = '_unleash_repo';
const sessionStorageKey = '_unleash_sessionId';
const lastUpdateKey = '_unleash_repoLastUpdateTimestamp';

String storageWithApp(String appName, String key) {
  return '$appName.$key';
}

class ExperimentalConfig {
  final int? togglesStorageTTL;

  const ExperimentalConfig({this.togglesStorageTTL});
}

/// Main entry point to Flutter Unleash Proxy (https://docs.getunleash.io/reference/unleash-proxy) client
class UnleashClient extends EventEmitter {
  /// Unleash Proxy URL (https://docs.getunleash.io/reference/unleash-proxy)
  final Uri url;

  /// The key used for Unleash Proxy authorization
  final String clientKey;

  /// The name of the app where the Unleash Client is used
  final String appName;

  /// The name of the environment where the Unleash Client is used
  final String environment;

  /// The number of seconds between toggles re-fetch
  final int refreshInterval;

  /// The number of second between metrics sending
  final int metricsInterval;

  /// The HTTP client for fetching toggles from the Unleash Proxy
  final Future<http.Response> Function(http.Request) fetcher;

  /// The HTTP client for sending metrics to the Unleash Proxy
  final Future<http.Response> Function(http.Request) poster;

  /// Exposed for testability purposes
  final String Function() sessionIdGenerator;

  /// Exposed for testability purposes
  final String Function() eventIdGenerator;

  /// Exposed for testability purposes
  final DateTime Function() clock;

  /// The flag to turn-off metrics tracking
  final bool disableMetrics;

  /// The scheduling timer for re-fetch of the toggles at a refreshInterval
  Timer? timer;

  /// The local in-memory copy of the toggles
  Map<String, ToggleConfig> toggles = {};

  /// The initial toggle setup provided by the user
  Map<String, ToggleConfig>? bootstrap;

  /// The flag to override cached data in the local-storage with the user provided toggle setup
  final bool bootstrapOverride;

  /// The flag to disable feature toggle setting after the initial fetch
  final bool disableRefresh;

  /// The custom name for sending clientKey
  final String headerName;

  /// The extra headers user want to provide to the Unleash Proxy
  final Map<String, String> customHeaders;

  /// The swappable storage provided. By default it can be in-memory or shared preferences based.
  /// The shared preferences provider may requires async init so it's marked as late.
  late StorageProvider actualStorageProvider;

  /// The user injected storage provider that has to be resolved prior to injecting it here
  StorageProvider? storageProvider;

  /// The HTTP header to prevent sending data to client when it hasn't changed
  String? etag;

  /// The internal state of the Unleash Client. It goes from initializing to initialized to ready.
  var clientState = ClientState.initializing;

  /// The information relating to the current feature toggle request
  var context = UnleashContext();

  /// The utility to count and report client side metrics
  late Metrics metrics;

  /// The flag used commonly for "disabled" feature toggles that are not visible to frontend SDKs.
  bool impressionDataAll;

  /// Internal indicator if the client has been started
  var started = false;

  ExperimentalConfig? experimental;

  int lastRefreshTimestamp = 0;

  UnleashClient(
      {required this.url,
      required this.clientKey,
      required this.appName,
      this.environment = 'default',
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
      this.customHeaders = const {},
      this.impressionDataAll = false,
      this.experimental}) {
    _init();
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
    if (experimental != null) {
      final ttl = experimental?.togglesStorageTTL;
      if (ttl != null && ttl > 0) {
        experimental = ExperimentalConfig(togglesStorageTTL: ttl * 1000);
      }
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

    if (bootstrap != null) {
      await _storeLastRefreshTimestamp();
    } else {
      lastRefreshTimestamp = await _getLastRefreshTimestamp();
    }

    clientState = ClientState.initialized;
    emit(initializedEvent);

    if (bootstrap != null && (bootstrapOverride || togglesInStorage.isEmpty)) {
      await actualStorageProvider.save(
          storageWithApp(appName, storageKey), stringifyToggles(bootstrap));
      toggles = bootstrap;

      clientState = ClientState.ready;
      emit(readyEvent);
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

      final uri = url.replace(
        queryParameters: {
          ...url.queryParameters,
          ...context.toMap(),
          'appName': appName,
          'environment': environment
        },
      );
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      final response = await fetcher(request);

      if (response.headers.containsKey('ETag') && response.statusCode == 200) {
        this.etag = response.headers['ETag'];
      }
      if (response.statusCode == 200) {
        await actualStorageProvider.save(
            storageWithApp(appName, storageKey), response.body);
        toggles = parseToggles(response.body);
        await _storeLastRefreshTimestamp();
        emit(updateEvent);
      }
      if (response.statusCode == 304) {
        await _storeLastRefreshTimestamp();
      }
      if (response.statusCode > 399) {
        emit(errorEvent, {
          "type": 'HttpError',
          "code": response.statusCode,
        });
      }
    } catch (e) {
      emit(errorEvent, e);
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
    try {
      final toggles =
          await actualStorageProvider.get(storageWithApp(appName, storageKey));

      if (toggles == null) {
        return {};
      }

      return parseToggles(toggles);
    } catch (e) {
      return {};
    }
  }

  /// Checks if any of the provided context fields are different from the current ones.
  bool _anyFieldHasChanged(Map<String, String> fields) {
    for (var entry in fields.entries) {
      String key = entry.key;
      String newValue = entry.value;

      if (key == 'userId') {
        if (context.userId != newValue) return true;
      } else if (key == 'sessionId') {
        if (context.sessionId != newValue) return true;
      } else if (key == 'remoteAddress') {
        if (context.remoteAddress != newValue) return true;
      } else {
        if (context.properties[key] != newValue) return true;
      }
    }
    return false;
  }

  Future<void> updateContext(UnleashContext unleashContext) async {
    if (unleashContext == context) return;
    if (started == false) {
      await _waitForEvent('initialized');
      _updateContextFields(unleashContext);
    } else if (clientState == ClientState.ready) {
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
    await setContextFields({field: value});
  }

  Future<void> setContextFields(Map<String, String> fields) async {
    if (!_anyFieldHasChanged(fields)) return;
    if (clientState == ClientState.ready) {
      fields.forEach((field, value) {
        _updateContextField(field, value);
      });
      await _fetchToggles();
    } else {
      await _waitForEvent('ready');
      fields.forEach((field, value) {
        _updateContextField(field, value);
      });
      await _fetchToggles();
    }
  }

  Future<void> sendMetrics() async {
    await metrics.sendMetrics();
  }

  Future<void> updateToggles() async {
    if (clientState != ClientState.ready) {
      await _waitForEvent('ready');
      await _fetchToggles();
    }
    await _fetchToggles();
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

  bool _isTogglesStorageTTLEnabled() {
    return experimental?.togglesStorageTTL != null &&
        experimental!.togglesStorageTTL! > 0;
  }

  bool _isUpToDate() {
    if (!_isTogglesStorageTTLEnabled()) {
      return false;
    }

    final now = clock().millisecondsSinceEpoch;
    final ttl = experimental?.togglesStorageTTL ?? 0;

    return lastRefreshTimestamp > 0 &&
        (lastRefreshTimestamp <= now) &&
        (now - lastRefreshTimestamp < ttl);
  }

  Future<int> _getLastRefreshTimestamp() async {
    if (_isTogglesStorageTTLEnabled()) {
      final lastRefresh = await actualStorageProvider
          .get(storageWithApp(appName, lastUpdateKey));
      final lastRefreshDecoded = lastRefresh != null
          ? LastUpdateTerms.fromJson(jsonDecode(lastRefresh))
          : null;
      final contextHash = context.getKey();
      if (lastRefreshDecoded != null && lastRefreshDecoded.key == contextHash) {
        return lastRefreshDecoded.timestamp;
      }
      return 0;
    }
    return 0;
  }

  Future<void> _storeLastRefreshTimestamp() async {
    if (_isTogglesStorageTTLEnabled()) {
      lastRefreshTimestamp = clock().millisecondsSinceEpoch;
      final lastUpdateValue = LastUpdateTerms(
          key: context.getKey(), timestamp: lastRefreshTimestamp);
      await actualStorageProvider.save(storageWithApp(appName, lastUpdateKey),
          jsonEncode(lastUpdateValue.toMap()));
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
    started = true;
    if (clientState == ClientState.initializing) {
      await _waitForEvent('initialized');
    }

    metrics.start();

    if (!_isUpToDate()) {
      await _fetchToggles();
    }

    if (clientState != ClientState.ready) {
      clientState = ClientState.ready;
      emit(readyEvent);
    }

    if (!disableRefresh && refreshInterval > 0) {
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

  void _emitImpression(String featureName, String type) {
    final toggle = toggles[featureName];
    final enabled = toggle?.enabled ?? false;

    if (impressionDataAll || (toggle != null && toggle.impressionData)) {
      final contextWithAppName = {
        ...context.toMap(),
        'appName': appName,
        'environment': environment
      };

      emit(impressionEvent, {
        'eventType': type,
        'eventId': eventIdGenerator(),
        'context': contextWithAppName,
        'enabled': enabled,
        'featureName': featureName,
        'impressionData': toggle?.impressionData
      });
    }
  }

  bool isEnabled(String featureName) {
    final toggle = toggles[featureName];
    final enabled = toggle?.enabled ?? false;
    metrics.count(featureName, enabled);

    _emitImpression(featureName, 'isEnabled');

    return enabled;
  }

  Variant getVariant(String featureName) {
    final toggle = toggles[featureName];
    final enabled = toggle != null ? toggle.enabled : false;

    metrics.count(featureName, enabled);
    _emitImpression(featureName, 'getVariant');

    final variant = toggle != null ? toggle.variant : Variant.defaultVariant;
    metrics.countVariant(featureName, variant.name);

    return variant;
  }
}
