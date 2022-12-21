class UnleashContext {
  String? userId;
  String? sessionId;
  String? remoteAddress;
  Map<String, String> properties;

  UnleashContext({this.userId, this.sessionId, this.remoteAddress, properties})
      : properties = properties ?? {};

  String toQueryParams() {
    final result = Uri(queryParameters: toSnapshot()).query;
    return result.isNotEmpty ? '?$result' : '';
  }

  Map<String, String> toSnapshot() {
    final params = <String, String>{};

    final localUserId = userId;
    if (localUserId != null) {
      params['userId'] = localUserId;
    }

    final localRemoteAddress = remoteAddress;
    if (localRemoteAddress != null) {
      params['remoteAddress'] = localRemoteAddress;
    }

    final localSessionId = sessionId;
    if (localSessionId != null) {
      params['sessionId'] = localSessionId;
    }

    params.addAll(properties);

    return params;
  }
}
