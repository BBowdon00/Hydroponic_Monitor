import 'dart:io';
import 'dart:math';

import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';

/// Utilities for generating realistic test data that mirrors production scenarios.
class TestDataGenerator {
  static final Random _random = Random();

  /// Generate realistic sensor data for a specific sensor type.
  static SensorData generateSensorData({
    SensorType? sensorType,
    String? sensorId,
    DateTime? timestamp,
    String? deviceId,
    String? location,
  }) {
    final type = sensorType ?? _randomSensorType();
    final id = sensorId ?? 'sensor_${type.name}_${_random.nextInt(1000)}';
    final time = timestamp ?? DateTime.now();

    return SensorData(
      id: id,
      sensorType: type,
      value: _generateRealisticValue(type, time),
      unit: type.defaultUnit,
      timestamp: time,
      deviceId: deviceId ?? 'device_${_random.nextInt(100)}',
      location: location ?? _randomLocation(),
    );
  }

  /// Generate a batch of realistic sensor data points.
  static List<SensorData> generateSensorDataBatch({
    int count = 10,
    SensorType? sensorType,
    Duration? interval,
    DateTime? startTime,
  }) {
    final intervalDuration = interval ?? const Duration(minutes: 5);
    final start =
        startTime ?? DateTime.now().subtract(Duration(minutes: count * 5));

    return List.generate(count, (index) {
      return generateSensorData(
        sensorType: sensorType,
        timestamp: start.add(
          Duration(milliseconds: intervalDuration.inMilliseconds * index),
        ),
      );
    });
  }

  /// Generate realistic historical data for a time range.
  static List<SensorData> generateHistoricalData({
    required SensorType sensorType,
    required DateTime start,
    required DateTime end,
    Duration interval = const Duration(hours: 1),
    String? sensorId,
  }) {
    final data = <SensorData>[];
    final id = sensorId ?? 'sensor_${sensorType.name}_001';

    DateTime current = start;
    while (current.isBefore(end)) {
      data.add(
        SensorData(
          id: id,
          sensorType: sensorType,
          value: _generateRealisticValue(sensorType, current),
          unit: sensorType.defaultUnit,
          timestamp: current,
          deviceId: 'device_001',
          location: 'greenhouse_zone_1',
        ),
      );
      current = current.add(interval);
    }

    return data;
  }

  /// Generate realistic device data.
  static Device generateDevice({
    String? id,
    DeviceType? type,
    DeviceStatus? status,
    String? name,
    String? location,
    bool? isEnabled,
  }) {
    final deviceType = type ?? _randomDeviceType();
    final deviceId =
        id ??
        '${deviceType.name}_${_random.nextInt(1000).toString().padLeft(3, '0')}';

    return Device(
      id: deviceId,
      name: name ?? '${deviceType.displayName} ${deviceId.split('_').last}',
      type: deviceType,
      status: status ?? _randomDeviceStatus(),
      location: location ?? _randomLocation(),
      isEnabled: isEnabled ?? _random.nextBool(),
      lastUpdate: DateTime.now().subtract(
        Duration(minutes: _random.nextInt(60)),
      ),
    );
  }

