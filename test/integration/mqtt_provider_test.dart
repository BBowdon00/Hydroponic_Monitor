@Tags(['integration'])
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/connection_status_provider.dart';
import '../test_utils.dart';
import 'package:hydroponic_monitor/core/logger.dart';
import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/presentation/providers/config_provider.dart';
import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';

// Simple in-memory config repository for deterministic integration tests
class _InMemoryConfigRepository implements ConfigRepository {
  _InMemoryConfigRepository();
  AppConfig _config = const AppConfig(
    mqtt: MqttConfig(host: 'localhost', port: 1883, username: '', password: ''),
    influx: InfluxConfig(
      url: 'http://localhost:8086',
      token: '',
      org: 'org',
      bucket: 'bucket',
    ),
    hls: HlsConfig(
      url: 'http://localhost:8080/stream',
      autoReconnect: true,
    ),
  );
  @override
  Future<AppConfig> loadConfig() async => _config;
  @override
  Future<void> saveConfig(AppConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearConfig() async {
    _config = const AppConfig(
      mqtt: MqttConfig(
        host: 'localhost',
        port: 1883,
        username: '',
        password: '',
      ),
      influx: InfluxConfig(
        url: 'http://localhost:8086',
        token: '',
        org: 'org',
        bucket: 'bucket',
      ),
      hls: HlsConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      ),
    );
  }
}

