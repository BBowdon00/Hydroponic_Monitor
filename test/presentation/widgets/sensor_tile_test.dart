import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/presentation/widgets/sensor_tile.dart';
import 'package:flutter/material.dart';

void main() {
  group('SensorTile Stale Data Tests', () {
    testWidgets('shows stale indicator for old data', (
      WidgetTester tester,
    ) async {
      // Create a timestamp that's more than 60 seconds old
      final staleTimestamp = DateTime.now().subtract(
        const Duration(seconds: 90),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(
              title: 'Temperature',
              value: '23.5°C',
              unit: '°C',
              icon: Icons.thermostat,
              color: Colors.orange,
              trend: SensorTrend.stable,
              lastUpdated: staleTimestamp,
            ),
          ),
        ),
      );

      // Verify stale indicator is shown
      expect(find.text('Stale (1m ago)'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('does not show stale indicator for fresh data', (
      WidgetTester tester,
    ) async {
      // Create a timestamp that's less than 60 seconds old
      final freshTimestamp = DateTime.now().subtract(
        const Duration(seconds: 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(
              title: 'Temperature',
              value: '23.5°C',
              unit: '°C',
              icon: Icons.thermostat,
              color: Colors.orange,
              trend: SensorTrend.stable,
              lastUpdated: freshTimestamp,
            ),
          ),
        ),
      );

      // Verify stale indicator is NOT shown
      expect(find.textContaining('Stale'), findsNothing);
      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    testWidgets('shows no indicator when lastUpdated is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SensorTile(
              title: 'Temperature',
              value: '23.5°C',
              unit: '°C',
              icon: Icons.thermostat,
              color: Colors.orange,
              trend: SensorTrend.stable,
              lastUpdated: null, // No timestamp
            ),
          ),
        ),
      );

      // Verify stale indicator is NOT shown
      expect(find.textContaining('Stale'), findsNothing);
      expect(find.byIcon(Icons.schedule), findsNothing);
    });
  });
}
