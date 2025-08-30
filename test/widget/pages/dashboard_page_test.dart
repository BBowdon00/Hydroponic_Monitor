import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/presentation/pages/dashboard_page.dart';
import 'package:hydroponic_monitor/presentation/providers/sensor_providers.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

void main() {
  group('DashboardPage', () {
    testWidgets('should display loading state initially', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardPage(),
          ),
        ),
      );

      // Act & Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display sensor tiles when data loads', (WidgetTester tester) async {
      // Arrange
      final mockSensorData = [
        SensorReading(
          id: 'temp_01',
          type: SensorType.temperature,
          value: 22.5,
          unit: '°C',
          timestamp: DateTime.now(),
          location: 'Test Location',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorDataProvider.overrideWith(
              (ref) => Stream.value(mockSensorData),
            ),
          ],
          child: MaterialApp(
            home: const DashboardPage(),
          ),
        ),
      );

      // Act
      await tester.pump(); // Trigger initial build
      await tester.pump(); // Allow stream to emit

      // Assert
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('22.5'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
    });

    testWidgets('should display error state when data fails to load', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorDataProvider.overrideWith(
              (ref) => Stream.error('Network error'),
            ),
          ],
          child: MaterialApp(
            home: const DashboardPage(),
          ),
        ),
      );

      // Act
      await tester.pump(); // Trigger initial build
      await tester.pump(); // Allow stream to emit error

      // Assert
      expect(find.text('Failed to load sensor data'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('should show refresh button in app bar', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const DashboardPage(),
          ),
        ),
      );

      // Act & Assert
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byTooltip('Refresh data'), findsOneWidget);
    });

    testWidgets('should display system status card', (WidgetTester tester) async {
      // Arrange
      final mockSensorData = [
        SensorReading(
          id: 'temp_01',
          type: SensorType.temperature,
          value: 22.5,
          unit: '°C',
          timestamp: DateTime.now(),
          isOnline: true,
        ),
        SensorReading(
          id: 'humid_01',
          type: SensorType.humidity,
          value: 65.0,
          unit: '%',
          timestamp: DateTime.now(),
          isOnline: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorDataProvider.overrideWith(
              (ref) => Stream.value(mockSensorData),
            ),
          ],
          child: MaterialApp(
            home: const DashboardPage(),
          ),
        ),
      );

      // Act
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.text('System Status'), findsOneWidget);
      expect(find.text('2 sensors online'), findsOneWidget);
    });
  });
}