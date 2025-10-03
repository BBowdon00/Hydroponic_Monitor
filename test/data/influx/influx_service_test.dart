import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/core/logger.dart';

class MockInfluxDbService extends Mock implements InfluxDbService {}

void main() {
  group('InfluxDbService', () {
    late InfluxDbService influxService;

    setUp(() {
      Logger.init(isTest: true);
      Logger.info('Setting up InfluxDbService test', tag: 'InfluxTest');

      influxService = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );
    });

    test('initializes with correct configuration', () {
      Logger.info('Testing InfluxDB service initialization', tag: 'InfluxTest');

      expect(influxService.url, equals('http://localhost:8086'));
      expect(influxService.token, equals('test-token'));
      expect(influxService.organization, equals('test-org'));
      expect(influxService.bucket, equals('test-bucket'));

      Logger.info(
        'InfluxDB configuration validation passed',
        tag: 'InfluxTest',
      );
    });

    test('returns failure when client not initialized', () async {
      Logger.info(
        'Testing that service returns failure when not initialized',
        tag: 'InfluxTest',
      );

      // The service now returns Failure when not initialized (production-ready behavior)
      // This ensures infrastructure issues are visible instead of being masked by dummy data
      final result = await influxService.queryLatestSensorData();

      expect(result, isA<Failure<List<SensorData>>>());
      final error = (result as Failure<List<SensorData>>).error;

      Logger.debug(
        'Received expected failure: ${error.message}',
        tag: 'InfluxTest',
      );

      // Should be InfluxUnavailableError specifically
      expect(error, isA<InfluxUnavailableError>());
      expect(
        error.message,
        equals('InfluxDB client not initialized'),
      );

      Logger.info(
        'Uninitialized client failure test completed successfully',
        tag: 'InfluxTest',
      );
    });

    test('returns failure for historical queries when not initialized', () async {
      Logger.info(
        'Testing that historical queries return failure when not initialized',
        tag: 'InfluxTest',
      );

      final start = DateTime.now().subtract(const Duration(hours: 2));
      final end = DateTime.now();

      Logger.debug(
        'Querying historical data from $start to $end',
        tag: 'InfluxTest',
      );

      final result = await influxService.querySensorData(
        sensorType: SensorType.temperature,
        start: start,
        end: end,
        limit: 10,
      );

      expect(result, isA<Failure<List<SensorData>>>());

      final error = (result as Failure<List<SensorData>>).error;
      expect(error, isA<InfluxUnavailableError>());
      expect(
        error.message,
        equals('InfluxDB client not initialized'),
      );

      Logger.info(
        'Historical query failure test completed successfully',
        tag: 'InfluxTest',
      );
    });

    test('returns failure for light intensity query when not initialized', () async {
      Logger.info(
        'Testing that light intensity query returns failure when not initialized',
        tag: 'InfluxTest',
      );

      final service = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );

      // Query without initializing the service
      final result = await service.querySensorData(
        sensorType: SensorType.lightIntensity,
        start: DateTime(2024, 1, 1, 0, 0),
        end: DateTime(2024, 1, 1, 23, 59),
        limit: 24,
      );

      expect(result, isA<Failure<List<SensorData>>>());
      final error = (result as Failure<List<SensorData>>).error;
      expect(error, isA<InfluxUnavailableError>());

      Logger.info(
        'Light intensity query failure test completed successfully',
        tag: 'InfluxTest',
      );
    });

    test('returns failure for device node validation when not initialized', () async {
      Logger.info(
        'Testing that queries return failure when validating device nodes without initialization',
        tag: 'InfluxTest',
      );

      final service = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );

      // Test one sensor type without initializing
      final result = await service.querySensorData(
        sensorType: SensorType.temperature,
        start: DateTime.now().subtract(const Duration(hours: 1)),
        end: DateTime.now(),
        limit: 1,
      );

      expect(result, isA<Failure<List<SensorData>>>());
      final error = (result as Failure<List<SensorData>>).error;
      expect(error, isA<InfluxUnavailableError>());

      Logger.info(
        'Device node validation failure test completed successfully',
        tag: 'InfluxTest',
      );
    });

    tearDown(() async {
      Logger.info('Tearing down InfluxDB service test', tag: 'InfluxTest');
      await influxService.close();
    });
  });

  group('InfluxDbService Integration', () {
    late MockInfluxDbService mockInfluxService;

    setUp(() {
      Logger.init(isTest: true);
      Logger.info(
        'Setting up InfluxDB mock integration test',
        tag: 'InfluxMockTest',
      );
      mockInfluxService = MockInfluxDbService();
    });

    test('mock service can simulate initialization success', () async {
      Logger.info(
        'Testing mock service initialization success',
        tag: 'InfluxMockTest',
      );

      when(
        () => mockInfluxService.initialize(),
      ).thenAnswer((_) async => const Success(null));

      final result = await mockInfluxService.initialize();
      expect(result, isA<Success>());

      verify(() => mockInfluxService.initialize()).called(1);
      Logger.info(
        'Mock initialization success test passed',
        tag: 'InfluxMockTest',
      );
    });

    test('mock service can simulate initialization failure', () async {
      Logger.info(
        'Testing mock service initialization failure',
        tag: 'InfluxMockTest',
      );

      when(() => mockInfluxService.initialize()).thenAnswer(
        (_) async => const Failure(InfluxError('Connection failed')),
      );

      final result = await mockInfluxService.initialize();
      expect(result, isA<Failure>());
      expect((result as Failure).error, isA<InfluxError>());

      verify(() => mockInfluxService.initialize()).called(1);
      Logger.info(
        'Mock initialization failure test passed',
        tag: 'InfluxMockTest',
      );
    });

    test('mock service can simulate data query', () async {
      Logger.info(
        'Testing mock service data query simulation',
        tag: 'InfluxMockTest',
      );

      final testData = [
        SensorData(
          id: 'temperature_1',
          sensorType: SensorType.temperature,
          value: 23.0,
          unit: '°C',
          timestamp: DateTime.now(),
          deviceId: '1',
          deviceNode: 'rpi',
          location: 'tent',
        ),
        SensorData(
          id: 'humidity_1',
          sensorType: SensorType.humidity,
          value: 60.0,
          unit: '%',
          timestamp: DateTime.now(),
          deviceId: '1',
          deviceNode: 'rpi',
          location: 'tent',
        ),
      ];

      Logger.debug(
        'Mock test data: ${testData.length} sensor readings',
        tag: 'InfluxMockTest',
      );

      when(
        () => mockInfluxService.queryLatestSensorData(),
      ).thenAnswer((_) async => Success(testData));

      final result = await mockInfluxService.queryLatestSensorData();
      expect(result, isA<Success>());
      expect((result as Success).data, equals(testData));

      verify(() => mockInfluxService.queryLatestSensorData()).called(1);
      Logger.info(
        'Mock data query simulation test passed',
        tag: 'InfluxMockTest',
      );
    });
  });
}
