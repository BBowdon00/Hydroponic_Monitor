import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import '../test_utils.dart';

/// Unit tests for MQTT topic structure, data formatting, and business logic
/// that doesn't require actual infrastructure services.
void main() {
  group('MQTT Topic Structure', () {
    test('should generate correct sensor topic paths', () {
      final topic = TestMqttTopics.sensorTopicFor('rpi');
      expect(topic, equals('grow/rpi/sensor'));
    });

    test('should generate correct actuator topic paths', () {
      final topic = TestMqttTopics.actuatorTopicFor('esp32_1');
      expect(topic, equals('grow/esp32_1/actuator'));
    });

    test('should generate correct device topic paths', () {
      final topic = TestMqttTopics.deviceTopicFor('rpi');
      expect(topic, equals('grow/rpi/device'));
    });

    test('should handle device node names with underscores', () {
      final topic = TestMqttTopics.sensorTopicFor('esp32_node_01');
      expect(topic, equals('grow/esp32_node_01/sensor'));
    });
  });

  group('Test Data Generation', () {
    test('should generate realistic sensor data with time-based values', () {
      // Test that light intensity varies by time of day (key business logic)
      final dayData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.lightIntensity,
        timestamp: DateTime(2025, 1, 15, 14, 0), // 2 PM
      );

      final nightData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.lightIntensity,
        timestamp: DateTime(2025, 1, 15, 2, 0), // 2 AM
      );

      expect(dayData.value, greaterThan(nightData.value));
      expect(nightData.value, lessThanOrEqualTo(100.0)); // Very low at night
      expect(dayData.value, greaterThanOrEqualTo(10000.0)); // Higher during day
    });

    test('should generate historical data with consistent intervals', () {
      final start = DateTime(2025, 1, 1, 0, 0);
      final end = DateTime(2025, 1, 1, 12, 0);
      final interval = Duration(hours: 1);

      final data = TestDataGenerator.generateHistoricalData(
        sensorType: SensorType.temperature,
        start: start,
        end: end,
        interval: interval,
      );

      expect(data.length, equals(12)); // 12 hours worth of data

      // Check intervals
      for (int i = 1; i < data.length; i++) {
        final timeDiff = data[i].timestamp.difference(data[i - 1].timestamp);
        expect(timeDiff, equals(interval));
      }
    });
  });

  group('Device Generation', () {
    test('should generate devices with correct types and consistent naming', () {
      for (final deviceType in DeviceType.values) {
        final device = TestDataGenerator.generateDevice(type: deviceType);
        expect(device.type, equals(deviceType));
        expect(device.id, contains(deviceType.name));
      }
      
      // Test consistent naming
      final customDevice = TestDataGenerator.generateDevice(
        id: 'pump_001',
        type: DeviceType.pump,
      );
      expect(customDevice.name, contains('001'));
      expect(customDevice.id, equals('pump_001'));
    });

    test('should handle all device statuses', () {
      final statuses = <DeviceStatus>{};

      // Generate many devices to test randomness
      for (int i = 0; i < 100; i++) {
        final device = TestDataGenerator.generateDevice();
        statuses.add(device.status);
      }

      // Should see multiple different statuses
      expect(statuses.length, greaterThan(1));
    });
  });

  group('JSON Data Format Validation', () {
    test('should create valid sensor JSON for MQTT', () {
      final sensorData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.temperature,
        sensorId: 'temp_sensor_01',
      );

      final jsonString = json.encode({
        'ts': sensorData.timestamp.toUtc().toIso8601String(),
        'value': sensorData.value,
        'unit': sensorData.unit,
        'accuracy': 0.1,
      });

      // Verify JSON is valid and contains expected fields
      final parsed = json.decode(jsonString) as Map<String, dynamic>;
      expect(parsed['ts'], isA<String>());
      expect(parsed['value'], isA<double>());
      expect(parsed['unit'], equals(sensorData.unit));
      expect(parsed['accuracy'], equals(0.1));

      // Verify timestamp format
      final timestamp = DateTime.parse(parsed['ts']);
      expect(timestamp.isUtc, isTrue);
    });

    test('should create valid actuator state JSON for MQTT', () {
      final stateJson = json.encode({
        'deviceType': 'pump',
        'deviceID': '1',
        'location': 'tent',
        'running': true,
        'description': 'main circulation pump',
      });

      final parsed = json.decode(stateJson) as Map<String, dynamic>;
      expect(parsed['deviceType'], equals('pump'));
      expect(parsed['deviceID'], equals('1'));
      expect(parsed['location'], equals('tent'));
      expect(parsed['running'], equals(true));
      expect(parsed['description'], equals('main circulation pump'));
    });

    test('should create valid device status JSON for MQTT', () {
      final statusJson = json.encode({
        'deviceType': 'microcontroller',
        'deviceID': '1',
        'location': 'tent',
        'running': false,
        'description': 'esp32 board offline',
      });

      final parsed = json.decode(statusJson) as Map<String, dynamic>;
      expect(parsed['deviceType'], equals('microcontroller'));
      expect(parsed['deviceID'], equals('1'));
      expect(parsed['location'], equals('tent'));
      expect(parsed['running'], equals(false));
      expect(parsed['description'], equals('esp32 board offline'));
    });
  });

  group('Batch Data Generation', () {
    test('should generate consistent batch data', () {
      final batch = TestDataGenerator.generateSensorDataBatch(
        count: 10,
        sensorType: SensorType.humidity,
        interval: Duration(minutes: 5),
      );

      expect(batch.length, equals(10));

      // All should be humidity sensors
      for (final data in batch) {
        expect(data.sensorType, equals(SensorType.humidity));
      }

      // Check time intervals
      for (int i = 1; i < batch.length; i++) {
        final timeDiff = batch[i].timestamp.difference(batch[i - 1].timestamp);
        expect(timeDiff, equals(Duration(minutes: 5)));
      }
    });

    test('should generate diverse sensor types when not specified', () {
      final batch = TestDataGenerator.generateSensorDataBatch(count: 20);

      final sensorTypes = batch.map((data) => data.sensorType).toSet();
      expect(sensorTypes.length, greaterThan(1)); // Should have variety
    });
  });

  group('New MQTT Payload Format Validation', () {
    test('should create valid sensor payload for MQTT', () {
      final payload = TestMqttPayloads.sensorPayload(
        deviceType: 'temperature',
        deviceID: '1',
        location: 'tent',
        value: 23.22,
        description: 'under light',
      );

      expect(payload['deviceType'], equals('temperature'));
      expect(payload['deviceID'], equals('1'));
      expect(payload['location'], equals('tent'));
      expect(payload['value'], equals('23.22')); // String format
      expect(payload['description'], equals('under light'));
    });

    test('should create valid actuator payload for MQTT', () {
      final payload = TestMqttPayloads.actuatorPayload(
        deviceType: 'pump',
        deviceID: '1',
        location: 'tent',
        running: true,
        description: 'main circulation',
      );

      expect(payload['deviceType'], equals('pump'));
      expect(payload['deviceID'], equals('1'));
      expect(payload['location'], equals('tent'));
      expect(payload['running'], equals(true));
      expect(payload['description'], equals('main circulation'));
    });

    test('should create valid device payload for MQTT', () {
      final payload = TestMqttPayloads.devicePayload(
        deviceType: 'microcontroller',
        deviceID: '1',
        location: 'tent',
        running: false,
        description: 'esp32 board on floor',
      );

      expect(payload['deviceType'], equals('microcontroller'));
      expect(payload['running'], equals(false));
      expect(payload['description'], equals('esp32 board on floor'));
    });

    test('should generate sensor payloads for all sensor types', () {
      for (final sensorType in SensorType.values) {
        final payload = TestMqttPayloads.generateSensorPayload(sensorType);

        expect(payload['deviceType'], equals(sensorType.name));
        expect(payload['deviceID'], equals('1'));
        expect(payload['location'], equals('tent'));
        expect(payload['value'], isA<String>());
        expect(payload['description'], contains(sensorType.name));
      }
    });
  });
}
