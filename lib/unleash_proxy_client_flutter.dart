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

import 'http_toggle_client.dart';

enum ClientState {
  initializing,
  initialized,
  ready,
}

const storageKey = '_unleash_repo';
const sessionStorageKey = '_unleash_sessionId';

class UnleashClient extends EventEmitter {
  Uri url;
  final String clientKey;
  final String appName;
  final int refreshInterval;
  final Future<http.Response> Function(http.Request) fetcher;
  final String Function() sessionIdGenerator;
  Timer? timer;
  Map<String, ToggleConfig> toggles = {};
  Map<String, ToggleConfig>? bootstrap;
  bool bootstrapOverride;
  bool disableRefresh;
  String headerName;
  Map<String, String> customHeaders;
  late StorageProvider actualStorageProvider;
  StorageProvider? storageProvider;
  String? etag;
  late Future<void> ready;
  bool readyEventEmitted = false;
  ClientState clientState = ClientState.initializing;
  UnleashContext context = UnleashContext();

  UnleashClient(
      {required this.url,
      required this.clientKey,
      required this.appName,
      this.refreshInterval = 30,
      this.fetcher = get,
      this.sessionIdGenerator = generateSessionId,
      this.storageProvider,
      this.bootstrap,
      this.bootstrapOverride = true,
      this.disableRefresh = false,
      this.headerName = 'Authorization',
      this.customHeaders = const {}}) {
    ready = _init();
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
      await actualStorageProvider.save(storageKey, stringifyToggles(bootstrap));
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
        await actualStorageProvider.save(storageKey, response.body);
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
      final existingSessionId =
          await actualStorageProvider.get(sessionStorageKey);
      if (existingSessionId == null) {
        final newSessionId = sessionIdGenerator();
        await actualStorageProvider.save(sessionStorageKey, newSessionId);
        return newSessionId;
      }
      return existingSessionId;
    }
  }

  Future<Map<String, ToggleConfig>> _fetchTogglesFromStorage() async {
    final toggles = await actualStorageProvider.get(storageKey);

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

  Variant getVariant(String featureName) {
    final toggle = toggles[featureName];

    if (toggle != null) {
      return toggle.variant;
    } else {
      return Variant.defaultVariant;
    }
  }

  Future<void> start() async {
    if (clientState == ClientState.initializing) {
      await _waitForEvent('initialized');
    }

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
    return toggles[featureName]?.enabled ?? false;
  }
}
