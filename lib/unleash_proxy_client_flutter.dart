library unleash_proxy_client_flutter;

import 'dart:ffi';

import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:events_emitter/events_emitter.dart';

class ToggleConfig {
  final bool enabled;
  final bool impressionData;

  ToggleConfig({required this.enabled, required this.impressionData});

  factory ToggleConfig.fromJson(dynamic json) {
    return ToggleConfig(
        enabled: json["enabled"], impressionData: json["impressionData"]);
  }
}

Future<dynamic> get(Uri url, String clientKey) async {
  var response = await http.get(url, headers: {
    'Accept': 'application/json',
    'Cache': 'no-cache',
    'Authorization': clientKey,
  });

  if (response.statusCode != 200) {
    // Do something else
    // Remember: check 304 also
    // Handle: 400 errors
  }

  return response.body;
}

Map<String, ToggleConfig> parseToggleResponse(dynamic body) {
  var data = jsonDecode(body)['toggles'];
  // Check if there is anything to map over? Otherwise map might cause an error
  // Write a test that checks if the
  return Map.fromIterable(data,
      key: (toggle) => toggle['name'],
      value: (toggle) => ToggleConfig.fromJson(toggle));
}

class UnleashClient extends EventEmitter {
  final String url;
  final String clientKey;
  final String appName;
  final int refreshInterval;
  final Future<dynamic> Function(Uri, String) fetcher;
  Timer? timer;
  Map<String, ToggleConfig> toggles = {};

  UnleashClient(
      {required this.url,
      required this.clientKey,
      required this.appName,
      this.refreshInterval = 30,
      this.fetcher = get});

  Future<Map<String, ToggleConfig>> fetchToggles() async {
    var body = await fetcher(Uri.parse(url), clientKey);

    return parseToggleResponse(body);
  }

  Future<void> start() async {
    toggles = await fetchToggles();
    emit('ready', 'feature toggle ready');
    timer = Timer.periodic(Duration(seconds: refreshInterval), (timer) {
      fetchToggles();
    });
  }

  void stop() {
    if(timer != null) {
      timer?.cancel();
    }
  }

  bool isEnabled(String featureName) {
    return toggles[featureName]?.enabled ?? false;
  }
}
