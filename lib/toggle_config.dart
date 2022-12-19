import 'package:unleash_proxy_client_flutter/variant.dart';

class ToggleConfig {
  final bool enabled;
  final bool impressionData;
  final Variant variant;

  ToggleConfig(
      {required this.enabled,
        required this.impressionData,
        required this.variant});

  factory ToggleConfig.fromJson(Map<String, dynamic> json) {
    return ToggleConfig(
        enabled: json["enabled"],
        impressionData: json["impressionData"],
        variant: Variant.fromJson(json["variant"]));
  }

  bool operator ==(Object other) {
    return other is ToggleConfig &&
        (other.enabled == enabled && other.impressionData == impressionData && other.variant == variant);
  }

  String toString() {
    return '{enabled: ${enabled}, impressionData: ${impressionData}, variant: ${variant}}';
  }
}
