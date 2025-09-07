import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/core/logger.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/presentation/providers/sensor_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';

void main() {
  setUpAll(() {
    Logger.init(isTest: true);
  });

  group('Sensor Provider Simple Tests', () {
    test('Basic sensor data structure works', () {
      final sensorData = SensorData(
        id: 'test_sensor',
        sensorType: SensorType.temperature,
        value: 25.0,
        unit: '°C',
        timestamp: DateTime.now(),
        deviceId: 'test_device',
        location: 'test_location',
      );

      expect(sensorData.sensorType, equals(SensorType.temperature));
      expect(sensorData.value, equals(25.0));
    });

    test('hasSensorDataProvider returns false initially', () {
      final container = ProviderContainer();
      
      // Initially should have no sensor data
      final hasSensorData = container.read(hasSensorDataProvider);
      expect(hasSensorData, isFalse);
      
      container.dispose();
    });

    test('latestSensorDataProvider returns null initially', () {
      final container = ProviderContainer();
      
      // Should return null for any sensor type initially
      final tempData = container.read(latestSensorDataProvider(SensorType.temperature));
      expect(tempData, isNull);
      
      final humidityData = container.read(latestSensorDataProvider(SensorType.humidity));
      expect(humidityData, isNull);
      
      container.dispose();
    });
  });
}