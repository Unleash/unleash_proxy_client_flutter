import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class Bucket {
  final DateTime Function() clock;
  DateTime start;
  late DateTime stop;
  Map<String, ToggleMetrics> toggles = {};

  Bucket(this.clock) : start = clock();

  void closeBucket() {
    stop = clock();
  }

  bool isEmpty() {
    return toggles.isEmpty;
  }

  Map<String, dynamic> toJson() => {
        'start': start.toUtc().toIso8601String(),
        'stop': stop.toUtc().toIso8601String(),
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

class MetricsPayload {
  final String appName;
  final String instanceId;
  final Bucket bucket;

  MetricsPayload(
      {required this.appName, required this.instanceId, required this.bucket});

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'instanceId': instanceId,
        'bucket': bucket.toJson(),
      };
}

class Metrics {
  final String appName;
  final int metricsInterval;
  final String clientKey;
  final Future<http.Response> Function(http.Request) poster;
  final Function(String, [dynamic]) emit;
  final DateTime Function() clock;
  bool disableMetrics;
  Timer? timer;
  Bucket bucket;
  Uri url;

  Metrics(
      {required this.appName,
      required this.metricsInterval,
      required this.clock,
      this.disableMetrics = false,
      required this.poster,
      required this.url,
      required this.clientKey,
      required this.emit})
      : bucket = Bucket(clock);

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

    final localBucket = bucket;
    // For now, accept that a failing request will lose the metrics.
    bucket = Bucket(clock);

    try {
      final payload = MetricsPayload(
          appName: appName, instanceId: 'flutter', bucket: localBucket);
      final jsonPayload = json.encode(payload);
      final request = createRequest(jsonPayload);
      final response = await poster(request);
      if (response.statusCode > 399) {
        emit('error', {
          "type": 'HttpError',
          "code": response.statusCode,
        });
      }
    } catch (e) {
      emit('error', e);
    }
  }

  http.Request createRequest(String payload) {
    final headers = {
      'Accept': 'application/json',
      'Cache': 'no-cache',
      'Content-Type': 'application/json',
      'Authorization': clientKey,
    };

    final request =
        http.Request('POST', Uri.parse('${url.toString()}/client/metrics'));
    request.body = payload;
    request.headers.addAll(headers);
    return request;
  }
}
