import 'dart:convert';

import 'package:unleash_proxy_client_flutter/toggle_config.dart';

Map<String, ToggleConfig> parseToggles(String body) {
  final data = jsonDecode(body)['toggles'];
  // Check if there is anything to map over? Otherwise map might cause an error
  // Write a test that checks if the
  return {
    for (var toggle in data) toggle['name']: ToggleConfig.fromJson(toggle)
  };
}

Map<String, dynamic> toJSON(String toggleName, ToggleConfig toggle) {
  return {'name': toggleName, ...toggle.toMap()};
}

String stringifyToggles(Map<String, ToggleConfig> toggles) {
  const jsonEncoder = JsonEncoder();
  final togglesList =
      toggles.entries.map((e) => toJSON(e.key, e.value)).toList();
  return jsonEncoder.convert({'toggles': togglesList});
}
