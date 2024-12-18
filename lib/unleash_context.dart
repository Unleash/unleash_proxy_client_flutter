/// https://docs.getunleash.io/reference/unleash-context
class UnleashContext {
  String? userId;
  String? sessionId;
  String? remoteAddress;
  Map<String, String> properties;

  UnleashContext(
      {this.userId,
      this.sessionId,
      this.remoteAddress,
      Map<String, String>? properties})
      : properties = properties ?? {};

  Map<String, String> toMap() {
    final userId = this.userId;
    final remoteAddress = this.remoteAddress;
    final sessionId = this.sessionId;

    final params = <String, String>{
      if (userId != null) 'userId': userId,
      if (remoteAddress != null) 'remoteAddress': remoteAddress,
      if (sessionId != null) 'sessionId': sessionId,
    };

    properties.forEach((key, value) {
      params['properties[$key]'] = value;
    });

    return params;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UnleashContext) return false;
    return other.userId == userId &&
        other.sessionId == sessionId &&
        other.remoteAddress == remoteAddress &&
        _mapEquals(other.properties, properties);
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      sessionId,
      remoteAddress,
      properties,
    );
  }

  static bool _mapEquals(Map<String, String> map1, Map<String, String> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }
}
