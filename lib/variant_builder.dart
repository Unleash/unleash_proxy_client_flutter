import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/material.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';

class VariantBuilder extends StatefulWidget {
  final String featureName;
  final Widget Function(Variant variant, BuildContext context) build;
  final UnleashClient unleashClient;

  const VariantBuilder({
    Key? key,
    required this.featureName,
    required this.build,
    required this.unleashClient,
  }) : super(key: key);

  @override
  VariantBuilderState createState() => VariantBuilderState();
}

class VariantBuilderState extends State<VariantBuilder> {
  late Variant _variant;
  late EventListener _listener;

  @override
  void initState() {
    super.initState();
    _variant = widget.unleashClient.getVariant(widget.featureName);
    _listener = widget.unleashClient.on('update', _onUpdate);
  }

  @override
  void dispose() {
    super.dispose();
    widget.unleashClient.removeEventListener(_listener);
  }

  void _onUpdate(dynamic _) {
    final newVariant = widget.unleashClient.getVariant(widget.featureName);
    if (newVariant.name != _variant.name ||
        newVariant.enabled != _variant.enabled) {
      setState(() {
        _variant = newVariant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.build(_variant, context);
  }
}
