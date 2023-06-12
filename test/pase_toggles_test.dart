import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/parse_stringify_toggles.dart';
import 'package:unleash_proxy_client_flutter/payload.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';
import 'package:unleash_proxy_client_flutter/toggle_config.dart';

void main() {
  test('Test Parse Toggles', () {
    const mockData = '''{ 
      "toggles": [
        { "name": "flutter-on", "enabled": true, "impressionData": true, "variant": { "enabled": false, "name": "disabled" } }, 
        { "name": "flutter-off", "enabled": false, "impressionData": false, "variant": { "enabled": false, "name": "flutter-off-variant" } },
        { "name": "flutter-missing-data" },
        { "name": "flutter-variant-payload", "enabled": true, "impressionData": true, "variant": { "enabled": true, "name": "flutter-variant", "payload": {"type": "string", "value": "someValue"} } }
      ] 
    }''';

    Map<String, ToggleConfig> result = parseToggles(mockData);

    expect(result.length, 4);

    // Check each ToggleConfig object in the result
    expect(
        result['flutter-on'],
        ToggleConfig(
          enabled: true,
          impressionData: true,
          variant: Variant(enabled: false, name: "disabled"),
        ));

    expect(
        result['flutter-off'],
        ToggleConfig(
          enabled: false,
          impressionData: false,
          variant: Variant(enabled: false, name: "flutter-off-variant"),
        ));

    expect(
        result['flutter-missing-data'],
        ToggleConfig(
          enabled: false,
          impressionData: false,
          variant: Variant(enabled: false, name: "disabled"),
        ));

    expect(
        result['flutter-variant-payload'],
        ToggleConfig(
          enabled: true,
          impressionData: true,
          variant: Variant(
              enabled: true,
              name: "flutter-variant",
              payload: Payload(type: "string", value: "someValue")),
        ));
  });
}
