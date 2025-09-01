/// Domain entity for sensor data readings.
class SensorData {
  const SensorData({
    required this.id,
    required this.sensorType,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.deviceId,
    this.location,
  });

  final String id;
  final SensorType sensorType;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String? deviceId;
  final String? location;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sensorType == other.sensorType &&
          value == other.value &&
          unit == other.unit &&
          timestamp == other.timestamp &&
          deviceId == other.deviceId &&
          location == other.location;

  @override
  int get hashCode =>
      id.hashCode ^
      sensorType.hashCode ^
      value.hashCode ^
      unit.hashCode ^
      timestamp.hashCode ^
      deviceId.hashCode ^
      location.hashCode;

  @override
  String toString() =>
      'SensorData(id: $id, type: $sensorType, value: $value$unit, timestamp: $timestamp)';
}

/// Types of sensors supported by the system.
enum SensorType {
  temperature,
  humidity,
  waterLevel,
  pH,
  electricalConductivity,
  lightIntensity,
  airQuality,
}

extension SensorTypeExtension on SensorType {
  String get displayName {
    switch (this) {
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.humidity:
        return 'Humidity';
      case SensorType.waterLevel:
        return 'Water Level';
      case SensorType.pH:
        return 'pH Level';
      case SensorType.electricalConductivity:
        return 'Electrical Conductivity';
      case SensorType.lightIntensity:
        return 'Light Intensity';
      case SensorType.airQuality:
        return 'Air Quality';
    }
  }

  String get defaultUnit {
    switch (this) {
      case SensorType.temperature:
        return '°C';
      case SensorType.humidity:
        return '%';
      case SensorType.waterLevel:
        return 'cm';
      case SensorType.pH:
        return 'pH';
      case SensorType.electricalConductivity:
        return 'µS/cm';
      case SensorType.lightIntensity:
        return 'lux';
      case SensorType.airQuality:
        return 'ppm';
    }
  }
}