  /// Generate a realistic value for a sensor type with time-based variation.
  static double _generateRealisticValue(SensorType type, DateTime timestamp) {
    final hourOfDay = timestamp.hour;
    final baseRandom = _random.nextDouble();

    switch (type) {
      case SensorType.temperature:
        // Temperature varies with time of day: 18-22°C at night, 22-28°C during day
        final baseTemp = 20.0 + (4.0 * sin((hourOfDay - 6) * pi / 12));
        return baseTemp + (baseRandom * 4.0 - 2.0); // ±2°C variation

      case SensorType.humidity:
        // Humidity is inversely related to temperature: 60-80% generally
        final baseHumidity = 70.0 - (hourOfDay - 12).abs() * 0.8;
        return (baseHumidity + (baseRandom * 20.0 - 10.0)).clamp(40.0, 90.0);

      case SensorType.waterLevel:
        // Water level decreases slowly during day, refilled periodically
        final baseLevel = 25.0 - (hourOfDay * 0.5);
        return (baseLevel + (baseRandom * 5.0 - 2.5)).clamp(5.0, 30.0);

      case SensorType.pH:
        // pH stays relatively stable: 5.8-6.5 for hydroponics
        return 6.1 + (baseRandom * 0.8 - 0.4);

      case SensorType.electricalConductivity:
        // EC varies with nutrient concentration: 800-1500 µS/cm
        return 1100.0 + (baseRandom * 400.0 - 200.0);

      case SensorType.lightIntensity:
        // Light follows day/night cycle: 0 at night, up to 50000 lux during day
        if (hourOfDay < 6 || hourOfDay > 20) return baseRandom * 100; // Night
        final dayProgress = (hourOfDay - 6) / 14.0; // 6 AM to 8 PM
        final lightCurve = sin(dayProgress * pi);
        return lightCurve * 45000 + (baseRandom * 5000);

      case SensorType.airQuality:
        // Air quality: lower ppm is better, varies during day
        final basePPM =
            400.0 + (hourOfDay > 12 ? 50.0 : 0.0); // Worse in afternoon
        return basePPM + (baseRandom * 100.0 - 50.0);
    }
  }

  static SensorType _randomSensorType() {
    return SensorType.values[_random.nextInt(SensorType.values.length)];
  }

  static DeviceType _randomDeviceType() {
    return DeviceType.values[_random.nextInt(DeviceType.values.length)];
  }

  static DeviceStatus _randomDeviceStatus() {
    return DeviceStatus.values[_random.nextInt(DeviceStatus.values.length)];
  }

  static String _randomLocation() {
    final zones = [
      'greenhouse_zone_1',
      'greenhouse_zone_2',
      'nursery',
      'propagation_area',
    ];
    return zones[_random.nextInt(zones.length)];
  }

  /// Create fallback instances for mocktail registration.
  static SensorData createFallbackSensorData() {
    return SensorData(
      id: 'fallback_sensor',
      sensorType: SensorType.temperature,
      value: 25.0,
      unit: '°C',
      timestamp: DateTime.now(),
    );
  }

  static Device createFallbackDevice() {
    return Device(
      id: 'fallback_device',
      name: 'Fallback Device',
      type: DeviceType.pump,
      status: DeviceStatus.online,
    );
  }
}

/// MQTT topic patterns for testing.
class TestMqttTopics {
  static const String sensorDataTopic = 'grow/tent/+/sensor/+/+/state';
  static const String deviceStatusTopic = 'grow/tent/+/actuator/+/+/state';
  static const String deviceCommandTopic = 'grow/tent/+/actuator/+/+/set';
  static const String nodeStatusTopic = 'grow/tent/+/status';

  static String sensorDataTopicFor(String node, String type, String id) =>
      'grow/tent/$node/sensor/$type/$id/state';
  static String deviceStatusTopicFor(String node, String type, String id) =>
      'grow/tent/$node/actuator/$type/$id/state';
  static String deviceCommandTopicFor(String node, String type, String id) =>
      'grow/tent/$node/actuator/$type/$id/set';
  static String nodeStatusTopicFor(String node) => 'grow/tent/$node/status';
}

/// Test configuration constants that can be overridden by environment variables.
class TestConfig {
  static String get testMqttHost =>
      Platform.environment['MQTT_HOST'] ?? 'localhost';

  static int get testMqttPort =>
      int.tryParse(Platform.environment['MQTT_PORT'] ?? '') ?? 1883;

  static String get testInfluxUrl =>
      Platform.environment['INFLUX_URL'] ?? 'http://localhost:8086';

  static String get testInfluxToken =>
      Platform.environment['INFLUX_TOKEN'] ??
      'test-token-for-integration-tests';

  static String get testInfluxOrg =>
      Platform.environment['INFLUX_ORG'] ?? 'test-org';

  static String get testInfluxBucket =>
      Platform.environment['INFLUX_BUCKET'] ?? 'test-bucket';
}
