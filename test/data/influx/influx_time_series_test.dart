import 'package:flutter_test/flutter_test.dart';

import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/time_series_point.dart';
import 'package:hydroponic_monitor/presentation/pages/charts_page.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/core/logger.dart';

void main() {
  group('InfluxDbService Time Series', () {
    late InfluxDbService influxService;

    setUp(() {
      Logger.init(isTest: true);
      Logger.info('Setting up time series test', tag: 'TimeSeriesTest');

      influxService = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );
    });

    group('queryTimeSeries', () {
      test('returns dummy data when client not initialized', () async {
        Logger.info(
          'Testing time series with uninitialized client',
          tag: 'TimeSeriesTest',
        );

        final result = await influxService.queryTimeSeries(
          SensorType.temperature,
          ChartRange.hours24,
        );

        expect(result, isA<Success<List<TimeSeriesPoint>>>());
        final points = (result as Success<List<TimeSeriesPoint>>).data;

        Logger.debug(
          'Generated ${points.length} time series points',
          tag: 'TimeSeriesTest',
        );

        // Should have reasonable number of points for 24h range
        expect(points.length, equals(24));
      });

      test('generates correct number of points for each range', () async {
        Logger.info(
          'Testing point count for different ranges',
          tag: 'TimeSeriesTest',
        );

        final ranges = {
          ChartRange.hour1: 12,
          ChartRange.hours24: 24,
          ChartRange.days7: 56,
          ChartRange.days30: 60,
        };

        for (final entry in ranges.entries) {
          final result = await influxService.queryTimeSeries(
            SensorType.temperature,
            entry.key,
          );

          expect(result, isA<Success<List<TimeSeriesPoint>>>());
          final points = (result as Success<List<TimeSeriesPoint>>).data;

          expect(
            points.length,
            equals(entry.value),
            reason: 'Range ${entry.key.name} should have ${entry.value} points',
          );

          Logger.debug(
            'Range ${entry.key.name}: ${points.length} points',
            tag: 'TimeSeriesTest',
          );
        }
      });

      test('points are ordered chronologically', () async {
        Logger.info(
          'Testing chronological ordering of points',
          tag: 'TimeSeriesTest',
        );

        final result = await influxService.queryTimeSeries(
          SensorType.temperature,
          ChartRange.hours24,
        );

        expect(result, isA<Success<List<TimeSeriesPoint>>>());
        final points = (result as Success<List<TimeSeriesPoint>>).data;

        // Check that each point's timestamp is after the previous
        for (int i = 1; i < points.length; i++) {
          expect(
            points[i].timestamp.isAfter(points[i - 1].timestamp),
            isTrue,
            reason: 'Point $i should be after point ${i - 1}',
          );
        }

        Logger.info('Chronological ordering verified', tag: 'TimeSeriesTest');
      });

      test('generates deterministic data for same sensor and range', () async {
        Logger.info(
          'Testing deterministic dummy data generation',
          tag: 'TimeSeriesTest',
        );

        final result1 = await influxService.queryTimeSeries(
          SensorType.temperature,
          ChartRange.hour1,
        );

        final result2 = await influxService.queryTimeSeries(
          SensorType.temperature,
          ChartRange.hour1,
        );

        expect(result1, isA<Success<List<TimeSeriesPoint>>>());
        expect(result2, isA<Success<List<TimeSeriesPoint>>>());

        final points1 = (result1 as Success<List<TimeSeriesPoint>>).data;
        final points2 = (result2 as Success<List<TimeSeriesPoint>>).data;

        expect(points1.length, equals(points2.length));

        // First few values should match (deterministic seeding)
        for (int i = 0; i < 3 && i < points1.length; i++) {
          expect(
            points1[i].value,
            equals(points2[i].value),
            reason: 'Point $i should have same value across runs',
          );
        }

        Logger.info(
          'Deterministic generation verified',
          tag: 'TimeSeriesTest',
        );
      });

      test('generates realistic values for each sensor type', () async {
        Logger.info(
          'Testing realistic value ranges',
          tag: 'TimeSeriesTest',
        );

        for (final sensorType in SensorType.values) {
          final result = await influxService.queryTimeSeries(
            sensorType,
            ChartRange.hour1,
          );

          expect(result, isA<Success<List<TimeSeriesPoint>>>());
          final points = (result as Success<List<TimeSeriesPoint>>).data;

          // All values should be positive
          for (final point in points) {
            expect(point.value, greaterThan(0));
          }

          // Check sensor-specific ranges
          switch (sensorType) {
            case SensorType.temperature:
              for (final point in points) {
                expect(point.value, inInclusiveRange(15.0, 35.0));
              }
              break;
            case SensorType.humidity:
              for (final point in points) {
                expect(point.value, inInclusiveRange(30.0, 90.0));
              }
              break;
            case SensorType.pH:
              for (final point in points) {
                expect(point.value, inInclusiveRange(5.5, 7.5));
              }
              break;
            case SensorType.waterLevel:
              for (final point in points) {
                expect(point.value, inInclusiveRange(5.0, 30.0));
              }
              break;
            default:
              // Other sensor types just need positive values
              break;
          }

          Logger.debug(
            '${sensorType.name}: verified ${points.length} points',
            tag: 'TimeSeriesTest',
          );
        }
      });
    });
  });
}
