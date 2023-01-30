import 'package:events_emitter/listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'package:unleash_proxy_client_flutter/variant.dart';
import 'package:unleash_proxy_client_flutter/variant_builder.dart';

class MockUnleashClient extends Mock implements UnleashClient {}

class MockEventListener extends Mock implements EventListener {}

class MockBuild extends Mock {
  Widget call(Variant variant, BuildContext context);
}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('VariantBuilder', () {
    late UnleashClient unleashClient;
    final EventListener<dynamic> eventListener = MockEventListener();

    setUp(() {
      unleashClient = MockUnleashClient();
      when(() => unleashClient.on<dynamic>('update', any()))
          .thenReturn(eventListener);
      registerFallbackValue(MockBuildContext());
      registerFallbackValue(Variant.defaultVariant);
      when(() => unleashClient.removeEventListener(eventListener))
          .thenReturn(true);
    });

    testWidgets('render "enabled" when "example" variant is enabled',
        (tester) async {
      when(() => unleashClient.getVariant('flutter-feature'))
          .thenReturn(Variant(name: 'example', enabled: true));
      await tester.pumpWidget(MaterialApp(
        home: VariantBuilder(
          featureName: 'flutter-feature',
          unleashClient: unleashClient,
          build: (variant, context) =>
              Text(variant.name == 'example' ? 'Enabled' : 'Disabled'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Enabled'), findsOneWidget);
    });

    testWidgets('render "disabled" when "another-example" variant is enabled',
        (tester) async {
      when(() => unleashClient.getVariant('flutter-feature'))
          .thenReturn(Variant(name: 'another-example', enabled: true));
      await tester.pumpWidget(MaterialApp(
        home: VariantBuilder(
          featureName: 'flutter-feature',
          unleashClient: unleashClient,
          build: (variant, context) =>
              Text(variant.name == 'example' ? 'Enabled' : 'Disabled'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('widget is updated if variant has changed', (tester) async {
      when(() => unleashClient.getVariant('flutter-variant'))
          .thenReturn(Variant.defaultVariant);
      await tester.pumpWidget(MaterialApp(
        home: VariantBuilder(
          featureName: 'flutter-variant',
          unleashClient: unleashClient,
          build: (variant, context) => Text(
              variant.name == Variant.defaultVariant.name
                  ? 'Disabled'
                  : 'Enabled'),
        ),
      ));
      await tester.pumpAndSettle();
      final void Function(dynamic) callback =
          verify(() => unleashClient.on<dynamic>('update', captureAny()))
              .captured
              .single;
      expect(find.text('Disabled'), findsOneWidget);
      when(() => unleashClient.getVariant('flutter-variant'))
          .thenReturn(Variant(name: 'example', enabled: true));
      callback(null);
      await tester.pumpAndSettle();
      expect(find.text('Enabled'), findsOneWidget);
    });

    testWidgets("widget is not rebuilt when variant hasn't changed",
        (tester) async {
      when(() => unleashClient.getVariant('flutter-feature'))
          .thenReturn(Variant.defaultVariant);
      final build = MockBuild();
      when(() => build(any(), any())).thenReturn(const SizedBox());
      await tester.pumpWidget(MaterialApp(
        home: VariantBuilder(
          featureName: 'flutter-feature',
          unleashClient: unleashClient,
          build: build,
        ),
      ));
      verify(() => build(Variant.defaultVariant, any())).called(1);
      final void Function(dynamic) callback =
          verify(() => unleashClient.on<dynamic>('update', captureAny()))
              .captured
              .single;
      callback(null);
      verifyNever(() => build(any(), any()));
    });

    testWidgets('listener is removed when widget is disposed', (tester) async {
      when(() => unleashClient.getVariant('flutter-feature'))
          .thenReturn(Variant.defaultVariant);
      await tester.pumpWidget(MaterialApp(
        home: VariantBuilder(
          featureName: 'flutter-feature',
          unleashClient: unleashClient,
          build: (variant, context) =>
              Text(variant.enabled ? 'Enabled' : 'Disabled'),
        ),
      ));
      await tester.pumpAndSettle();
      verify(() => unleashClient.on<dynamic>('update', any())).called(1);
      await tester.pumpWidget(const SizedBox());
      verify(() => unleashClient.removeEventListener(eventListener)).called(1);
    });
  });
}
