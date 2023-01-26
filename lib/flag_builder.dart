import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/material.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';

class FlagBuilder extends StatefulWidget {
  final String flag;
  final Widget Function(bool isEnabled, BuildContext context) build;
  final UnleashClient unleashClient;

  const FlagBuilder({
    Key? key,
    required this.flag,
    required this.build,
    required this.unleashClient,
  }) : super(key: key);

  @override
  FlagBuilderState createState() => FlagBuilderState();
}

class FlagBuilderState extends State<FlagBuilder> {
  bool _isEnabled = false;
  late EventListener _listener;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.unleashClient.isEnabled(widget.flag);
    _listener = widget.unleashClient.on('update', _onUpdate);
  }

  @override
  void dispose() {
    super.dispose();
    widget.unleashClient.removeEventListener(_listener);
  }

  void _onUpdate(dynamic _) {
    final newFlag = widget.unleashClient.isEnabled(widget.flag);
    if (newFlag != _isEnabled) {
      setState(() {
        _isEnabled = newFlag;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.build(_isEnabled, context);
  }
}
