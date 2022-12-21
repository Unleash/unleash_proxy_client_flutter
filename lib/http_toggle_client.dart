import 'package:http/http.dart' as http;

Future<http.Response> get(http.Request request) {
  return http.get(request.url, headers: request.headers);
}
