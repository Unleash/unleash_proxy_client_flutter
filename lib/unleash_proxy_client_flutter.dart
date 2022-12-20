library unleash_proxy_client_flutter;

import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:events_emitter/events_emitter.dart';
import 'package:unleash_proxy_client_flutter/parse_toggles.dart';
import 'package:unleash_proxy_client_flutter/session_id_generator.dart';
import 'package:unleash_proxy_client_flutter/storage_provider.dart';
import 'package:unleash_proxy_client_flutter/toggle_config.dart';
import 'package:unleash_proxy_client_flutter/unleash_context.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';

import 'http_toggle_client.dart';
import 'in_memory_storage_provider.dart';

enum ClientState {
  initializing,
  initialized,
  ready,
}

class UnleashClient extends EventEmitter {
  Uri url;
  final String clientKey;
  final String appName;
  final int refreshInterval;
  final Future<http.Response> Function(http.Request) fetcher;
  final String Function() sessionIdGenerator;
  Timer? timer;
  Map<String, ToggleConfig> toggles = {};
  StorageProvider storageProvider;
  String? etag;
  late Future<void> ready;
  late bool readyEventEmitted = false;
  ClientState clientState = ClientState.initializing;
  UnleashContext context = UnleashContext();

  UnleashClient({
    required this.url,
    required this.clientKey,
    required this.appName,
    this.refreshInterval = 30,
    this.fetcher = get,
    this.sessionIdGenerator = generateSessionId,
    storageProvider,
  }) : storageProvider = storageProvider ?? InMemoryStorageProvider() {
    ready = init();
  }

  Future<void> fetchToggles() async {
    try {
      var headers = {
        'Accept': 'application/json',
        'Cache': 'no-cache',
        'Authorization': clientKey,
      };
      var localEtag = etag;
      if (localEtag != null) {
        headers.putIfAbsent('If-None-Match', () => localEtag);
      }

      var request = http.Request('GET', Uri.parse('${url.toString()}${context.toQueryParams()}'));
      request.headers.addAll(headers);
      var response = await fetcher(request);

      if (response.headers.containsKey('ETag') && response.statusCode == 200) {
        etag = response.headers['ETag'];
      }
      if (response.statusCode == 200) {
        await storageProvider.save('unleash_repo', response.body);
        toggles = parseToggleResponse(response.body);
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

  String resolveSessionId() {
    return sessionIdGenerator();
  }

  Future<void> init() async {
    toggles = await fetchTogglesFromStorage();
    emit('initialized');
    clientState = ClientState.initialized;
  }

  Future<Map<String, ToggleConfig>> fetchTogglesFromStorage() async {
    var toggles = await storageProvider.get('unleash_repo');

    if (toggles == null) {
      return {};
    }

    return parseToggleResponse(toggles);
  }

  Future<void> updateContext(UnleashContext unleashContext) async {
    if(unleashContext.sessionId == null) {
      var oldSessionId = context.sessionId;
      context = unleashContext;
      context.sessionId = oldSessionId;
    } else {
      context = unleashContext;
    }

    if (clientState == ClientState.ready) {
      await fetchToggles();
    } else {
      final completer = Completer<void>();
      void listener(dynamic value) async {
        await fetchToggles();
        off(type: 'ready', callback: listener);
        completer.complete();
      }

      once('ready', listener);
      await completer.future;
    }
  }

  Variant getVariant(String featureName) {
    var toggle = toggles[featureName];

    if (toggle != null) {
      return toggle.variant;
    } else {
      return Variant.defaultVariant;
    }
  }

  Future<void> start() async {
    var currentSessionId = context.sessionId;
    if(currentSessionId == null) {
      var sessionId = resolveSessionId();
      context.sessionId = sessionId;
    }

    await fetchToggles();

    if (clientState != ClientState.ready) {
      emit('ready');
      clientState = ClientState.ready;
    }

    timer = Timer.periodic(Duration(seconds: refreshInterval), (timer) {
      fetchToggles();
    });
  }

  stop() {
    final Timer? localTimer = timer;
    if (localTimer != null && localTimer.isActive) {
      localTimer.cancel();
    }
  }

  bool isEnabled(String featureName) {
    return toggles[featureName]?.enabled ?? false;
  }
}
