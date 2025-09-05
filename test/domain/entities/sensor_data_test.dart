import 'package:flutter_test/flutter_test.dart';

import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/core/logger.dart';

void main() {
  group('SensorData', () {
    setUp(() {
      Logger.init(isTest: true);
    });

    test('creates valid sensor data with all properties', () {
      Logger.info(
        "Testing sensor data creation with all properties",
        tag: 'SensorDataTest',
      );

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

      Logger.debug(
        "Created sensor data: ${sensorData.sensorType.name} = ${sensorData.value} ${sensorData.unit}",
        tag: 'SensorDataTest',
      );

      expect(sensorData.id, equals('temp_001'));
      expect(sensorData.sensorType, equals(SensorType.temperature));
      expect(sensorData.value, equals(23.5));
      expect(sensorData.unit, equals('°C'));
      expect(sensorData.timestamp, equals(timestamp));
      expect(sensorData.deviceId, equals('device_001'));
      expect(sensorData.location, equals('greenhouse_a'));

      Logger.info(
        "Sensor data creation with all properties test passed",
        tag: 'SensorDataTest',
      );
    });

    test('creates valid sensor data with minimal properties', () {
      Logger.info(
        "Testing sensor data creation with minimal properties",
        tag: 'SensorDataTest',
      );

      final timestamp = DateTime.now();
      final sensorData = SensorData(
        id: 'humidity_001',
        sensorType: SensorType.humidity,
        value: 65.0,
        unit: '%',
        timestamp: timestamp,
      );

      Logger.debug(
        "Created minimal sensor data: ${sensorData.sensorType.name} = ${sensorData.value}%",
        tag: 'SensorDataTest',
      );

      expect(sensorData.id, equals('humidity_001'));
      expect(sensorData.sensorType, equals(SensorType.humidity));
      expect(sensorData.value, equals(65.0));
      expect(sensorData.unit, equals('%'));
      expect(sensorData.timestamp, equals(timestamp));
      expect(sensorData.deviceId, isNull);
      expect(sensorData.location, isNull);

      Logger.info(
        "Sensor data creation with minimal properties test passed",
        tag: 'SensorDataTest',
      );
    });

    test('equality works correctly', () {
      Logger.info(
        "Testing sensor data equality comparison",
        tag: 'SensorDataTest',
      );

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

      Logger.debug(
        "Comparing sensor data: ${sensorData1.id} vs ${sensorData2.id} vs ${sensorData3.id}",
        tag: 'SensorDataTest',
      );

      expect(sensorData1, equals(sensorData2));
      expect(sensorData1, isNot(equals(sensorData3)));
      expect(sensorData1.hashCode, equals(sensorData2.hashCode));

      Logger.info(
        "Sensor data equality comparison test passed",
        tag: 'SensorDataTest',
      );
    });

    test('toString provides useful information', () {
      Logger.info(
        "Testing sensor data toString representation",
        tag: 'SensorDataTest',
      );

      final timestamp = DateTime.now();
      final sensorData = SensorData(
        id: 'temp_001',
        sensorType: SensorType.temperature,
        value: 23.5,
        unit: '°C',
        timestamp: timestamp,
      );

      final stringRepresentation = sensorData.toString();

      Logger.debug(
        "Sensor data string representation: $stringRepresentation",
        tag: 'SensorDataTest',
      );

      expect(stringRepresentation, contains('temp_001'));
      expect(stringRepresentation, contains('temperature'));
      expect(stringRepresentation, contains('23.5'));
      expect(stringRepresentation, contains('°C'));

      Logger.info(
        "Sensor data toString representation test passed",
        tag: 'SensorDataTest',
      );
    });
  });

  group('SensorType', () {
    setUp(() {
      Logger.init(isTest: true);
    });

    test('display names are correct', () {
      Logger.info("Testing SensorType display names", tag: 'SensorDataTest');

      final displayNames = {
        SensorType.temperature: 'Temperature',
        SensorType.humidity: 'Humidity',
        SensorType.waterLevel: 'Water Level',
        SensorType.pH: 'pH Level',
        SensorType.electricalConductivity: 'Electrical Conductivity',
        SensorType.lightIntensity: 'Light Intensity',
        SensorType.airQuality: 'Air Quality',
        SensorType.powerUsage: 'Power Usage',
      };

      for (final entry in displayNames.entries) {
        Logger.debug(
          "${entry.key.name} -> ${entry.value}",
          tag: 'SensorDataTest',
        );
        expect(entry.key.displayName, equals(entry.value));
      }

      Logger.info(
        "SensorType display names test passed",
        tag: 'SensorDataTest',
      );
    });

    test('default units are correct', () {
      Logger.info("Testing SensorType default units", tag: 'SensorDataTest');

      final defaultUnits = {
        SensorType.temperature: '°C',
        SensorType.humidity: '%',
        SensorType.waterLevel: 'cm',
        SensorType.pH: 'pH',
        SensorType.electricalConductivity: 'µS/cm',
        SensorType.lightIntensity: 'lux',
        SensorType.airQuality: 'ppm',
        SensorType.powerUsage: 'W',
      };

      for (final entry in defaultUnits.entries) {
        Logger.debug(
          "${entry.key.name} -> ${entry.value}",
          tag: 'SensorDataTest',
        );
        expect(entry.key.defaultUnit, equals(entry.value));
      }

      Logger.info(
        "SensorType default units test passed",
        tag: 'SensorDataTest',
      );
    });
  });
}
