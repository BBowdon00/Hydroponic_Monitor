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
    registerFallbackValue(const Duration(seconds: 1));
  });

  // Helper to wait for provider value with timeout
  Future<SensorData?> waitForProvider(
    ProviderContainer container,
    Provider<SensorData?> provider, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final end = DateTime.now().add(timeout);
    SensorData? data;
    while (DateTime.now().isBefore(end)) {
      data = container.read(provider);
      if (data != null) return data;
      await Future.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException('Provider did not emit data in time');
  }

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
      when(
        () => mockMqttService.sensorDataStream,
      ).thenAnswer((_) => sensorDataController.stream);

      // Provide a connection stream that emits a connected event to satisfy
      // repository initialization wait logic.
      when(
        () => mockMqttService.connectionStream,
      ).thenAnswer((_) => Stream<String>.value('connected'));
      when(() => mockMqttService.isConnected).thenReturn(true);

      // Mock MQTT service connection
      when(
        () => mockMqttService.incrementAttempt(),
      ).thenReturn(1);
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success<void>(null));
      when(
        () => mockMqttService.ensureInitialized(timeout: any(named: 'timeout')),
      ).thenAnswer((_) async {});

      // Mock InfluxDB service initialization
      when(
        () => mockInfluxService.initialize(),
      ).thenAnswer((_) async => const Success<void>(null));

      // Create container with mocked services and a strict initialization repository
      container = ProviderContainer(
        overrides: [
          mqttServiceProvider.overrideWithValue(mockMqttService),
          influxServiceProvider.overrideWithValue(mockInfluxService),
          // Override mqttConnectionProvider to complete immediately (no config needed)
          mqttConnectionProvider.overrideWith((ref) async {
            // Just complete successfully without connecting
          }),
          // Override influxConnectionProvider to complete immediately (no config needed)
          influxConnectionProvider.overrideWith((ref) async {
            // Just complete successfully without connecting
          }),
          sensorRepositoryProvider.overrideWithValue(
            SensorRepository(
              mqttService: mockMqttService,
              influxService: mockInfluxService,
              strictInit: true,
            ),
          ),
        ],
      );
      addTearDown(() {
        sensorDataController.close();
        container.dispose();
      });
    });

    // Removed tearDown; now handled by addTearDown in setUp

    test('Repository initialization completes successfully', () async {
      final repositoryFuture = container.read(
        sensorRepositoryInitProvider.future,
      );

      // Wait for initialization to complete
      final repository = await repositoryFuture;

      expect(repository, isA<SensorRepository>());
      // connect() and initialize() are no longer called during repository init
      // (handled by mqttConnectionProvider and influxConnectionProvider)
      verifyNever(() => mockMqttService.connect());
      verifyNever(() => mockInfluxService.initialize());
    });

    test('Real-time sensor data accumulates by sensor type', () async {
      // Wait for repository initialization
      await container.read(sensorRepositoryInitProvider.future);

      // Set up listener BEFORE emitting data to ensure we catch all events
      Map<SensorType, SensorData>? receivedData;
      final sub = container.listen<AsyncValue<Map<SensorType, SensorData>>>(
        realTimeSensorDataByTypeProvider,
        (prev, next) {
          print('Provider state changed: $next');
          next.whenData((data) {
            print('Received data in provider: $data');
            receivedData = data;
          });
        },
        fireImmediately: true,
      );

      // Small delay to ensure subscription is active
      await Future.delayed(const Duration(milliseconds: 100));

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
      print('Emitted tempSensor');
      await Future.delayed(const Duration(milliseconds: 500));

      sensorDataController.add(humiditySensor);
      print('Emitted humiditySensor');
      await Future.delayed(const Duration(milliseconds: 500));

      // Wait for data to arrive with timeout
      int attempts = 0;
      while (receivedData == null && attempts < 100) {
        await Future.delayed(const Duration(milliseconds: 50));
        attempts++;
      }

      print('Final receivedData: $receivedData');
      expect(
        receivedData,
        isNotNull,
        reason: 'Provider should have emitted sensor data',
      );
      expect(receivedData![SensorType.temperature]?.value, equals(25.0));
      expect(receivedData![SensorType.humidity]?.value, equals(60.0));

      sub.close();
    });

    test(
      'Latest sensor data provider returns correct values for each sensor type',
      () async {
        // Wait for repository initialization
        await container.read(sensorRepositoryInitProvider.future);

        // Set up listeners BEFORE emitting data
        SensorData? tempData;
        SensorData? humidityData;
        SensorData? phData;

        // Listen for temperature data
        final tempSub = container.listen<SensorData?>(
          latestSensorDataProvider(SensorType.temperature),
          (prev, next) {
            tempData = next;
          },
          fireImmediately: true,
        );
        // Listen for humidity data
        final humiditySub = container.listen<SensorData?>(
          latestSensorDataProvider(SensorType.humidity),
          (prev, next) {
            humidityData = next;
          },
          fireImmediately: true,
        );

        // Small delay to ensure subscriptions are active
        await Future.delayed(const Duration(milliseconds: 100));

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
        print('Emitted tempSensor');
        await Future.delayed(const Duration(milliseconds: 300));

        sensorDataController.add(humiditySensor);
        print('Emitted humiditySensor');
        await Future.delayed(const Duration(milliseconds: 300));

        // Wait for provider updates
        await Future.delayed(const Duration(milliseconds: 200));

        expect(tempData?.value, equals(22.5));
        expect(tempData?.sensorType, equals(SensorType.temperature));
        expect(humidityData?.value, equals(65.0));
        expect(humidityData?.sensorType, equals(SensorType.humidity));

        // pH sensor data was never sent, should be null
        phData = container.read(latestSensorDataProvider(SensorType.pH));
        expect(phData, isNull);

        tempSub.close();
        humiditySub.close();
      },
    );
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
      print('Emitted tempSensor');
      await Future.delayed(const Duration(milliseconds: 300));

      // Now should have sensor data
      expect(container.read(hasSensorDataProvider), isTrue);
    });

    test(
      'Provider handles repository initialization errors gracefully',
      () async {
        // Create a new container with failing MQTT service
        final failingMqttService = MockMqttService();
        when(
          () => failingMqttService.incrementAttempt(),
        ).thenReturn(1);
        when(
          () => failingMqttService.connect(),
        ).thenAnswer((_) async => Failure(MqttError('MQTT connection failed')));
        when(
          () => failingMqttService.ensureInitialized(
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(TimeoutException('MQTT not ready'));

        final failingContainer = ProviderContainer(
          overrides: [
            mqttServiceProvider.overrideWithValue(failingMqttService),
            influxServiceProvider.overrideWithValue(mockInfluxService),
            // Override mqttConnectionProvider to complete immediately with failure
            mqttConnectionProvider.overrideWith((ref) async {
              throw Exception('MQTT connection failed');
            }),
            // Override influxConnectionProvider to fail as well
            influxConnectionProvider.overrideWith((ref) async {
              throw Exception('InfluxDB connection failed');
            }),
            sensorRepositoryProvider.overrideWithValue(
              SensorRepository(
                mqttService: failingMqttService,
                influxService: mockInfluxService,
                strictInit: true,
              ),
            ),
          ],
        );

        // Repository initialization should fail
        expect(
          () => failingContainer.read(sensorRepositoryInitProvider.future),
          throwsA(anything), // Accept any exception
        );

        failingContainer.dispose();
      },
    );
  });
}
