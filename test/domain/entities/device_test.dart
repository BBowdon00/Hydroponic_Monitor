import 'package:flutter_test/flutter_test.dart';

import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/core/logger.dart';

void main() {
  group('Device', () {
    setUp(() {
      Logger.init(isTest: true);
    });

    test('creates valid device with all properties', () {
      Logger.info(
        'Testing device creation with all properties',
        tag: 'DeviceEntityTest',
      );

      final lastUpdate = DateTime.now();
      final device = Device(
        id: 'pump_001',
        name: 'Water Pump 1',
        type: DeviceType.pump,
        status: DeviceStatus.online,
        isEnabled: true,
        description: 'Main water circulation pump',
        location: 'greenhouse_a',
        lastUpdate: lastUpdate,
      );

      Logger.debug(
        'Created device: ${device.name} (${device.type.name})',
        tag: 'DeviceEntityTest',
      );

      expect(device.id, equals('pump_001'));
      expect(device.name, equals('Water Pump 1'));
      expect(device.type, equals(DeviceType.pump));
      expect(device.status, equals(DeviceStatus.online));
      expect(device.isEnabled, isTrue);
      expect(device.description, equals('Main water circulation pump'));
      expect(device.location, equals('greenhouse_a'));
      expect(device.lastUpdate, equals(lastUpdate));

      Logger.info(
        'Device creation with all properties test passed',
        tag: 'DeviceEntityTest',
      );
    });

    test('creates valid device with minimal properties', () {
      Logger.info(
        'Testing device creation with minimal properties',
        tag: 'DeviceEntityTest',
      );

      final device = Device(
        id: 'fan_001',
        name: 'Ventilation Fan',
        type: DeviceType.fan,
        status: DeviceStatus.offline,
      );

      Logger.debug(
        'Created minimal device: ${device.name}',
        tag: 'DeviceEntityTest',
      );

      expect(device.id, equals('fan_001'));
      expect(device.name, equals('Ventilation Fan'));
      expect(device.type, equals(DeviceType.fan));
      expect(device.status, equals(DeviceStatus.offline));
      expect(device.isEnabled, isFalse);
      expect(device.description, isNull);
      expect(device.location, isNull);
      expect(device.lastUpdate, isNull);

      Logger.info(
        'Device creation with minimal properties test passed',
        tag: 'DeviceEntityTest',
      );
    });

    test('copyWith works correctly', () {
      Logger.info(
        'Testing device copyWith functionality',
        tag: 'DeviceEntityTest',
      );

      final originalDevice = Device(
        id: 'heater_001',
        name: 'Water Heater',
        type: DeviceType.heater,
        status: DeviceStatus.offline,
        isEnabled: false,
      );

      Logger.debug(
        'Original device status: ${originalDevice.status.name}',
        tag: 'DeviceEntityTest',
      );

      final updatedDevice = originalDevice.copyWith(
        status: DeviceStatus.online,
        isEnabled: true,
        lastUpdate: DateTime.now(),
      );

      Logger.debug(
        'Updated device status: ${updatedDevice.status.name}',
        tag: 'DeviceEntityTest',
      );

      expect(updatedDevice.id, equals('heater_001'));
      expect(updatedDevice.name, equals('Water Heater'));
      expect(updatedDevice.type, equals(DeviceType.heater));
      expect(updatedDevice.status, equals(DeviceStatus.online));
      expect(updatedDevice.isEnabled, isTrue);
      expect(updatedDevice.lastUpdate, isNotNull);

      // Original should be unchanged
      expect(originalDevice.status, equals(DeviceStatus.offline));
      expect(originalDevice.isEnabled, isFalse);
      expect(originalDevice.lastUpdate, isNull);

      Logger.info(
        'Device copyWith functionality test passed',
        tag: 'DeviceEntityTest',
      );
    });

    test('equality works correctly', () {
      Logger.info(
        'Testing device equality comparison',
        tag: 'DeviceEntityTest',
      );

      final lastUpdate = DateTime.now();
      final device1 = Device(
        id: 'light_001',
        name: 'LED Light',
        type: DeviceType.light,
        status: DeviceStatus.online,
        isEnabled: true,
        lastUpdate: lastUpdate,
      );

      final device2 = Device(
        id: 'light_001',
        name: 'LED Light',
        type: DeviceType.light,
        status: DeviceStatus.online,
        isEnabled: true,
        lastUpdate: lastUpdate,
      );

      final device3 = Device(
        id: 'light_002',
        name: 'LED Light',
        type: DeviceType.light,
        status: DeviceStatus.online,
        isEnabled: true,
        lastUpdate: lastUpdate,
      );

      Logger.debug(
        'Comparing devices: ${device1.id} vs ${device2.id} vs ${device3.id}',
        tag: 'DeviceEntityTest',
      );

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
      expect(device1.hashCode, equals(device2.hashCode));

      Logger.info(
        'Device equality comparison test passed',
        tag: 'DeviceEntityTest',
      );
    });

    test('toString provides useful information', () {
      Logger.info(
        'Testing device toString representation',
        tag: 'DeviceEntityTest',
      );

      final device = Device(
        id: 'sensor_001',
        name: 'Temperature Sensor',
        type: DeviceType.sensor,
        status: DeviceStatus.online,
        isEnabled: true,
      );

      final stringRepresentation = device.toString();

      Logger.debug(
        'Device string representation: $stringRepresentation',
        tag: 'DeviceEntityTest',
      );

      expect(stringRepresentation, contains('sensor_001'));
      expect(stringRepresentation, contains('Temperature Sensor'));
      expect(stringRepresentation, contains('sensor'));
      expect(stringRepresentation, contains('online'));
      expect(stringRepresentation, contains('true'));

      Logger.info(
        'Device toString representation test passed',
        tag: 'DeviceEntityTest',
      );
    });
  });

  group('DeviceType', () {
    setUp(() {
      Logger.init(isTest: true);
    });

    test('display names are correct', () {
      Logger.info('Testing DeviceType display names', tag: 'DeviceEntityTest');

      final displayNames = {
        DeviceType.pump: 'Pump',
        DeviceType.fan: 'Fan',
        DeviceType.heater: 'Heater',
        DeviceType.light: 'Light',
        DeviceType.sensor: 'Sensor',
        DeviceType.controller: 'Controller',
      };

      for (final entry in displayNames.entries) {
        Logger.debug(
          '${entry.key.name} -> ${entry.value}',
          tag: 'DeviceEntityTest',
        );
        expect(entry.key.displayName, equals(entry.value));
      }

      Logger.info(
        'DeviceType display names test passed',
        tag: 'DeviceEntityTest',
      );
    });
  });

  group('DeviceStatus', () {
    setUp(() {
      Logger.init(isTest: true);
    });

    test('display names are correct', () {
      Logger.info(
        'Testing DeviceStatus display names',
        tag: 'DeviceEntityTest',
      );

      final displayNames = {
        DeviceStatus.online: 'Online',
        DeviceStatus.offline: 'Offline',
        DeviceStatus.pending: 'Pending',
        DeviceStatus.error: 'Error',
        DeviceStatus.stopped: 'Stopped',
      };

      for (final entry in displayNames.entries) {
        Logger.debug(
          '${entry.key.name} -> ${entry.value}',
          tag: 'DeviceEntityTest',
        );
        expect(entry.key.displayName, equals(entry.value));
      }

      Logger.info(
        'DeviceStatus display names test passed',
        tag: 'DeviceEntityTest',
      );
    });
  });
}
