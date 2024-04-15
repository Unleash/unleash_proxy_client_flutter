import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/parse_stringify_toggles.dart';

const mockData = '''{ 
     "toggles": [
      { "name": "flutter-on", "enabled": true, "impressionData": true, "variant": { "enabled": false, "name": "disabled" } }, 
      { "name": "flutter-off", "enabled": false, "impressionData": false, "variant": { "enabled": false, "name": "flutter-off-variant" } },
      { "invalid": "flutter-variant", "enabled": true, "impressionData": true, "variant": { "enabled": true, "name": "flutter-variant" } }
     ] 
  }''';

void main() {
  group('parseToggles', () {
    test('should skip invalid entries and parse only valid ones', () {
      var result = parseToggles(mockData);
      expect(result.length, 2);
      expect(result.containsKey('flutter-on'), isTrue);
      expect(result['flutter-on']?.enabled, isTrue);
      expect(result.containsKey('flutter-off'), isTrue);
      expect(result['flutter-off']?.enabled, isFalse);
    });

    test('should return an empty map if toggles is not a list', () {
      var jsonBody = '{"toggles": {"name": "feature1", "enabled": true}}';
      var result = parseToggles(jsonBody);
      expect(result.isEmpty, isTrue);
    });
  });
}
