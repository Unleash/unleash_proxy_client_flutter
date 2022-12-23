/// https://docs.getunleash.io/reference/unleash-context
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
    final userId = this.userId;
    final remoteAddress = this.remoteAddress;
    final sessionId = this.sessionId;

    final params = <String, String>{
      if (userId != null) 'userId': userId,
      if (remoteAddress != null) 'remoteAddress': remoteAddress,
      if (sessionId != null) 'sessionId': sessionId,
    };

    params.addAll(properties);

    return params;
  }
}
