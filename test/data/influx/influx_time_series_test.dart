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
      test('returns failure when client not initialized', () async {
        Logger.info(
          'Testing time series returns failure with uninitialized client',
          tag: 'TimeSeriesTest',
        );

        final result = await influxService.queryTimeSeries(
          SensorType.temperature,
          ChartRange.hours24,
        );

        expect(result, isA<Failure<List<TimeSeriesPoint>>>());
        final error = (result as Failure<List<TimeSeriesPoint>>).error;

        Logger.debug(
          'Received expected failure: ${error.message}',
          tag: 'TimeSeriesTest',
        );

        expect(error, isA<InfluxUnavailableError>());
        expect(error.message, equals('InfluxDB client not initialized'));
      });

      test('returns failure for all ranges when not initialized', () async {
        Logger.info(
          'Testing that all ranges return failure when not initialized',
          tag: 'TimeSeriesTest',
        );

        final ranges = [
          ChartRange.hour1,
          ChartRange.hours24,
          ChartRange.days7,
          ChartRange.days30,
        ];

        for (final range in ranges) {
          final result = await influxService.queryTimeSeries(
            SensorType.temperature,
            range,
          );

          expect(result, isA<Failure<List<TimeSeriesPoint>>>());
          final error = (result as Failure<List<TimeSeriesPoint>>).error;
          expect(error, isA<InfluxUnavailableError>());

          Logger.debug(
            'Range ${range.name}: correctly returned failure',
            tag: 'TimeSeriesTest',
          );
        }
      });

      test(
        'returns failure for chronological ordering check when not initialized',
        () async {
          Logger.info(
            'Testing that ordering check returns failure when not initialized',
            tag: 'TimeSeriesTest',
          );

          final result = await influxService.queryTimeSeries(
            SensorType.temperature,
            ChartRange.hours24,
          );

          expect(result, isA<Failure<List<TimeSeriesPoint>>>());
          final error = (result as Failure<List<TimeSeriesPoint>>).error;
          expect(error, isA<InfluxUnavailableError>());

          Logger.info('Ordering check failure verified', tag: 'TimeSeriesTest');
        },
      );

      test(
        'returns failure for deterministic data check when not initialized',
        () async {
          Logger.info(
            'Testing that deterministic check returns failure when not initialized',
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

          expect(result1, isA<Failure<List<TimeSeriesPoint>>>());
          expect(result2, isA<Failure<List<TimeSeriesPoint>>>());

          Logger.info(
            'Deterministic check failure verified',
            tag: 'TimeSeriesTest',
          );
        },
      );

      test(
        'returns failure for realistic values check when not initialized',
        () async {
          Logger.info(
            'Testing that realistic values check returns failure when not initialized',
            tag: 'TimeSeriesTest',
          );

          for (final sensorType in SensorType.values) {
            final result = await influxService.queryTimeSeries(
              sensorType,
              ChartRange.hour1,
            );

            expect(result, isA<Failure<List<TimeSeriesPoint>>>());
            final error = (result as Failure<List<TimeSeriesPoint>>).error;
            expect(error, isA<InfluxUnavailableError>());

            Logger.debug(
              '${sensorType.name}: correctly returned failure',
              tag: 'TimeSeriesTest',
            );
          }
        },
      );
    });
  });
}
