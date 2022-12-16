library unleash_proxy_client_flutter;

import 'package:http/http.dart' as http;
import 'dart:async';

class UnleashClient {
  final String url;
  final String clientKey;
  final String appName;
  final int refreshInterval = 15;
  late Timer timer;

  UnleashClient({
    required this.url,
    required this.clientKey,
    required this.appName,
  });

  // Future<Map<String, dynamic>> fetchToggles() async {
  //   var response = await http.get(url, headers: {
  //     'Content-Type': 'application/json',
  //     'Client-Key': clientKey,
  //   });
  //
  //   if (response.statusCode == 200) {
  //     return json.decode(response.body);
  //   } else {
  //     throw Exception('Failed to fetch toggles');
  //   }
  // }

  void start() {
    timer = Timer.periodic(Duration(seconds: refreshInterval), (timer) {
      // fetchToggles();
    });
  }
}
