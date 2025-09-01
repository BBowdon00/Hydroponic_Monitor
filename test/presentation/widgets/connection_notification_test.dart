import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/presentation/widgets/connection_notification.dart';
import 'package:hydroponic_monitor/presentation/providers/connection_status_provider.dart';

void main() {
  group('ConnectionNotification', () {
    testWidgets('shows notification when services are disconnected', (
      WidgetTester tester,
    ) async {
      // Create a container with mock disconnected state
      final container = ProviderContainer(
        overrides: [
          connectionStatusProvider.overrideWith((ref) async* {
            yield const ConnectionStatus(
              mqttConnected: false,
              influxConnected: false,
              mqttDisconnectedSince: null,
              influxDisconnectedSince: null,
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ConnectionNotification()),
          ),
        ),
      );

      // Wait for the stream to emit
      await tester.pump();

      // Verify notification is shown
      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('MQTT, InfluxDB disconnected'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('hides notification when all services are connected', (
      WidgetTester tester,
    ) async {
      // Create a container with mock connected state
      final container = ProviderContainer(
        overrides: [
          connectionStatusProvider.overrideWith((ref) async* {
            yield const ConnectionStatus(
              mqttConnected: true,
              influxConnected: true,
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ConnectionNotification()),
          ),
        ),
      );

      // Wait for the stream to emit
      await tester.pump();

      // Verify notification is hidden
      expect(find.text('Connection Lost'), findsNothing);
    });

    testWidgets('shows partial disconnection correctly', (
      WidgetTester tester,
    ) async {
      // Create a container with one service disconnected
      final container = ProviderContainer(
        overrides: [
          connectionStatusProvider.overrideWith((ref) async* {
            yield const ConnectionStatus(
              mqttConnected: true,
              influxConnected: false,
              influxDisconnectedSince: null,
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ConnectionNotification()),
          ),
        ),
      );

      // Wait for the stream to emit
      await tester.pump();

      // Verify notification shows only disconnected service
      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('InfluxDB disconnected'), findsOneWidget);
      expect(find.textContaining('MQTT'), findsNothing);
    });
  });
}
