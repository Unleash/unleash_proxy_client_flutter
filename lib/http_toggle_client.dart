import 'package:http/http.dart' as http;

/// Wraps http package into more convenient interface that can be easily swapped in tests
Future<http.Response> get(http.Request request) {
  return http.get(request.url, headers: request.headers);
}

/// Wraps http package into more convenient interface that can be easily swapped in tests
Future<http.Response> post(http.Request request) {
  return http.post(request.url, headers: request.headers, body: request.body);
}