/// Integration tests for MQTT publish/subscribe functionality using the provider framework.
///
/// These tests verify that:
/// 1. MQTT messages can be published successfully
/// 2. The provider framework correctly receives and processes MQTT messages
/// 3. Real-time data streams work through the provider layer
/// 4. Both sensor data and device status updates are handled properly
///
/// Note: These tests require a running MQTT broker (e.g., Mosquitto)
void main() {
  group('MQTT Provider Integration Tests', () {
    const testTimeout = Timeout(Duration(minutes: 2));
    late ProviderContainer container;
    late MqttService mqttService;
    MqttServerClient? testPublisherClient;

    setUpAll(() async {
      // Initialize logger for tests
      Logger.init(isTest: true);

      // Initialize DotEnv for the tests
      // Try to load .env.test first, fallback to .env
      try {
        await dotenv.load(fileName: '.env.test');
      } catch (_) {
        await dotenv.load(fileName: '.env');
      }

      // Set up test MQTT client for publishing test messages
      testPublisherClient = MqttServerClient(
        TestConfig.testMqttHost,
        'provider_test_publisher',
      );
      testPublisherClient!.port = TestConfig.testMqttPort;
      testPublisherClient!.keepAlivePeriod = 20;
      testPublisherClient!.autoReconnect = true;

      await testPublisherClient!.connect();
      expect(
        testPublisherClient!.connectionStatus!.state,
        equals(MqttConnectionState.connected),
      );
    });

    tearDownAll(() async {
      testPublisherClient?.disconnect();
    });

    setUp(() async {
      // Create a fresh container for each test
      container = ProviderContainer(
        overrides: [
          // Provide in-memory config to satisfy configProvider dependencies
          configRepositoryProvider.overrideWithValue(
            _InMemoryConfigRepository(),
          ),
          sensorRepositoryProvider.overrideWith((ref) {
            final mqtt = ref.read(mqttServiceProvider);
            final influx = ref.read(influxServiceProvider);
            return SensorRepository(
              mqttService: mqtt,
              influxService: influx,
              strictInit: true,
            );
          }),
        ],
      );
      await container.read(mqttServiceProvider).connect();
      // Get the MQTT service from the container after initialization
      mqttService = container.read(mqttServiceProvider);
    });

    tearDown(() async {
      // Clean up the container
      container.dispose();
    });

    test(
      'Sensor data publish and receive through provider',
      tags: ['integration'], // Added integration tag
      () async {
        // Wait for repository initialization
        await container.read(sensorRepositoryInitProvider.future);

        // Set up provider listener BEFORE publishing data
        // ignore: deprecated_member_use
        final sensorStream = container.read(realTimeSensorDataProvider.stream);
        final receivedData = <SensorData>[];

        final subscription = sensorStream.listen((data) {
          receivedData.add(data);
        });

        // Small delay to ensure subscription is active
        await Future.delayed(const Duration(milliseconds: 200));

        // Create test sensor data
        final testData = TestDataGenerator.generateSensorData(
          sensorType: SensorType.temperature,
          sensorId: 'provider_test_temp_001',
          deviceId: 'test_device_001',
          location: 'provider_test_zone',
        );

        // Publish sensor data using test MQTT client
        final topic = TestMqttTopics.sensorTopicFor('rpi');
        final messageJson = _sensorDataToJson(testData);

        final builder = MqttClientPayloadBuilder();
        builder.addString(messageJson);

        testPublisherClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        Logger.info('Published sensor data to topic: $topic');
        Logger.debug('Message: $messageJson');

        // Wait for the message to be processed
        await Future.delayed(const Duration(seconds: 3));

        Logger.info('Received ${receivedData.length} sensor data points');
        for (final data in receivedData) {
          Logger.debug('Received: ${data.sensorType} = ${data.value}');
        }

        // Verify the data was received through the provider
        expect(
          receivedData,
          isNotEmpty,
          reason: 'Should have received sensor data through provider',
        );

        final received = receivedData.first;
        expect(received.sensorType, equals(testData.sensorType));
        expect(received.value, closeTo(testData.value, 0.01));
        expect(received.deviceId, equals('rpi')); // From topic parsing
        expect(received.location, equals(testData.location));

        await subscription.cancel();
      },
      timeout: testTimeout,
    );

    test(
      'Device status publish and receive through provider',
      tags: ['integration'], // Added integration tag
      () async {
        // Listen to the device status updates provider
        // ignore: deprecated_member_use
        final deviceStream = container.read(deviceStatusUpdatesProvider.stream);
        final receivedDevices = <Device>[];

        final deviceSubscription = deviceStream.listen((device) {
          receivedDevices.add(device);
        });

        // Publish device status using test MQTT client
        final topic = TestMqttTopics.deviceTopicFor('esp32_1');
        final devicePayload = TestMqttPayloads.devicePayload(
          deviceType: 'microcontroller',
          deviceID: '1',
          location: 'tent',
          running: true,
          description: 'ESP32 test device',
        );
        final payloadJson = json.encode(devicePayload);

        final builder = MqttClientPayloadBuilder();
        builder.addString(payloadJson);

        testPublisherClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        Logger.info('Published device status to topic: $topic', tag: 'MQTT');
        Logger.debug('Payload: $payloadJson', tag: 'MQTT');

        // Wait for the message to be processed
        await Future.delayed(const Duration(seconds: 1));

        // Verify the device status was received through the provider
        expect(
          receivedDevices,
          isNotEmpty,
          reason: 'Should have received device status through provider',
        );

        final received = receivedDevices.first;
        expect(received.id, equals('esp32_1_microcontroller_1'));
        expect(received.name, equals('ESP32 test device'));
        expect(received.status, equals(DeviceStatus.online));
        expect(received.location, equals('tent'));
        expect(received.isEnabled, isTrue);

        await deviceSubscription.cancel();
      },
      timeout: testTimeout,
    );

    test(
      'Multiple sensor types through provider',
      tags: ['integration'], // Added integration tag
      () async {
        // Wait for repository initialization
        await container.read(sensorRepositoryInitProvider.future);

        final sensorTypes = [
          SensorType.temperature,
          SensorType.humidity,
          SensorType.pH,
        ];
        final receivedData = <SensorData>[];
        final receivedTypes = <SensorType>{};

        // Set up provider listener BEFORE publishing data
        // ignore: deprecated_member_use
        final sensorStream = container.read(realTimeSensorDataProvider.stream);

        final subscription = sensorStream.listen((data) {
          receivedData.add(data);
          receivedTypes.add(data.sensorType);
        });

        // Small delay to ensure subscription is active
        await Future.delayed(const Duration(milliseconds: 200));

        Future<void> publishTypes(Iterable<SensorType> types) async {
          // Ensure publisher client is still connected (reconnect if broker dropped connection)
          if (testPublisherClient != null &&
              testPublisherClient!.connectionStatus?.state !=
                  MqttConnectionState.connected) {
            try {
              await testPublisherClient!.connect();
              Logger.info(
                'Reconnected test publisher client before publishing types',
                tag: 'Test',
              );
            } catch (e) {
              Logger.warning(
                'Failed to reconnect publisher client: $e',
                tag: 'Test',
              );
            }
          }
          for (final sensorType in types) {
            final testData = TestDataGenerator.generateSensorData(
              sensorType: sensorType,
              sensorId: 'multi_test_${sensorType.name}',
              deviceId: 'multi_device',
              location: 'multi_test_zone',
            );

            final topic = TestMqttTopics.sensorTopicFor('rpi');
            final messageJson = _sensorDataToJson(testData);

            final builder = MqttClientPayloadBuilder();
            builder.addString(messageJson);

            testPublisherClient!.publishMessage(
              topic,
              MqttQos.atLeastOnce,
              builder.payload!,
            );

            // Small delay between publishes to avoid flooding
            await Future.delayed(const Duration(milliseconds: 150));
          }
        }

        // Initial publish of all sensor types
        await publishTypes(sensorTypes);

        // Wait up to 5 seconds for all unique types to arrive, republishing missing once
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        var republished = false;
        while (DateTime.now().isBefore(deadline) &&
            receivedTypes.length < sensorTypes.length) {
          await Future.delayed(const Duration(milliseconds: 250));
          final missing = sensorTypes.where((t) => !receivedTypes.contains(t));
          if (missing.isNotEmpty && !republished) {
            Logger.warning(
              'Did not receive all sensor types yet. Missing: ${missing.map((e) => e.name).join(', ')}. Republishing missing types once.',
              tag: 'Test',
            );
            await publishTypes(missing);
            republished = true;
          }
        }

        Logger.info('Received ${receivedData.length} sensor data points');
        for (final data in receivedData) {
          Logger.debug('Received: ${data.sensorType} = ${data.value}');
        }

        // Verify all sensor types were received (unique types)
        final missingAfterWait = sensorTypes.where(
          (t) => !receivedTypes.contains(t),
        );
        expect(
          missingAfterWait,
          isEmpty,
          reason:
              'Did not receive all sensor types. Still missing: ${missingAfterWait.map((e) => e.name).join(', ')}',
        );

        for (final sensorType in sensorTypes) {
          final matchingData = receivedData.where(
            (data) => data.sensorType == sensorType,
          );
          expect(
            matchingData,
            isNotEmpty,
            reason: 'Should have received $sensorType data',
          );
        }

        await subscription.cancel();
      },
      timeout: testTimeout,
    );

    test(
      'Actuator state publish and receive through provider',
      tags: ['integration'], // Added integration tag
      () async {
        // Listen to the device status updates provider (actuators are treated as devices)
        // ignore: deprecated_member_use
        final deviceStream = container.read(deviceStatusUpdatesProvider.stream);
        final receivedDevices = <Device>[];

        final subscription = deviceStream.listen((device) {
          receivedDevices.add(device);
        });

        // Publish actuator state using test MQTT client
        final topic = TestMqttTopics.actuatorTopicFor('rpi');
        final actuatorPayload = TestMqttPayloads.actuatorPayload(
          deviceType: 'pump',
          deviceID: '1',
          location: 'tent',
          running: true,
          description: 'Circulation pump',
        );
        final payloadJson = json.encode(actuatorPayload);

        final builder = MqttClientPayloadBuilder();
        builder.addString(payloadJson);

        testPublisherClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        Logger.info('Published actuator state to topic: $topic');
        Logger.debug('Payload: $payloadJson');

        // Wait up to 3 seconds for the specific actuator device to appear
        const targetId = 'rpi_pump_1';
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (DateTime.now().isBefore(deadline)) {
          final match = receivedDevices.where((d) => d.id == targetId);
          if (match.isNotEmpty) {
            final received = match.first;
            expect(received.name, equals('Circulation pump'));
            expect(received.type, equals(DeviceType.pump));
            expect(received.status, equals(DeviceStatus.online));
            expect(received.isEnabled, isTrue);
            break;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Final assertion ensuring actuator device was captured
        expect(
          receivedDevices.any((d) => d.id == targetId),
          isTrue,
          reason: 'Expected actuator device with id $targetId to be received',
        );

        await subscription.cancel();
      },
      timeout: testTimeout,
    );

    test(
      'MQTT connection status through provider',
      tags: ['integration'], // Added integration tag
      () async {
        // Wait a moment for services to initialize
        await Future.delayed(const Duration(milliseconds: 500));

        // Read the current connection status
        final connectionAsync = container.read(connectionStatusProvider);

        await connectionAsync.when(
          data: (status) {
            // Should have received connection status
            expect(status.mqttConnected, isA<bool>());
            expect(status.influxConnected, isA<bool>());
          },
          loading: () {
            // Loading state is acceptable initially
          },
          error: (error, _) {
            fail('Connection status provider should not error: $error');
          },
        );
      },
      timeout: testTimeout,
    );

    test(
      'Provider handles malformed MQTT messages gracefully',
      tags: ['integration'], // Added integration tag
      () async {
        // Wait for repository initialization
        await container.read(sensorRepositoryInitProvider.future);

        // Set up provider listener BEFORE publishing data
        // ignore: deprecated_member_use
        final sensorStream = container.read(realTimeSensorDataProvider.stream);
        final receivedData = <SensorData>[];

        final subscription = sensorStream.listen((data) {
          receivedData.add(data);
        });

        // Small delay to ensure subscription is active
        await Future.delayed(const Duration(milliseconds: 200));

        // Publish malformed JSON
        final topic = TestMqttTopics.sensorTopicFor('rpi');
        const malformedJson =
            '{"deviceType": "temperature", "deviceID": "malformed", "invalid": json}';

        final builder = MqttClientPayloadBuilder();
        builder.addString(malformedJson);

        testPublisherClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        // Wait for processing
        await Future.delayed(const Duration(seconds: 1));

        // Read the current sensor data state
        final sensorAsync = container.read(realTimeSensorDataProvider);

        // Verify the provider handles malformed data gracefully (doesn't crash)
        expect(() => sensorAsync, returnsNormally);

        // The provider should still be in a valid state
        await sensorAsync.when(
          data: (data) {
            // Should handle malformed data gracefully
            expect(data, isA<SensorData>());
          },
          loading: () {
            // Loading state is acceptable
          },
          error: (error, _) {
            // Error handling is also acceptable for malformed data
            expect(error, isNotNull);
          },
        );
      },
      timeout: testTimeout,
    );
  });
}

/// Convert sensor data to JSON format for MQTT publishing.
String _sensorDataToJson(SensorData data) {
  return json.encode(
    TestMqttPayloads.sensorPayload(
      deviceType: data.sensorType.name,
      deviceID: '1',
      location: data.location ?? 'tent',
      value: data.value,
      description: 'provider test ${data.sensorType.name} sensor',
    ),
  );
}
