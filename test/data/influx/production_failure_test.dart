import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/time_series_point.dart';
import 'package:hydroponic_monitor/presentation/pages/charts_page.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/core/logger.dart';

/// Integration test validating production-ready failure behavior.
/// Ensures that InfluxDB service returns explicit failures instead of
/// masking infrastructure issues with synthetic data.
void main() {
  group('Production Readiness - Failure Propagation', () {
    late InfluxDbService influxService;

    setUp(() {
      Logger.init(isTest: true);
      Logger.info('Setting up production failure test', tag: 'ProdReadiness');

      influxService = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );
    });

    test(
      'querySensorData returns InfluxUnavailableError when not initialized',
      () async {
        Logger.info(
          'Testing querySensorData failure propagation',
          tag: 'ProdReadiness',
        );

        final result = await influxService.querySensorData(
          sensorType: SensorType.temperature,
          start: DateTime.now().subtract(const Duration(hours: 1)),
          end: DateTime.now(),
          limit: 10,
        );

        // Verify explicit failure instead of synthetic data
        expect(result, isA<Failure<List<SensorData>>>());
        final error = (result as Failure<List<SensorData>>).error;
        expect(error, isA<InfluxUnavailableError>());
        expect(error.message, equals('InfluxDB client not initialized'));

        Logger.info(
          '✓ querySensorData correctly returns failure',
          tag: 'ProdReadiness',
        );
      },
    );

    test(
      'queryLatestSensorData returns InfluxUnavailableError when not initialized',
      () async {
        Logger.info(
          'Testing queryLatestSensorData failure propagation',
          tag: 'ProdReadiness',
        );

        final result = await influxService.queryLatestSensorData();

        // Verify explicit failure instead of synthetic data
        expect(result, isA<Failure<List<SensorData>>>());
        final error = (result as Failure<List<SensorData>>).error;
        expect(error, isA<InfluxUnavailableError>());
        expect(error.message, equals('InfluxDB client not initialized'));

        Logger.info(
          '✓ queryLatestSensorData correctly returns failure',
          tag: 'ProdReadiness',
        );
      },
    );

    test(
      'queryTimeSeries returns InfluxUnavailableError when not initialized',
      () async {
        Logger.info(
          'Testing queryTimeSeries failure propagation',
          tag: 'ProdReadiness',
        );

        final result = await influxService.queryTimeSeries(
          SensorType.humidity,
          ChartRange.hours24,
        );

        // Verify explicit failure instead of synthetic data
        expect(result, isA<Failure<List<TimeSeriesPoint>>>());
        final error = (result as Failure<List<TimeSeriesPoint>>).error;
        expect(error, isA<InfluxUnavailableError>());
        expect(error.message, equals('InfluxDB client not initialized'));

        Logger.info(
          '✓ queryTimeSeries correctly returns failure',
          tag: 'ProdReadiness',
        );
      },
    );

    test(
      'all sensor types produce explicit failures when service unavailable',
      () async {
        Logger.info(
          'Testing failure propagation for all sensor types',
          tag: 'ProdReadiness',
        );

        for (final sensorType in SensorType.values) {
          final result = await influxService.querySensorData(
            sensorType: sensorType,
            start: DateTime.now().subtract(const Duration(hours: 1)),
            end: DateTime.now(),
            limit: 5,
          );

          expect(
            result,
            isA<Failure<List<SensorData>>>(),
            reason: '${sensorType.name} should return Failure',
          );

          final error = (result as Failure<List<SensorData>>).error;
          expect(
            error,
            isA<InfluxUnavailableError>(),
            reason: '${sensorType.name} should return InfluxUnavailableError',
          );
        }

        Logger.info(
          '✓ All ${SensorType.values.length} sensor types correctly return failures',
          tag: 'ProdReadiness',
        );
      },
    );

    tearDown(() async {
      Logger.info('Tearing down production failure test', tag: 'ProdReadiness');
      await influxService.close();
    });
  });
}
