import 'package:flutter_test/flutter_test.dart';

import 'package:hydroponic_monitor/domain/entities/device.dart';

void main() {
  group('Device', () {
    test('creates valid device with all properties', () {
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

      expect(device.id, equals('pump_001'));
      expect(device.name, equals('Water Pump 1'));
      expect(device.type, equals(DeviceType.pump));
      expect(device.status, equals(DeviceStatus.online));
      expect(device.isEnabled, isTrue);
      expect(device.description, equals('Main water circulation pump'));
      expect(device.location, equals('greenhouse_a'));
      expect(device.lastUpdate, equals(lastUpdate));
    });

    test('creates valid device with minimal properties', () {
      final device = Device(
        id: 'fan_001',
        name: 'Ventilation Fan',
        type: DeviceType.fan,
        status: DeviceStatus.offline,
      );

      expect(device.id, equals('fan_001'));
      expect(device.name, equals('Ventilation Fan'));
      expect(device.type, equals(DeviceType.fan));
      expect(device.status, equals(DeviceStatus.offline));
      expect(device.isEnabled, isFalse);
      expect(device.description, isNull);
      expect(device.location, isNull);
      expect(device.lastUpdate, isNull);
    });

    test('copyWith works correctly', () {
      final originalDevice = Device(
        id: 'heater_001',
        name: 'Water Heater',
        type: DeviceType.heater,
        status: DeviceStatus.offline,
        isEnabled: false,
      );

      final updatedDevice = originalDevice.copyWith(
        status: DeviceStatus.online,
        isEnabled: true,
        lastUpdate: DateTime.now(),
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
    });

    test('equality works correctly', () {
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

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
      expect(device1.hashCode, equals(device2.hashCode));
    });

    test('toString provides useful information', () {
      final device = Device(
        id: 'sensor_001',
        name: 'Temperature Sensor',
        type: DeviceType.sensor,
        status: DeviceStatus.online,
        isEnabled: true,
      );

      final stringRepresentation = device.toString();
      expect(stringRepresentation, contains('sensor_001'));
      expect(stringRepresentation, contains('Temperature Sensor'));
      expect(stringRepresentation, contains('sensor'));
      expect(stringRepresentation, contains('online'));
      expect(stringRepresentation, contains('true'));
    });
  });

  group('DeviceType', () {
    test('display names are correct', () {
      expect(DeviceType.pump.displayName, equals('Pump'));
      expect(DeviceType.fan.displayName, equals('Fan'));
      expect(DeviceType.heater.displayName, equals('Heater'));
      expect(DeviceType.light.displayName, equals('Light'));
      expect(DeviceType.sensor.displayName, equals('Sensor'));
      expect(DeviceType.controller.displayName, equals('Controller'));
    });
  });

  group('DeviceStatus', () {
    test('display names are correct', () {
      expect(DeviceStatus.online.displayName, equals('Online'));
      expect(DeviceStatus.offline.displayName, equals('Offline'));
      expect(DeviceStatus.pending.displayName, equals('Pending'));
      expect(DeviceStatus.error.displayName, equals('Error'));
      expect(DeviceStatus.stopped.displayName, equals('Stopped'));
    });
  });
}