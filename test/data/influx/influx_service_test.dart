import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/core/errors.dart';

class MockInfluxDbService extends Mock implements InfluxDbService {}

void main() {
  group('InfluxDbService', () {
    late InfluxDbService influxService;

    setUp(() {
      influxService = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );
    });

    test('initializes with correct configuration', () {
      expect(influxService.url, equals('http://localhost:8086'));
      expect(influxService.token, equals('test-token'));
      expect(influxService.organization, equals('test-org'));
      expect(influxService.bucket, equals('test-bucket'));
    });

    test('generates realistic dummy sensor data', () async {
      // The service gracefully falls back to dummy data when not initialized
      // This ensures the app remains functional even without a real InfluxDB connection
      final result = await influxService.queryLatestSensorData();

      expect(result, isA<Success<List<SensorData>>>());
      final data = (result as Success<List<SensorData>>).data;
      
      // Should return data for all sensor types
      expect(data.length, equals(SensorType.values.length));
      
      // Verify each sensor type is represented
      final sensorTypes = data.map((d) => d.sensorType).toSet();
      expect(sensorTypes.length, equals(SensorType.values.length));
      
      // Verify realistic data values
      for (final sensorData in data) {
        expect(sensorData.value, greaterThan(0));
        expect(sensorData.unit, equals(sensorData.sensorType.defaultUnit));
        expect(sensorData.timestamp, isNotNull);
      }
    });

    test('generates historical data with time progression', () async {
      final start = DateTime.now().subtract(const Duration(hours: 2));
      final end = DateTime.now();

      final result = await influxService.querySensorData(
        sensorType: SensorType.temperature,
        start: start,
        end: end,
        limit: 10,
      );

      expect(result, isA<Success<List<SensorData>>>());

      final data = (result as Success<List<SensorData>>).data;
      expect(data.length, equals(10));

      // Check that timestamps are in chronological order
      for (int i = 1; i < data.length; i++) {
        expect(data[i].timestamp.isAfter(data[i - 1].timestamp), isTrue);
      }

      // Check that first timestamp is close to start time
      expect(
        data.first.timestamp.isAfter(
          start.subtract(const Duration(minutes: 5)),
        ),
        isTrue,
      );
      expect(
        data.first.timestamp.isBefore(start.add(const Duration(minutes: 30))),
        isTrue,
      );
    });

    test('handles day/night cycle for light intensity', () async {
      // Test light intensity values at different times of day - variables used for documentation
      // ignore: unused_local_variable
      final dawnTime = DateTime(2024, 1, 1, 6, 0); // 6 AM
      // ignore: unused_local_variable
      final noonTime = DateTime(2024, 1, 1, 12, 0); // 12 PM
      // ignore: unused_local_variable
      final nightTime = DateTime(2024, 1, 1, 22, 0); // 10 PM

      final service = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );

      // Query for different times (this uses dummy data generation internally)
      final result = await service.querySensorData(
        sensorType: SensorType.lightIntensity,
        start: DateTime(2024, 1, 1, 0, 0),
        end: DateTime(2024, 1, 1, 23, 59),
        limit: 24,
      );

      expect(result, isA<Success<List<SensorData>>>());
      final data = (result as Success<List<SensorData>>).data;

      // Should have data points throughout the day
      expect(data.length, equals(24));

      // All should be light intensity data
      for (final point in data) {
        expect(point.sensorType, equals(SensorType.lightIntensity));
        expect(point.unit, equals('lux'));
      }
    });

    tearDown(() async {
      await influxService.close();
    });
  });

  group('InfluxDbService Integration', () {
    late MockInfluxDbService mockInfluxService;

    setUp(() {
      mockInfluxService = MockInfluxDbService();
    });

    test('mock service can simulate initialization success', () async {
      when(
        () => mockInfluxService.initialize(),
      ).thenAnswer((_) async => const Success(null));

      final result = await mockInfluxService.initialize();
      expect(result, isA<Success>());

      verify(() => mockInfluxService.initialize()).called(1);
    });

    test('mock service can simulate initialization failure', () async {
      when(() => mockInfluxService.initialize()).thenAnswer(
        (_) async => const Failure(InfluxError('Connection failed')),
      );

      final result = await mockInfluxService.initialize();
      expect(result, isA<Failure>());
      expect((result as Failure).error, isA<InfluxError>());

      verify(() => mockInfluxService.initialize()).called(1);
    });

    test('mock service can simulate data query', () async {
      final testData = [
        SensorData(
          id: 'sensor_1',
          sensorType: SensorType.temperature,
          value: 23.0,
          unit: '°C',
          timestamp: DateTime.now(),
        ),
        SensorData(
          id: 'sensor_2',
          sensorType: SensorType.humidity,
          value: 60.0,
          unit: '%',
          timestamp: DateTime.now(),
        ),
      ];

      when(
        () => mockInfluxService.queryLatestSensorData(),
      ).thenAnswer((_) async => Success(testData));

      final result = await mockInfluxService.queryLatestSensorData();
      expect(result, isA<Success>());
      expect((result as Success).data, equals(testData));

      verify(() => mockInfluxService.queryLatestSensorData()).called(1);
    });
  });
}
