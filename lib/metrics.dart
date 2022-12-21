import 'package:http/http.dart' as http;
import 'package:clock/clock.dart';
import 'dart:async';
import 'dart:convert';

class Bucket {
  DateTime start = clock.now();
  late DateTime stop;
  Map<String, ToggleMetrics> toggles = {};

  void closeBucket() {
    stop = clock.now();
  }

  bool isEmpty() {
    return toggles.isEmpty;
  }

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'stop': stop.toIso8601String(),
        'toggles': toggles.map((key, value) => MapEntry(key, value.toJson())),
      };
}

class ToggleMetrics {
  int yes = 0;
  int no = 0;

  Map<String, dynamic> toJson() => {
        'yes': yes,
        'no': no,
      };
}

class Metrics {
  final String appName;
  final int metricsInterval;
  final Future<http.Response> Function(http.Request) poster;
  bool disableMetrics;
  Timer? timer;
  Bucket bucket = Bucket();
  Uri url;

  Metrics(
      {required this.appName,
      required this.metricsInterval,
      this.disableMetrics = false,
      required this.poster,
      required this.url});

  Future<void> start() async {
    if (disableMetrics) {
      return;
    }

    timer = Timer.periodic(Duration(seconds: metricsInterval), (timer) {
      sendMetrics();
    });
  }

  void count(String name, bool enabled) {
    if (disableMetrics) {
      return;
    }

    var toggle = bucket.toggles[name];
    if (toggle == null) {
      toggle = ToggleMetrics();
      bucket.toggles[name] = toggle;
    }

    if (enabled) {
      toggle.yes++;
    } else {
      toggle.no++;
    }
  }

  void sendMetrics() async {
    bucket.closeBucket();
    if (bucket.isEmpty()) {
      return;
    }

    var localBucket = bucket;
    // For now, accept that a failing request will lose the metrics.
    bucket = Bucket();

    try {
      var jsonPayload = json.encode(localBucket);
      var request = createRequest(jsonPayload);
      await poster(request);
    } catch (e) {
      // emit an error
      print(e);
    }
  }

  http.Request createRequest(String payload) {
    var headers = {
      'Accept': 'application/json',
      'Cache': 'no-cache',
      'Content-Type': 'application/json',
    };

    var request =
        http.Request('POST', Uri.parse('${url.toString()}/client/metrics'));
    request.body = payload;
    request.headers.addAll(headers);
    return request;
  }
}
