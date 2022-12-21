import 'package:flutter_test/flutter_test.dart';
import 'package:unleash_proxy_client_flutter/toggle_config.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';

void main() {
  test('config equal', () async {
    var config1 = ToggleConfig(
        enabled: true,
        impressionData: true,
        variant: Variant(name: 'name', enabled: true));
    var config2 = ToggleConfig(
        enabled: true,
        impressionData: true,
        variant: Variant(name: 'name', enabled: true));

    expect(config1 == config2, true);
  });

  test('config not equal because of variants', () async {
    var config1 = ToggleConfig(
        enabled: true,
        impressionData: true,
        variant: Variant(name: 'name1', enabled: true));
    var config2 = ToggleConfig(
        enabled: true,
        impressionData: true,
        variant: Variant(name: 'name2', enabled: true));

    expect(config1 != config2, true);
  });

  test('config not equal because of enabled', () async {
    var config1 = ToggleConfig(
        enabled: true,
        impressionData: true,
        variant: Variant(name: 'name1', enabled: true));
    var config2 = ToggleConfig(
        enabled: false,
        impressionData: true,
        variant: Variant(name: 'name1', enabled: true));

    expect(config1 != config2, true);
  });

  test('config toString', () async {
    var config = ToggleConfig(
        enabled: true,
        impressionData: true,
        variant: Variant(name: 'name1', enabled: true));

    expect(config.toString(),
        '{enabled: true, impressionData: true, variant: {name: name1, enabled: true}}');
  });
}
