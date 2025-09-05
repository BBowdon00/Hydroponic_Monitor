import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import '../test_utils.dart';

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
      container = ProviderContainer();

      // Get the MQTT service from the container
      mqttService = container.read(mqttServiceProvider);

      // Connect the MQTT service
      final connectResult = await mqttService.connect();
      expect(
        connectResult,
        isA<Success<void>>(),
        reason: 'MQTT service should connect successfully',
      );

      // Wait a moment for subscriptions to be established
      await Future.delayed(const Duration(milliseconds: 500));
    });

    tearDown(() async {
      // Clean up the container
      container.dispose();
      await mqttService.disconnect();
    });

    test('Sensor data publish and receive through provider', () async {
      // Create test sensor data
      final testData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.temperature,
        sensorId: 'provider_test_temp_001',
        deviceId: 'test_device_001',
        location: 'provider_test_zone',
      );

      // Listen to the real-time sensor data provider
      // ignore: deprecated_member_use
      final sensorStream = container.read(realTimeSensorDataProvider.stream);
      final receivedData = <SensorData>[];

      final subscription = sensorStream.listen((data) {
        receivedData.add(data);
      });

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

      print('Published sensor data to topic: $topic');
      print('Message: $messageJson');

      // Wait for the message to be processed
      await Future.delayed(const Duration(seconds: 1));

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
    }, timeout: testTimeout);

    test('Device status publish and receive through provider', () async {
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

      print('Published device status to topic: $topic');
      print('Payload: $payloadJson');

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
    }, timeout: testTimeout);

    test('Multiple sensor types through provider', () async {
      final sensorTypes = [
        SensorType.temperature,
        SensorType.humidity,
        SensorType.pH,
      ];
      final receivedData = <SensorData>[];

      // Listen to the real-time sensor data provider
      // ignore: deprecated_member_use
      final sensorStream = container.read(realTimeSensorDataProvider.stream);

      final subscription = sensorStream.listen((data) {
        receivedData.add(data);
      });

      // Publish multiple sensor types
      for (final sensorType in sensorTypes) {
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

        // Small delay between publishes
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Wait for all messages to be processed
      await Future.delayed(const Duration(seconds: 2));

      // Verify all sensor types were received
      expect(
        receivedData.length,
        equals(sensorTypes.length),
        reason: 'Should have received all sensor types through provider',
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
    }, timeout: testTimeout);

    test('Actuator state publish and receive through provider', () async {
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

      print('Published actuator state to topic: $topic');
      print('Payload: $payloadJson');

      // Wait for the message to be processed
      await Future.delayed(const Duration(seconds: 1));

      // Verify the actuator state was received through the provider
      expect(
        receivedDevices,
        isNotEmpty,
        reason: 'Should have received actuator state through provider',
      );

      final received = receivedDevices.first;
      expect(received.id, equals('rpi_pump_1'));
      expect(received.name, equals('Circulation pump'));
      expect(received.type, equals(DeviceType.pump));
      expect(received.status, equals(DeviceStatus.online));
      expect(received.isEnabled, isTrue);

      await subscription.cancel();
    }, timeout: testTimeout);

    test('MQTT connection status through provider', () async {
      // Listen to the MQTT connection status provider
      // ignore: deprecated_member_use
      final connectionStream = container.read(
        mqttConnectionStatusProvider.stream,
      );
      final connectionStatuses = <String>[];

      final subscription = connectionStream.listen((status) {
        connectionStatuses.add(status);
      });

      // Wait a moment for initial status
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify we received connection status updates
      expect(
        connectionStatuses,
        isNotEmpty,
        reason: 'Should have received MQTT connection status updates',
      );

      // Should contain connected status
      expect(
        connectionStatuses.contains('connected'),
        isTrue,
        reason: 'Should have received connected status',
      );

      await subscription.cancel();
    }, timeout: testTimeout);

    test('Provider handles malformed MQTT messages gracefully', () async {
      // ignore: deprecated_member_use
      final sensorStream = container.read(realTimeSensorDataProvider.stream);
      final receivedData = <SensorData>[];

      final subscription = sensorStream.listen((data) {
        receivedData.add(data);
      });

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

      // Verify no malformed data was processed (should be filtered out)
      final malformedData = receivedData.where(
        (data) => data.deviceId == 'malformed',
      );
      expect(
        malformedData,
        isEmpty,
        reason: 'Malformed messages should not be processed',
      );

      await subscription.cancel();
    }, timeout: testTimeout);
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
