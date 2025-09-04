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

  group('Sensor Data Generation', () {
    test('should generate realistic temperature values', () {
      final data = TestDataGenerator.generateSensorData(
        sensorType: SensorType.temperature,
        timestamp: DateTime(2025, 1, 15, 14, 30), // 2:30 PM
      );

      expect(data.sensorType, equals(SensorType.temperature));
      expect(data.unit, equals('°C'));
      expect(data.value, greaterThanOrEqualTo(15.0));
      expect(data.value, lessThanOrEqualTo(35.0));
    });

    test('should generate realistic humidity values', () {
      final data = TestDataGenerator.generateSensorData(
        sensorType: SensorType.humidity,
        timestamp: DateTime(2025, 1, 15, 12, 0), // Noon
      );

      expect(data.sensorType, equals(SensorType.humidity));
      expect(data.unit, equals('%'));
      expect(data.value, greaterThanOrEqualTo(40.0));
      expect(data.value, lessThanOrEqualTo(90.0));
    });

    test('should generate realistic pH values', () {
      final data = TestDataGenerator.generateSensorData(
        sensorType: SensorType.pH,
      );

      expect(data.sensorType, equals(SensorType.pH));
      expect(data.unit, equals('pH'));
      expect(data.value, greaterThanOrEqualTo(5.5));
      expect(data.value, lessThanOrEqualTo(7.0));
    });

    test('should generate light intensity based on time of day', () {
      // Test daytime reading
      final dayData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.lightIntensity,
        timestamp: DateTime(2025, 1, 15, 14, 0), // 2 PM
      );

      // Test nighttime reading
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
    test('should generate devices with correct types', () {
      for (final deviceType in DeviceType.values) {
        final device = TestDataGenerator.generateDevice(type: deviceType);
        expect(device.type, equals(deviceType));
        expect(device.id, contains(deviceType.name));
      }
    });

    test('should generate device names consistently', () {
      final device = TestDataGenerator.generateDevice(
        id: 'pump_001',
        type: DeviceType.pump,
      );

      expect(device.name, contains('001'));
      expect(device.id, equals('pump_001'));
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

  group('Data Validation Rules', () {
    test('should validate sensor value ranges', () {
      final tempData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.temperature,
      );

      // Temperature should be in reasonable range for hydroponics
      expect(tempData.value, greaterThanOrEqualTo(10.0));
      expect(tempData.value, lessThanOrEqualTo(40.0));
    });

    test('should validate pH values for hydroponics', () {
      final phData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.pH,
      );

      // pH should be in hydroponic range
      expect(phData.value, greaterThanOrEqualTo(5.0));
      expect(phData.value, lessThanOrEqualTo(7.5));
    });

    test('should validate electrical conductivity values', () {
      final ecData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.electricalConductivity,
      );

      // EC should be in reasonable range for nutrient solutions
      expect(ecData.value, greaterThanOrEqualTo(500.0));
      expect(ecData.value, lessThanOrEqualTo(2000.0));
    });

    test('should validate water level percentages', () {
      final waterData = TestDataGenerator.generateSensorData(
        sensorType: SensorType.waterLevel,
      );

      // Water level should be percentage-like
      expect(waterData.value, greaterThanOrEqualTo(0.0));
      expect(waterData.value, lessThanOrEqualTo(100.0));
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

  group('Error Handling and Edge Cases', () {
    test('should handle edge case timestamps', () {
      final futureData = TestDataGenerator.generateSensorData(
        timestamp: DateTime(2030, 12, 31, 23, 59, 59),
      );

      final pastData = TestDataGenerator.generateSensorData(
        timestamp: DateTime(2020, 1, 1, 0, 0, 0),
      );

      expect(futureData.timestamp.year, equals(2030));
      expect(pastData.timestamp.year, equals(2020));
    });

    test('should generate valid data for all sensor types', () {
      for (final sensorType in SensorType.values) {
        expect(() {
          TestDataGenerator.generateSensorData(sensorType: sensorType);
        }, returnsNormally);
      }
    });

    test('should generate valid devices for all device types', () {
      for (final deviceType in DeviceType.values) {
        expect(() {
          TestDataGenerator.generateDevice(type: deviceType);
        }, returnsNormally);
      }
    });
  });

  group('Performance Tests', () {
    test('should generate large batches efficiently', () {
      final stopwatch = Stopwatch()..start();

      final largeBatch = TestDataGenerator.generateSensorDataBatch(count: 1000);

      stopwatch.stop();

      expect(largeBatch.length, equals(1000));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast
    });

    test('should generate historical data efficiently', () {
      final stopwatch = Stopwatch()..start();

      final historicalData = TestDataGenerator.generateHistoricalData(
        sensorType: SensorType.temperature,
        start: DateTime.now().subtract(Duration(days: 7)),
        end: DateTime.now(),
        interval: Duration(minutes: 15),
      );

      stopwatch.stop();

      expect(
        historicalData.length,
        greaterThan(500),
      ); // Week of 15-min intervals
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
      ); // Should be reasonably fast
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
