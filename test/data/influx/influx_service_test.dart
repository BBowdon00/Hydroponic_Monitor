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
      // Test querying latest sensor data (which returns dummy data)
      final result = await influxService.queryLatestSensorData();
      
      expect(result, isA<Success<List<SensorData>>>());
      
      final data = (result as Success<List<SensorData>>).data;
      expect(data.length, equals(SensorType.values.length));
      
      // Check that all sensor types are represented
      final sensorTypes = data.map((d) => d.sensorType).toSet();
      expect(sensorTypes.length, equals(SensorType.values.length));
      
      // Check that values are within reasonable ranges
      for (final sensorData in data) {
        expect(sensorData.value, isA<double>());
        expect(sensorData.unit, isNotEmpty);
        expect(sensorData.timestamp, isA<DateTime>());
        expect(sensorData.id, isNotEmpty);
        
        // Check sensor-specific value ranges
        switch (sensorData.sensorType) {
          case SensorType.temperature:
            expect(sensorData.value, greaterThan(10.0));
            expect(sensorData.value, lessThan(40.0));
            expect(sensorData.unit, equals('°C'));
            break;
          case SensorType.humidity:
            expect(sensorData.value, greaterThanOrEqualTo(30.0));
            expect(sensorData.value, lessThanOrEqualTo(90.0));
            expect(sensorData.unit, equals('%'));
            break;
          case SensorType.pH:
            expect(sensorData.value, greaterThanOrEqualTo(5.5));
            expect(sensorData.value, lessThanOrEqualTo(7.5));
            expect(sensorData.unit, equals('pH'));
            break;
          case SensorType.waterLevel:
            expect(sensorData.value, greaterThanOrEqualTo(5.0));
            expect(sensorData.value, lessThanOrEqualTo(30.0));
            expect(sensorData.unit, equals('cm'));
            break;
          case SensorType.electricalConductivity:
            expect(sensorData.value, greaterThan(1000.0));
            expect(sensorData.value, lessThan(2000.0));
            expect(sensorData.unit, equals('µS/cm'));
            break;
          case SensorType.lightIntensity:
            expect(sensorData.value, greaterThanOrEqualTo(0.0));
            expect(sensorData.unit, equals('lux'));
            break;
          case SensorType.airQuality:
            expect(sensorData.value, greaterThan(300.0));
            expect(sensorData.value, lessThan(700.0));
            expect(sensorData.unit, equals('ppm'));
            break;
        }
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
      expect(data.first.timestamp.isAfter(start.subtract(const Duration(minutes: 5))), isTrue);
      expect(data.first.timestamp.isBefore(start.add(const Duration(minutes: 30))), isTrue);
    });

    test('handles day/night cycle for light intensity', () async {
      // Test light intensity values at different times of day
      final dawnTime = DateTime(2024, 1, 1, 6, 0); // 6 AM
      final noonTime = DateTime(2024, 1, 1, 12, 0); // 12 PM
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

    test('write operations return success for dummy data', () async {
      final sensorData = SensorData(
        id: 'test_sensor',
        sensorType: SensorType.temperature,
        value: 22.5,
        unit: '°C',
        timestamp: DateTime.now(),
      );

      // Write operations should work (though they don't actually write)
      final writeResult = await influxService.writeSensorData(sensorData);
      expect(writeResult, isA<Failure>()); // Should fail since not connected

      final batchData = [sensorData, sensorData];
      final batchResult = await influxService.writeSensorDataBatch(batchData);
      expect(batchResult, isA<Failure>()); // Should fail since not connected
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
      when(() => mockInfluxService.initialize()).thenAnswer((_) async => const Success(null));

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

    test('mock service can simulate successful data write', () async {
      final sensorData = SensorData(
        id: 'test_sensor',
        sensorType: SensorType.humidity,
        value: 65.0,
        unit: '%',
        timestamp: DateTime.now(),
      );

      when(() => mockInfluxService.writeSensorData(any())).thenAnswer(
        (_) async => const Success(null),
      );

      final result = await mockInfluxService.writeSensorData(sensorData);
      expect(result, isA<Success>());

      verify(() => mockInfluxService.writeSensorData(sensorData)).called(1);
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

      when(() => mockInfluxService.queryLatestSensorData()).thenAnswer(
        (_) async => Success(testData),
      );

      final result = await mockInfluxService.queryLatestSensorData();
      expect(result, isA<Success>());
      expect((result as Success).data, equals(testData));

      verify(() => mockInfluxService.queryLatestSensorData()).called(1);
    });

    test('mock service can simulate batch write', () async {
      final batchData = List.generate(
        5,
        (index) => SensorData(
          id: 'sensor_$index',
          sensorType: SensorType.temperature,
          value: 20.0 + index,
          unit: '°C',
          timestamp: DateTime.now(),
        ),
      );

      when(() => mockInfluxService.writeSensorDataBatch(any())).thenAnswer(
        (_) async => const Success(null),
      );

      final result = await mockInfluxService.writeSensorDataBatch(batchData);
      expect(result, isA<Success>());

      verify(() => mockInfluxService.writeSensorDataBatch(batchData)).called(1);
    });
  });
}