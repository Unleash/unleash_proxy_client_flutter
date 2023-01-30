import 'package:events_emitter/listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unleash_proxy_client_flutter/flag_builder.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';

class MockUnleashClient extends Mock implements UnleashClient {}

class MockEventListener extends Mock implements EventListener {}

class MockBuild extends Mock {
  Widget call(bool isEnabled, BuildContext context);
}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('FlagBuilder', () {
    late UnleashClient unleashClient;
    final EventListener<dynamic> eventListener = MockEventListener();

    setUp(() {
      unleashClient = MockUnleashClient();
      when(() => unleashClient.on<dynamic>('update', any()))
          .thenReturn(eventListener);
      registerFallbackValue(MockBuildContext());
      when(() => unleashClient.removeEventListener(eventListener))
          .thenReturn(true);
    });

    testWidgets('render "enabled" when flag is enabled', (tester) async {
      when(() => unleashClient.isEnabled('flutter-on')).thenReturn(true);
      await tester.pumpWidget(MaterialApp(
        home: FlagBuilder(
          flag: 'flutter-on',
          unleashClient: unleashClient,
          build: (isEnabled, context) =>
              Text(isEnabled ? 'Enabled' : 'Disabled'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Enabled'), findsOneWidget);
    });

    testWidgets('render "disabled" when flag is disabled', (tester) async {
      when(() => unleashClient.isEnabled('flutter-off')).thenReturn(false);
      await tester.pumpWidget(MaterialApp(
        home: FlagBuilder(
          flag: 'flutter-off',
          unleashClient: unleashClient,
          build: (isEnabled, context) =>
              Text(isEnabled ? 'Enabled' : 'Disabled'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('widget is updated if flag has changed', (tester) async {
      when(() => unleashClient.isEnabled('flutter-on')).thenReturn(true);
      await tester.pumpWidget(MaterialApp(
        home: FlagBuilder(
          flag: 'flutter-on',
          unleashClient: unleashClient,
          build: (isEnabled, context) =>
              Text(isEnabled ? 'Enabled' : 'Disabled'),
        ),
      ));
      await tester.pumpAndSettle();
      final void Function(dynamic) callback =
          verify(() => unleashClient.on<dynamic>('update', captureAny()))
              .captured
              .single;
      expect(find.text('Enabled'), findsOneWidget);
      when(() => unleashClient.isEnabled('flutter-on')).thenReturn(false);
      callback(null);
      await tester.pumpAndSettle();
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets("widget is not built when flag hasn't changed", (tester) async {
      when(() => unleashClient.isEnabled('flutter-on')).thenReturn(true);
      final build = MockBuild();
      when(() => build(any(), any())).thenReturn(const SizedBox());
      await tester.pumpWidget(MaterialApp(
        home: FlagBuilder(
          flag: 'flutter-on',
          unleashClient: unleashClient,
          build: build,
        ),
      ));
      verify(() => build(true, any())).called(1);
      final void Function(dynamic) callback =
          verify(() => unleashClient.on<dynamic>('update', captureAny()))
              .captured
              .single;
      callback(null);
      verifyNever(() => build(any(), any()));
    });

    testWidgets('listener is removed when widget is disposed', (tester) async {
      when(() => unleashClient.isEnabled('flutter-on')).thenReturn(true);
      await tester.pumpWidget(MaterialApp(
        home: FlagBuilder(
          flag: 'flutter-on',
          unleashClient: unleashClient,
          build: (isEnabled, context) =>
              Text(isEnabled ? 'Enabled' : 'Disabled'),
        ),
      ));
      await tester.pumpAndSettle();
      verify(() => unleashClient.on<dynamic>('update', any())).called(1);
      await tester.pumpWidget(const SizedBox());
      verify(() => unleashClient.removeEventListener(eventListener)).called(1);
    });
  });
}
