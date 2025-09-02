import 'package:flutter_test/flutter_test.dart';

import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

void main() {
  group('SensorData', () {
    test('creates valid sensor data with all properties', () {
      final timestamp = DateTime.now();
      final sensorData = SensorData(
        id: 'temp_001',
        sensorType: SensorType.temperature,
        value: 23.5,
        unit: '°C',
        timestamp: timestamp,
        deviceId: 'device_001',
        location: 'greenhouse_a',
      );

      expect(sensorData.id, equals('temp_001'));
      expect(sensorData.sensorType, equals(SensorType.temperature));
      expect(sensorData.value, equals(23.5));
      expect(sensorData.unit, equals('°C'));
      expect(sensorData.timestamp, equals(timestamp));
      expect(sensorData.deviceId, equals('device_001'));
      expect(sensorData.location, equals('greenhouse_a'));
    });

    test('creates valid sensor data with minimal properties', () {
      final timestamp = DateTime.now();
      final sensorData = SensorData(
        id: 'humidity_001',
        sensorType: SensorType.humidity,
        value: 65.0,
        unit: '%',
        timestamp: timestamp,
      );

      expect(sensorData.id, equals('humidity_001'));
      expect(sensorData.sensorType, equals(SensorType.humidity));
      expect(sensorData.value, equals(65.0));
      expect(sensorData.unit, equals('%'));
      expect(sensorData.timestamp, equals(timestamp));
      expect(sensorData.deviceId, isNull);
      expect(sensorData.location, isNull);
    });

    test('equality works correctly', () {
      final timestamp = DateTime.now();
      final sensorData1 = SensorData(
        id: 'test_001',
        sensorType: SensorType.pH,
        value: 6.5,
        unit: 'pH',
        timestamp: timestamp,
      );

      final sensorData2 = SensorData(
        id: 'test_001',
        sensorType: SensorType.pH,
        value: 6.5,
        unit: 'pH',
        timestamp: timestamp,
      );

      final sensorData3 = SensorData(
        id: 'test_002',
        sensorType: SensorType.pH,
        value: 6.5,
        unit: 'pH',
        timestamp: timestamp,
      );

      expect(sensorData1, equals(sensorData2));
      expect(sensorData1, isNot(equals(sensorData3)));
      expect(sensorData1.hashCode, equals(sensorData2.hashCode));
    });

    test('toString provides useful information', () {
      final timestamp = DateTime.now();
      final sensorData = SensorData(
        id: 'temp_001',
        sensorType: SensorType.temperature,
        value: 23.5,
        unit: '°C',
        timestamp: timestamp,
      );

      final stringRepresentation = sensorData.toString();
      expect(stringRepresentation, contains('temp_001'));
      expect(stringRepresentation, contains('temperature'));
      expect(stringRepresentation, contains('23.5'));
      expect(stringRepresentation, contains('°C'));
    });
  });

  group('SensorType', () {
    test('display names are correct', () {
      expect(SensorType.temperature.displayName, equals('Temperature'));
      expect(SensorType.humidity.displayName, equals('Humidity'));
      expect(SensorType.waterLevel.displayName, equals('Water Level'));
      expect(SensorType.pH.displayName, equals('pH Level'));
      expect(
        SensorType.electricalConductivity.displayName,
        equals('Electrical Conductivity'),
      );
      expect(SensorType.lightIntensity.displayName, equals('Light Intensity'));
      expect(SensorType.airQuality.displayName, equals('Air Quality'));
    });

    test('default units are correct', () {
      expect(SensorType.temperature.defaultUnit, equals('°C'));
      expect(SensorType.humidity.defaultUnit, equals('%'));
      expect(SensorType.waterLevel.defaultUnit, equals('cm'));
      expect(SensorType.pH.defaultUnit, equals('pH'));
      expect(SensorType.electricalConductivity.defaultUnit, equals('µS/cm'));
      expect(SensorType.lightIntensity.defaultUnit, equals('lux'));
      expect(SensorType.airQuality.defaultUnit, equals('ppm'));
    });
  });
}
