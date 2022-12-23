/// https://docs.getunleash.io/reference/feature-toggle-variants
class Variant {
  final String name;
  final bool enabled;

  static final defaultVariant = Variant(name: 'disabled', enabled: false);

  Variant({required this.name, required this.enabled});

  factory Variant.fromJson(Map<String, dynamic> json) {
    return Variant(name: json["name"], enabled: json["enabled"]);
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'enabled': enabled};
  }

  @override
  bool operator ==(Object other) {
    return other is Variant && (other.name == name && other.enabled == enabled);
  }

  @override
  String toString() {
    return '{name: $name, enabled: $enabled}';
  }

  @override
  int get hashCode => Object.hash(name, enabled);
}
