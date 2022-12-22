class UnleashContext {
  String? userId;
  String? sessionId;
  String? remoteAddress;
  Map<String, String> properties;

  UnleashContext({this.userId, this.sessionId, this.remoteAddress, properties})
      : properties = properties ?? {};

  String toQueryParams() {
    final result = Uri(queryParameters: toMap()).query;
    return result.isNotEmpty ? '?$result' : '';
  }

  Map<String, String> toMap() {
    final params = <String, String>{};

    final userId = this.userId;
    if (userId != null) {
      params['userId'] = userId;
    }

    final remoteAddress = this.remoteAddress;
    if (remoteAddress != null) {
      params['remoteAddress'] = remoteAddress;
    }

    final sessionId = this.sessionId;
    if (sessionId != null) {
      params['sessionId'] = sessionId;
    }

    params.addAll(properties);

    return params;
  }
}
