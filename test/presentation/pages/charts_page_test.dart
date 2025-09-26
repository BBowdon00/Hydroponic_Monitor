import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/presentation/pages/charts_page.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/domain/entities/time_series_point.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

class MockSensorRepository extends Mock implements SensorRepository {}

void main() {
  group('ChartsPage Widget Tests', () {
    late MockSensorRepository mockRepository;

    setUp(() {
      mockRepository = MockSensorRepository();
      registerFallbackValue(SensorType.temperature);
      registerFallbackValue(ChartRange.hours24);
    });

    testWidgets('displays chart range selector', (WidgetTester tester) async {
      // Mock successful time series data
      when(() => mockRepository.getSensorTimeSeries(
        any(),
        any(),
      )).thenAnswer((_) async => Success([
        TimeSeriesPoint(timestamp: DateTime.now().subtract(Duration(hours: 1)), value: 24.0),
        TimeSeriesPoint(timestamp: DateTime.now(), value: 25.0),
      ]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: ChartsPage(),
          ),
        ),
      );

      // Wait for initial build
      await tester.pump();

      // Verify page title
      expect(find.text('Charts & Analytics'), findsOneWidget);

      // Verify time range selector section
      expect(find.text('Time Range'), findsOneWidget);

      // Verify range options are displayed
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('24h'), findsOneWidget);
      expect(find.text('7d'), findsOneWidget);

      // Verify refresh button
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('displays sensor chart cards', (WidgetTester tester) async {
      // Mock successful time series data for all sensor types
      when(() => mockRepository.getSensorTimeSeries(
        any(),
        any(),
      )).thenAnswer((_) async => Success([
        TimeSeriesPoint(timestamp: DateTime.now().subtract(Duration(hours: 1)), value: 24.0),
        TimeSeriesPoint(timestamp: DateTime.now(), value: 25.0),
      ]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: ChartsPage(),
          ),
        ),
      );

      // Wait for charts to load
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100));

      // Verify sensor type cards are present (check for some of them)
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('Water Level'), findsOneWidget);

      // Verify that chart cards are displayed
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('handles loading state', (WidgetTester tester) async {
      // Mock delayed response to test loading state
      when(() => mockRepository.getSensorTimeSeries(
        any(),
        any(),
      )).thenAnswer((_) async {
        await Future.delayed(Duration(seconds: 1));
        return Success([
          TimeSeriesPoint(timestamp: DateTime.now(), value: 25.0),
        ]);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: ChartsPage(),
          ),
        ),
      );

      // Initial pump
      await tester.pump();

      // Should show loading indicators
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('allows range selection', (WidgetTester tester) async {
      when(() => mockRepository.getSensorTimeSeries(
        any(),
        any(),
      )).thenAnswer((_) async => Success([
        TimeSeriesPoint(timestamp: DateTime.now(), value: 25.0),
      ]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: ChartsPage(),
          ),
        ),
      );

      await tester.pump();

      // Initially 24h should be selected (default)
      final chip24h = find.widgetWithText(FilterChip, '24h');
      expect(chip24h, findsOneWidget);

      // Tap on 1h range
      await tester.tap(find.widgetWithText(FilterChip, '1h'));
      await tester.pump();

      // This should trigger a new data fetch with 1h range
      verify(() => mockRepository.getSensorTimeSeries(
        any(),
        ChartRange.hour1,
      )).called(greaterThan(0));
    });
  });
}