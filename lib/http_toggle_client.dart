import 'package:http/http.dart' as http;

Future<http.Response> get(http.Request request) async {
  var response = await http.get(request.url, headers: request.headers);

  if (response.statusCode != 200) {
    // Do something else
    // Remember: check 304 also
    // Handle: 400 errors
  }

  return response;
}

Future<http.Response> post(http.Request request) async {
  var response = await http.post(request.url,
      headers: request.headers, body: request.body);

  return response;
}
