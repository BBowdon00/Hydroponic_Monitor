import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/time_series_point.dart';
import 'package:hydroponic_monitor/presentation/pages/charts_page.dart';
import 'package:hydroponic_monitor/presentation/providers/chart_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/core/logger.dart';

class MockSensorRepository extends Mock implements SensorRepository {}

class MockInfluxDbService extends Mock implements InfluxDbService {}

class MockMqttService extends Mock implements MqttService {}

void main() {
  setUpAll(() {
    Logger.init(isTest: true);
  });

  group('ChartStats', () {
    test('calculates stats correctly from points', () {
      final points = [
        TimeSeriesPoint(timestamp: DateTime.now(), value: 10.0),
        TimeSeriesPoint(
          timestamp: DateTime.now().add(const Duration(hours: 1)),
          value: 20.0,
        ),
        TimeSeriesPoint(
          timestamp: DateTime.now().add(const Duration(hours: 2)),
          value: 30.0,
        ),
      ];

      final stats = ChartStats.fromPoints(points);

      expect(stats.min, equals(10.0));
      expect(stats.max, equals(30.0));
      expect(stats.average, equals(20.0));
    });

    test('handles empty points list', () {
      final stats = ChartStats.fromPoints([]);

      expect(stats.min, equals(0.0));
      expect(stats.max, equals(0.0));
      expect(stats.average, equals(0.0));
    });

    test('handles single point', () {
      final points = [
        TimeSeriesPoint(timestamp: DateTime.now(), value: 15.5),
      ];

      final stats = ChartStats.fromPoints(points);

      expect(stats.min, equals(15.5));
      expect(stats.max, equals(15.5));
      expect(stats.average, equals(15.5));
    });

    test('formats values to 2 decimal places', () {
      final points = [
        TimeSeriesPoint(timestamp: DateTime.now(), value: 10.123456),
        TimeSeriesPoint(
          timestamp: DateTime.now().add(const Duration(hours: 1)),
          value: 20.987654,
        ),
      ];

      final stats = ChartStats.fromPoints(points);

      expect(stats.min, equals(10.12));
      expect(stats.max, equals(20.99));
      expect(stats.average, equals(15.56));
    });
  });

  group('Chart Providers', () {
    test('chartDataRefreshTriggerProvider initializes to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final trigger = container.read(chartDataRefreshTriggerProvider);
      expect(trigger, equals(0));
    });

    test('chartDataRefreshTriggerProvider can be incremented', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(chartDataRefreshTriggerProvider.notifier).state++;
      final trigger = container.read(chartDataRefreshTriggerProvider);
      expect(trigger, equals(1));
    });

    test('sensorChartDataProvider fetches data for sensor type and range',
        () async {
      final mockRepository = MockSensorRepository();
      final mockInflux = MockInfluxDbService();
      final mockMqtt = MockMqttService();

      final now = DateTime.now();
      final mockPoints = [
        TimeSeriesPoint(timestamp: now, value: 20.0),
        TimeSeriesPoint(
          timestamp: now.add(const Duration(hours: 1)),
          value: 22.0,
        ),
        TimeSeriesPoint(
          timestamp: now.add(const Duration(hours: 2)),
          value: 24.0,
        ),
      ];

      when(
        () => mockRepository.getSensorTimeSeries(
          SensorType.temperature,
          ChartRange.hour1,
        ),
      ).thenAnswer((_) async => Success(mockPoints));

      final container = ProviderContainer(
        overrides: [
          sensorRepositoryProvider.overrideWithValue(mockRepository),
          influxServiceProvider.overrideWithValue(mockInflux),
          mqttServiceProvider.overrideWithValue(mockMqtt),
        ],
      );
      addTearDown(container.dispose);

      final chartData = await container.read(
        sensorChartDataProvider(
          (sensorType: SensorType.temperature, range: ChartRange.hour1),
        ).future,
      );

      expect(chartData.points.length, equals(3));
      expect(chartData.stats.min, equals(20.0));
      expect(chartData.stats.max, equals(24.0));
      expect(chartData.stats.average, equals(22.0));

      verify(
        () => mockRepository.getSensorTimeSeries(
          SensorType.temperature,
          ChartRange.hour1,
        ),
      ).called(1);
    });

    test('sensorChartDataProvider invalidates on refresh trigger change',
        () async {
      final mockRepository = MockSensorRepository();
      final mockInflux = MockInfluxDbService();
      final mockMqtt = MockMqttService();

      final now = DateTime.now();
      final mockPoints = [
        TimeSeriesPoint(timestamp: now, value: 20.0),
      ];

      when(
        () => mockRepository.getSensorTimeSeries(
          SensorType.temperature,
          ChartRange.hour1,
        ),
      ).thenAnswer((_) async => Success(mockPoints));

      final container = ProviderContainer(
        overrides: [
          sensorRepositoryProvider.overrideWithValue(mockRepository),
          influxServiceProvider.overrideWithValue(mockInflux),
          mqttServiceProvider.overrideWithValue(mockMqtt),
        ],
      );
      addTearDown(container.dispose);

      // First fetch
      await container.read(
        sensorChartDataProvider(
          (sensorType: SensorType.temperature, range: ChartRange.hour1),
        ).future,
      );

      // Increment refresh trigger
      container.read(chartDataRefreshTriggerProvider.notifier).state++;

      // Second fetch - should call repository again
      await container.read(
        sensorChartDataProvider(
          (sensorType: SensorType.temperature, range: ChartRange.hour1),
        ).future,
      );

      verify(
        () => mockRepository.getSensorTimeSeries(
          SensorType.temperature,
          ChartRange.hour1,
        ),
      ).called(2);
    });
  });
}
