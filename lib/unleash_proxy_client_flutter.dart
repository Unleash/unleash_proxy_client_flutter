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
  return http.get(url, headers: {
    'Accept': 'application/json',
    'Cache': 'no-cache',
    'Authorization': clientKey,
  });
}

class UnleashClient extends EventEmitter {
  final String url;
  final String clientKey;
  final String appName;
  final int refreshInterval = 15;
  late Timer timer;
  late Map<String, ToggleConfig> toggles = {};

  UnleashClient({
    required this.url,
    required this.clientKey,
    required this.appName,
  });

  Future<Map<String, ToggleConfig>> fetchToggles() async {
    var response = await get(Uri.parse(url), clientKey);

    if (response.statusCode == 200) {
      var toggleList = jsonDecode(response.body)['toggles'];
      return Map.fromIterable(toggleList,
          key: (toggle) => toggle['name'],
          value: (toggle) => ToggleConfig.fromJson(toggle));
    } else {
      throw Exception('Failed to fetch toggles');
    }
  }

  void start() async {
    toggles = await fetchToggles();
    emit('ready', 'feature toggle ready');
    // timer = Timer.periodic(Duration(seconds: refreshInterval), (timer) {
    // fetchToggles();

    // });
  }

  bool isEnabled(String featureName) {
    return toggles[featureName]?.enabled ?? false;
  }
}
