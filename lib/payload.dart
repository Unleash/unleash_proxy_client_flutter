/// https://docs.getunleash.io/reference/feature-toggle-variants
class Payload {
  final String type;
  final String value;

  Payload({required this.type, required this.value});

  factory Payload.fromJson(Map<String, dynamic> json) {
    return Payload(type: json["type"], value: json["value"]);
  }

  Map<String, dynamic> toMap() {
    return {'type': type, 'value': value};
  }

  @override
  bool operator ==(Object other) {
    return other is Payload && (other.type == type && other.value == value);
  }

  @override
  String toString() {
    return '{type: $type, value: $value}';
  }

  @override
  int get hashCode => Object.hash(type, value);
}
