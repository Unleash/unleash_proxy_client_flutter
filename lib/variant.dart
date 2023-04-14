import 'package:unleash_proxy_client_flutter/payload.dart';

/// https://docs.getunleash.io/reference/feature-toggle-variants
class Variant {
  final String name;
  final bool enabled;
  final Payload? payload;

  static final defaultVariant = Variant(name: 'disabled', enabled: false);

  Variant({required this.name, required this.enabled, this.payload});

  factory Variant.fromJson(Map<String, dynamic> json) {
    return Variant(
      name: json["name"],
      enabled: json["enabled"],
      payload:
          json["payload"] != null ? Payload.fromJson(json["payload"]) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'enabled': enabled, 'payload': payload};
  }

  @override
  bool operator ==(Object other) {
    return other is Variant &&
        (other.name == name &&
            other.enabled == enabled &&
            other.payload == payload);
  }

  @override
  String toString() {
    return '{name: $name, enabled: $enabled, payload: $payload}';
  }

  @override
  int get hashCode => Object.hash(name, enabled, payload);
}
