class UnleashContext {
  String? userId;
  String? sessionId;
  String? remoteAddress;
  Map<String, String> properties;

  UnleashContext({this.userId, this.sessionId, this.remoteAddress, properties})
      : properties = properties ?? {};

  String toQueryParams() {
    var result = Uri(queryParameters: toSnapshot()).query;
    return result.isNotEmpty ? '?$result' : '';
  }

  Map<String, String> toSnapshot() {
    final params = <String, String>{};

    if (userId != null) {
      params.putIfAbsent('userId', () => userId!);
    }

    if (remoteAddress != null) {
      params.putIfAbsent('remoteAddress', () => remoteAddress!);
    }

    if (sessionId != null) {
      params.putIfAbsent('sessionId', () => sessionId!);
    }

    params.addAll(properties);

    return params;
  }
}
