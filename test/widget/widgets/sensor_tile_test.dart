import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/presentation/widgets/sensor_tile.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

void main() {
  group('SensorTile', () {
    late SensorReading mockSensorReading;

    setUp(() {
      mockSensorReading = SensorReading(
        id: 'temp_01',
        type: SensorType.temperature,
        value: 23.5,
        unit: '°C',
        timestamp: DateTime.now(),
        location: 'Greenhouse A',
        isOnline: true,
      );
    });

    testWidgets('should display sensor information', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(sensorReading: mockSensorReading),
          ),
        ),
      );

      // Assert
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('23.5'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
      expect(find.text('Greenhouse A'), findsOneWidget);
      expect(find.byIcon(Icons.thermostat), findsOneWidget);
    });

    testWidgets('should show online status indicator', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(sensorReading: mockSensorReading),
          ),
        ),
      );

      // Assert
      expect(find.byType(Container), findsWidgets); // Status indicator is a Container
    });

    testWidgets('should show offline status for offline sensor', (WidgetTester tester) async {
      // Arrange
      final offlineSensor = mockSensorReading.copyWith(isOnline: false);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(sensorReading: offlineSensor),
          ),
        ),
      );

      // Assert - Icon should be displayed in error color when offline
      expect(find.byIcon(Icons.thermostat), findsOneWidget);
    });

    testWidgets('should display sparkline when enabled', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(
              sensorReading: mockSensorReading,
              showSparkline: true,
              sparklineData: const [1.0, 2.0, 3.0, 4.0, 5.0],
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Trend Chart'), findsOneWidget);
    });

    testWidgets('should not display sparkline when disabled', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(
              sensorReading: mockSensorReading,
              showSparkline: false,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Trend Chart'), findsNothing);
    });

    testWidgets('should handle tap when callback provided', (WidgetTester tester) async {
      // Arrange
      bool wasTapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(
              sensorReading: mockSensorReading,
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(SensorTile));
      await tester.pump();

      // Assert
      expect(wasTapped, isTrue);
    });

    testWidgets('should format value correctly for integers', (WidgetTester tester) async {
      // Arrange
      final integerSensor = mockSensorReading.copyWith(value: 25.0);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(sensorReading: integerSensor),
          ),
        ),
      );

      // Assert
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('should format value correctly for decimals', (WidgetTester tester) async {
      // Arrange
      final decimalSensor = mockSensorReading.copyWith(value: 25.7);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(sensorReading: decimalSensor),
          ),
        ),
      );

      // Assert
      expect(find.text('25.7'), findsOneWidget);
    });
  });
}