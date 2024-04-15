import 'package:test/test.dart';
import 'parse_stringify_toggles.dart';

void main() {
  group('parseToggles', () {
    test('should parse valid toggles correctly', () {
      var jsonBody = '''
      {
        "toggles": [
          {"name": "feature1", "enabled": true},
          {"name": "feature2", "enabled": false}
        ]
      }
      ''';
      var result = parseToggles(jsonBody);
      expect(result.containsKey('feature1'), isTrue);
      expect(result['feature1']?.enabled, isTrue);
      expect(result.containsKey('feature2'), isTrue);
      expect(result['feature2']?.enabled, isFalse);
    });

    test('should skip invalid entries and parse only valid ones', () {
      var jsonBody = '''
      {
        "toggles": [
          {"name": "validFeature", "enabled": true},
          {"invalid": "data"},
          {"name": 123, "enabled": "yes"}
        ]
      }
      ''';
      var result = parseToggles(jsonBody);
      expect(result.length, 1);
      expect(result.containsKey('validFeature'), isTrue);
      expect(result['validFeature']?.enabled, isTrue);
    });

    test('should return an empty map if toggles is not a list', () {
      var jsonBody = '{"toggles": {"name": "feature1", "enabled": true}}';
      var result = parseToggles(jsonBody);
      expect(result.isEmpty, isTrue);
    });
  });
}
