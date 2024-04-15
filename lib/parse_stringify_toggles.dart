import 'dart:convert';

import 'package:unleash_proxy_client_flutter/toggle_config.dart';

/// Parses toggles from the server or local storage so that they can be used
/// as structured data
Map<String, ToggleConfig> parseToggles(String body) {
  var decoded = jsonDecode(body);

  // Return an empty map if 'toggles' isn't a list or doesn't exist
  if (decoded['toggles'] is! List) {
    print('Expected a list of toggles, received ${decoded['toggles'].runtimeType}');
    return {};
  }

  var toggles = decoded['toggles'] as List;
  var result = <String, ToggleConfig>{};

  for (var toggle in toggles) {
    if (toggle is Map<String, dynamic> && toggle.containsKey('name')) {
      result[toggle['name']] = ToggleConfig.fromJson(toggle);
    } else {
      // Log the invalid toggle entry; skip processing it
      print('Skipping invalid toggle entry: $toggle');
    }
  }

  return result;
}

Map<String, dynamic> toJSON(String toggleName, ToggleConfig toggle) {
  return {'name': toggleName, ...toggle.toMap()};
}

/// Serializes structured toggles into a String before we send it to the
/// server of local storage
String stringifyToggles(Map<String, ToggleConfig> toggles) {
  const jsonEncoder = JsonEncoder();
  final togglesList =
      toggles.entries.map((e) => toJSON(e.key, e.value)).toList();
  return jsonEncoder.convert({'toggles': togglesList});
}
