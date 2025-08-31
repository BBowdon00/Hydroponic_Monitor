import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/core/errors.dart';

class MockMqttService extends Mock implements MqttService {}
class MockInfluxDbService extends Mock implements InfluxDbService {}

void main() {
  group('SensorRepository', () {
    late SensorRepository repository;
    late MockMqttService mockMqttService;
    late MockInfluxDbService mockInfluxService;

    setUp(() {
      mockMqttService = MockMqttService();
      mockInfluxService = MockInfluxDbService();
      repository = SensorRepository(
        mqttService: mockMqttService,
        influxService: mockInfluxService,
      );
    });

    group('initialization', () {
      test('successful initialization of both services', () async {
        when(() => mockMqttService.connect()).thenAnswer((_) async => const Success(null));
        when(() => mockInfluxService.initialize()).thenAnswer((_) async => const Success(null));
        when(() => mockMqttService.sensorDataStream).thenAnswer((_) => const Stream.empty());

        final result = await repository.initialize();

        expect(result, isA<Success>());
        verify(() => mockMqttService.connect()).called(1);
        verify(() => mockInfluxService.initialize()).called(1);
      });

      test('fails when MQTT connection fails', () async {
        when(() => mockMqttService.connect()).thenAnswer(
          (_) async => const Failure(MqttError('MQTT connection failed')),
        );

        final result = await repository.initialize();

        expect(result, isA<Failure>());
        expect((result as Failure).error, isA<MqttError>());
        verify(() => mockMqttService.connect()).called(1);
        verifyNever(() => mockInfluxService.initialize());
      });

      test('fails when InfluxDB initialization fails', () async {
        when(() => mockMqttService.connect()).thenAnswer((_) async => const Success(null));
        when(() => mockInfluxService.initialize()).thenAnswer(
          (_) async => const Failure(InfluxError('InfluxDB initialization failed')),
        );

        final result = await repository.initialize();

        expect(result, isA<Failure>());
        expect((result as Failure).error, isA<InfluxError>());
        verify(() => mockMqttService.connect()).called(1);
        verify(() => mockInfluxService.initialize()).called(1);
      });
    });

    group('real-time data streaming', () {
      test('provides MQTT sensor data stream', () {
        final testData = SensorData(
          id: 'temp_001',
          sensorType: SensorType.temperature,
          value: 25.0,
          unit: '°C',
          timestamp: DateTime.now(),
        );

        when(() => mockMqttService.sensorDataStream).thenAnswer(
          (_) => Stream.value(testData),
        );

        expect(repository.realTimeSensorData, emits(testData));
      });

      test('handles MQTT stream errors gracefully', () {
        when(() => mockMqttService.sensorDataStream).thenAnswer(
          (_) => Stream.error('MQTT stream error'),
        );

        expect(repository.realTimeSensorData, emitsError('MQTT stream error'));
      });
    });

    group('historical data queries', () {
      test('gets latest readings from InfluxDB', () async {
        final testData = [
          SensorData(
            id: 'temp_001',
            sensorType: SensorType.temperature,
            value: 25.0,
            unit: '°C',
            timestamp: DateTime.now(),
          ),
          SensorData(
            id: 'hum_001',
            sensorType: SensorType.humidity,
            value: 60.0,
            unit: '%',
            timestamp: DateTime.now(),
          ),
        ];

        when(() => mockInfluxService.queryLatestSensorData()).thenAnswer(
          (_) async => Success(testData),
        );

        final result = await repository.getLatestReadings();

        expect(result, isA<Success>());
        expect((result as Success).data, equals(testData));
        verify(() => mockInfluxService.queryLatestSensorData()).called(1);
      });

      test('gets historical data with filters', () async {
        final start = DateTime.now().subtract(const Duration(hours: 24));
        final end = DateTime.now();
        final testData = [
          SensorData(
            id: 'temp_001',
            sensorType: SensorType.temperature,
            value: 25.0,
            unit: '°C',
            timestamp: start.add(const Duration(hours: 12)),
          ),
        ];

        when(() => mockInfluxService.querySensorData(
              sensorType: any(named: 'sensorType'),
              sensorId: any(named: 'sensorId'),
              deviceId: any(named: 'deviceId'),
              start: any(named: 'start'),
              end: any(named: 'end'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => Success(testData));

        final result = await repository.getHistoricalData(
          sensorType: SensorType.temperature,
          sensorId: 'temp_001',
          start: start,
          end: end,
          limit: 100,
        );

        expect(result, isA<Success>());
        expect((result as Success).data, equals(testData));
        
        verify(() => mockInfluxService.querySensorData(
              sensorType: SensorType.temperature,
              sensorId: 'temp_001',
              deviceId: null,
              start: start,
              end: end,
              limit: 100,
            )).called(1);
      });

      test('gets sensor type history', () async {
        final start = DateTime.now().subtract(const Duration(hours: 24));
        final end = DateTime.now();
        final testData = List.generate(
          10,
          (index) => SensorData(
            id: 'temp_$index',
            sensorType: SensorType.temperature,
            value: 20.0 + index,
            unit: '°C',
            timestamp: start.add(Duration(hours: index * 2)),
          ),
        );

        when(() => mockInfluxService.querySensorData(
              sensorType: any(named: 'sensorType'),
              start: any(named: 'start'),
              end: any(named: 'end'),
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => Success(testData));

        final result = await repository.getSensorTypeHistory(
          SensorType.temperature,
          start: start,
          end: end,
          limit: 100,
        );

        expect(result, isA<Success>());
        expect((result as Success).data, equals(testData));
      });
    });

    group('data storage', () {
      test('stores single sensor data point', () async {
        final sensorData = SensorData(
          id: 'test_sensor',
          sensorType: SensorType.pH,
          value: 6.5,
          unit: 'pH',
          timestamp: DateTime.now(),
        );

        when(() => mockInfluxService.writeSensorData(any())).thenAnswer(
          (_) async => const Success(null),
        );

        final result = await repository.storeSensorData(sensorData);

        expect(result, isA<Success>());
        verify(() => mockInfluxService.writeSensorData(sensorData)).called(1);
      });

      test('stores sensor data batch', () async {
        final batchData = List.generate(
          5,
          (index) => SensorData(
            id: 'batch_sensor_$index',
            sensorType: SensorType.waterLevel,
            value: 15.0 + index,
            unit: 'cm',
            timestamp: DateTime.now(),
          ),
        );

        when(() => mockInfluxService.writeSensorDataBatch(any())).thenAnswer(
          (_) async => const Success(null),
        );

        final result = await repository.storeSensorDataBatch(batchData);

        expect(result, isA<Success>());
        verify(() => mockInfluxService.writeSensorDataBatch(batchData)).called(1);
      });

      test('handles storage errors', () async {
        final sensorData = SensorData(
          id: 'test_sensor',
          sensorType: SensorType.temperature,
          value: 25.0,
          unit: '°C',
          timestamp: DateTime.now(),
        );

        when(() => mockInfluxService.writeSensorData(any())).thenAnswer(
          (_) async => const Failure(InfluxError('Storage failed')),
        );

        final result = await repository.storeSensorData(sensorData);

        expect(result, isA<Failure>());
        expect((result as Failure).error, isA<InfluxError>());
      });
    });

    group('MQTT to InfluxDB data flow', () {
      test('automatically stores MQTT data to InfluxDB on initialization', () async {
        final testData = SensorData(
          id: 'stream_sensor',
          sensorType: SensorType.temperature,
          value: 25.0,
          unit: '°C',
          timestamp: DateTime.now(),
        );

        // Set up successful initialization
        when(() => mockMqttService.connect()).thenAnswer((_) async => const Success(null));
        when(() => mockInfluxService.initialize()).thenAnswer((_) async => const Success(null));
        
        // Set up MQTT stream that emits test data
        when(() => mockMqttService.sensorDataStream).thenAnswer(
          (_) => Stream.value(testData),
        );
        
        // Set up successful InfluxDB write
        when(() => mockInfluxService.writeSensorData(any())).thenAnswer(
          (_) async => const Success(null),
        );

        // Initialize repository
        await repository.initialize();

        // Wait for stream to be processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify that MQTT data was written to InfluxDB
        verify(() => mockInfluxService.writeSensorData(testData)).called(1);
      });
    });

    group('disposal', () {
      test('properly disposes all resources', () async {
        when(() => mockMqttService.disconnect()).thenAnswer((_) async {});
        when(() => mockInfluxService.close()).thenAnswer((_) async {});

        await repository.dispose();

        verify(() => mockMqttService.disconnect()).called(1);
        verify(() => mockInfluxService.close()).called(1);
      });

      test('handles disposal errors gracefully', () async {
        when(() => mockMqttService.disconnect()).thenThrow('MQTT disconnect error');
        when(() => mockInfluxService.close()).thenAnswer((_) async {});

        // Should not throw despite MQTT error
        await repository.dispose();

        verify(() => mockMqttService.disconnect()).called(1);
        verify(() => mockInfluxService.close()).called(1);
      });
    });
  });
}