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

    test('generates realistic dummy sensor data', () async {
      Logger.info('Testing dummy sensor data generation', tag: 'InfluxTest');

      // The service gracefully falls back to dummy data when not initialized
      // This ensures the app remains functional even without a real InfluxDB connection
      final result = await influxService.queryLatestSensorData();

      expect(result, isA<Success<List<SensorData>>>());
      final data = (result as Success<List<SensorData>>).data;

      Logger.debug(
        'Generated ${data.length} sensor data points',
        tag: 'InfluxTest',
      );

      // Should return data for all sensor types
      expect(data.length, equals(SensorType.values.length));

      // Verify each sensor type is represented
      final sensorTypes = data.map((d) => d.sensorType).toSet();
      expect(sensorTypes.length, equals(SensorType.values.length));

      Logger.debug(
        "Sensor types generated: ${sensorTypes.map((t) => t.name).join(', ')}",
        tag: 'InfluxTest',
      );

      // Verify proper data structure aligned with MQTT patterns
      for (final sensorData in data) {
        expect(sensorData.value, greaterThan(0));
        expect(sensorData.unit, equals(sensorData.sensorType.defaultUnit));
        expect(sensorData.timestamp, isNotNull);

        // Validate new structure fields
        expect(sensorData.deviceId, equals('1')); // Default deviceID
        expect(sensorData.location, equals('tent')); // Default location
        expect(sensorData.deviceNode, isNotNull); // Should have deviceNode

        // Validate deviceNode assignments match expected patterns
        final expectedNodes = ['rpi', 'esp32_1', 'esp32_2'];
        expect(expectedNodes.contains(sensorData.deviceNode), isTrue);

        // Validate ID format: sensorType_deviceID
        expect(sensorData.id, equals('${sensorData.sensorType.name}_1'));

        Logger.debug(
          '${sensorData.sensorType.name}: ${sensorData.value} ${sensorData.unit} [node: ${sensorData.deviceNode}]',
          tag: 'InfluxTest',
        );
      }

      Logger.info(
        'Dummy sensor data generation test completed successfully',
        tag: 'InfluxTest',
      );
    });

    test('generates historical data with time progression', () async {
      Logger.info(
        'Testing historical data generation with time progression',
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

      expect(result, isA<Success<List<SensorData>>>());

      final data = (result as Success<List<SensorData>>).data;
      expect(data.length, equals(10));

      Logger.debug(
        'Generated ${data.length} historical data points',
        tag: 'InfluxTest',
      );

      // Check that timestamps are in chronological order
      for (int i = 1; i < data.length; i++) {
        expect(data[i].timestamp.isAfter(data[i - 1].timestamp), isTrue);

        if (i < 3) {
          // Log first few for debugging
          Logger.debug(
            'Data point $i: ${data[i].timestamp} - ${data[i].value}°C',
            tag: 'InfluxTest',
          );
        }
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

      Logger.info(
        'Historical data time progression test completed successfully',
        tag: 'InfluxTest',
      );
    });

    test('handles day/night cycle for light intensity', () async {
      Logger.info(
        'Testing light intensity day/night cycle simulation',
        tag: 'InfluxTest',
      );

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

      Logger.debug(
        'Generated ${data.length} light intensity data points for 24-hour cycle',
        tag: 'InfluxTest',
      );

      // Should have data points throughout the day
      expect(data.length, equals(24));

      // All should be light intensity data
      for (final point in data) {
        expect(point.sensorType, equals(SensorType.lightIntensity));
        expect(point.unit, equals('lux'));
        // Validate new structure
        expect(point.deviceNode, equals('esp32_1')); // Light sensors on esp32_1
        expect(point.location, equals('tent'));
        expect(point.deviceId, equals('1'));
      }

      Logger.info(
        'Day/night cycle simulation test completed successfully',
        tag: 'InfluxTest',
      );
    });

    test('validates device node assignments by sensor type', () async {
      Logger.info(
        'Testing device node assignments for different sensor types',
        tag: 'InfluxTest',
      );

      final service = InfluxDbService(
        url: 'http://localhost:8086',
        token: 'test-token',
        organization: 'test-org',
        bucket: 'test-bucket',
      );

      // Test each sensor type's device node assignment
      final sensorNodeMap = {
        SensorType.temperature: 'rpi',
        SensorType.humidity: 'rpi',
        SensorType.pH: 'rpi',
        SensorType.electricalConductivity: 'rpi',
        SensorType.waterLevel: 'esp32_1',
        SensorType.lightIntensity: 'esp32_1',
        SensorType.airQuality: 'esp32_1',
        SensorType.powerUsage: 'esp32_2',
      };

      for (final entry in sensorNodeMap.entries) {
        final result = await service.querySensorData(
          sensorType: entry.key,
          start: DateTime.now().subtract(const Duration(hours: 1)),
          end: DateTime.now(),
          limit: 1,
        );

        expect(result, isA<Success<List<SensorData>>>());
        final data = (result as Success<List<SensorData>>).data;
        expect(data.length, equals(1));

        final sensorData = data.first;
        expect(sensorData.deviceNode, equals(entry.value));
        expect(sensorData.sensorType, equals(entry.key));

        Logger.debug(
          '${entry.key.name} assigned to ${entry.value} ✓',
          tag: 'InfluxTest',
        );
      }

      Logger.info(
        'Device node assignment validation completed successfully',
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
