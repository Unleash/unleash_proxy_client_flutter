library unleash_proxy_client_flutter;

import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:events_emitter/events_emitter.dart';

class UnleashClient extends EventEmitter {
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
    emit('ready', 'dummy data');
    // timer = Timer.periodic(Duration(seconds: refreshInterval), (timer) {
      // fetchToggles();

    // });
  }

  bool isEnabled(String s) {
    return false;
  }
}
