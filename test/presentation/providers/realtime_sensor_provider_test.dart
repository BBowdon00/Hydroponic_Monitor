import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/core/logger.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/sensor_providers.dart';

// Mock classes
class MockMqttService extends Mock implements MqttService {}
class MockInfluxDbService extends Mock implements InfluxDbService {}
class MockSensorRepository extends Mock implements SensorRepository {}

void main() {
  setUpAll(() {
    Logger.init(isTest: true);
  });

  group('Real-time Sensor Data Integration', () {
    late MockMqttService mockMqttService;
    late MockInfluxDbService mockInfluxService;
    late ProviderContainer container;
    late StreamController<SensorData> sensorDataController;

    setUp(() {
      mockMqttService = MockMqttService();
      mockInfluxService = MockInfluxDbService();
      sensorDataController = StreamController<SensorData>.broadcast();

      // Mock MQTT service stream
      when(() => mockMqttService.sensorDataStream)
          .thenAnswer((_) => sensorDataController.stream);
      
      // Mock MQTT service connection
      when(() => mockMqttService.connect())
          .thenAnswer((_) async => const Success<void>(null));
      
      // Mock InfluxDB service initialization  
      when(() => mockInfluxService.initialize())
          .thenAnswer((_) async => const Success<void>(null));

      // Create container with mocked services
      container = ProviderContainer(
        overrides: [
          mqttServiceProvider.overrideWithValue(mockMqttService),
          influxServiceProvider.overrideWithValue(mockInfluxService),
        ],
      );
    });

    tearDown(() {
      sensorDataController.close();
      container.dispose();
    });

    test('Repository initialization completes successfully', () async {
      final repositoryFuture = container.read(sensorRepositoryInitProvider.future);
      
      // Wait for initialization to complete
      final repository = await repositoryFuture;
      
      expect(repository, isA<SensorRepository>());
      verify(() => mockMqttService.connect()).called(1);
      verify(() => mockInfluxService.initialize()).called(1);
    });

    test('Real-time sensor data accumulates by sensor type', () async {
      // Wait for repository initialization
      await container.read(sensorRepositoryInitProvider.future);
      
      // Create test sensor data for different types
      final tempSensor = SensorData(
        id: 'temp_1',
        sensorType: SensorType.temperature,
        value: 25.0,
        unit: '°C',
        timestamp: DateTime.now(),
        deviceId: 'node_1',
        location: 'greenhouse',
      );
      
      final humiditySensor = SensorData(
        id: 'humidity_1',
        sensorType: SensorType.humidity,
        value: 60.0,
        unit: '%',
        timestamp: DateTime.now(),
        deviceId: 'node_1',
        location: 'greenhouse',
      );

      // Emit sensor data
      sensorDataController.add(tempSensor);
      await Future.delayed(const Duration(milliseconds: 100));
      
      sensorDataController.add(humiditySensor);
      await Future.delayed(const Duration(milliseconds: 100));

      // Check that the accumulated data has both sensor types
      final sensorDataByTypeAsync = container.read(realTimeSensorDataByTypeProvider);
      
      sensorDataByTypeAsync.when(
        data: (sensorDataByType) {
          expect(sensorDataByType, hasLength(2));
          expect(sensorDataByType[SensorType.temperature]?.value, equals(25.0));
          expect(sensorDataByType[SensorType.humidity]?.value, equals(60.0));
        },
        loading: () => fail('Provider should have data by now'),
        error: (error, stack) => fail('Provider should not error: $error'),
      );
    });

    test('Latest sensor data provider returns correct values for each sensor type', () async {
      // Wait for repository initialization
      await container.read(sensorRepositoryInitProvider.future);
      
      // Create test sensor data
      final tempSensor = SensorData(
        id: 'temp_1',
        sensorType: SensorType.temperature,
        value: 22.5,
        unit: '°C',
        timestamp: DateTime.now(),
        deviceId: 'node_1',
        location: 'greenhouse',
      );
      
      final humiditySensor = SensorData(
        id: 'humidity_1', 
        sensorType: SensorType.humidity,
        value: 65.0,
        unit: '%',
        timestamp: DateTime.now(),
        deviceId: 'node_1',
        location: 'greenhouse',
      );

      // Emit sensor data
      sensorDataController.add(tempSensor);
      await Future.delayed(const Duration(milliseconds: 100));
      
      sensorDataController.add(humiditySensor);
      await Future.delayed(const Duration(milliseconds: 100));

      // Check that individual sensor type providers return correct data
      final tempData = container.read(latestSensorDataProvider(SensorType.temperature));
      final humidityData = container.read(latestSensorDataProvider(SensorType.humidity));
      final phData = container.read(latestSensorDataProvider(SensorType.pH));

      expect(tempData?.value, equals(22.5));
      expect(tempData?.sensorType, equals(SensorType.temperature));
      
      expect(humidityData?.value, equals(65.0));
      expect(humidityData?.sensorType, equals(SensorType.humidity));
      
      // pH sensor data was never sent, should be null
      expect(phData, isNull);
    });

    test('Has sensor data provider reports correct status', () async {
      // Wait for repository initialization
      await container.read(sensorRepositoryInitProvider.future);
      
      // Initially should have no sensor data
      expect(container.read(hasSensorDataProvider), isFalse);
      
      // Add sensor data
      final tempSensor = SensorData(
        id: 'temp_1',
        sensorType: SensorType.temperature,
        value: 23.0,
        unit: '°C',
        timestamp: DateTime.now(),
        deviceId: 'node_1',
        location: 'greenhouse',
      );
      
      sensorDataController.add(tempSensor);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Now should have sensor data
      expect(container.read(hasSensorDataProvider), isTrue);
    });

    test('Provider handles repository initialization errors gracefully', () async {
      // Create a new container with failing MQTT service
      final failingMqttService = MockMqttService();
      when(() => failingMqttService.connect())
          .thenAnswer((_) async => Failure(MqttError('MQTT connection failed')));
      
      final failingContainer = ProviderContainer(
        overrides: [
          mqttServiceProvider.overrideWithValue(failingMqttService),
          influxServiceProvider.overrideWithValue(mockInfluxService),
        ],
      );
      
      // Repository initialization should fail
      expect(
        () => failingContainer.read(sensorRepositoryInitProvider.future),
        throwsA(isA<Exception>()),
      );
      
      failingContainer.dispose();
    });
  });
}