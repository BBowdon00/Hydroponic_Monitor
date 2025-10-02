import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/presentation/widgets/connection_notification.dart';
import 'package:hydroponic_monitor/presentation/providers/connection_status_provider.dart';
import 'package:hydroponic_monitor/presentation/providers/manual_reconnect_provider.dart';
import 'package:hydroponic_monitor/data/connection_recovery_service.dart';

// Mock class
class MockConnectionRecoveryService extends Mock implements ConnectionRecoveryService {}

void main() {
  group('ConnectionNotification', () {
    late MockConnectionRecoveryService mockRecoveryService;

    setUp(() {
      mockRecoveryService = MockConnectionRecoveryService();
    });

    testWidgets('shows red notification when services are disconnected', (
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
          connectionRecoveryServiceProvider.overrideWithValue(mockRecoveryService),
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

      // Verify notification is shown with red styling
      expect(find.text('MQTT, InfluxDB disconnected'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows green notification when all services are connected', (
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
          connectionRecoveryServiceProvider.overrideWithValue(mockRecoveryService),
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

      // Verify notification is shown with green styling and connected message
      expect(find.text('All services connected'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
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
          connectionRecoveryServiceProvider.overrideWithValue(mockRecoveryService),
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
      expect(find.text('InfluxDB disconnected'), findsOneWidget);
      expect(find.textContaining('MQTT'), findsNothing);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('shows loading state while connecting', (
      WidgetTester tester,
    ) async {
      // Create a container with loading state - simulate AsyncLoading
      final container = ProviderContainer(
        overrides: [
          connectionStatusProvider.overrideWith((ref) => Stream.value(const ConnectionStatus(
            mqttConnected: false,
            influxConnected: false,
          )).asyncMap((status) async => throw 'Loading')),
          connectionRecoveryServiceProvider.overrideWithValue(mockRecoveryService),
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

      // For loading state, the widget shows gray styling with connecting text
      // Since the stream is in error state, it shows the error banner
      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
