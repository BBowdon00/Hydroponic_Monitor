import 'package:freezed_annotation/freezed_annotation.dart';

part 'sensor_data.freezed.dart';
part 'sensor_data.g.dart';

/// Sensor data types
enum SensorType {
  temperature,
  humidity,
  waterLevel,
  ph,
  electricalConductivity,
  lightIntensity,
  pressure,
}

/// Real-time sensor reading
@freezed
class SensorReading with _$SensorReading {
  const factory SensorReading({
    required String id,
    required SensorType type,
    required double value,
    required String unit,
    required DateTime timestamp,
    String? location,
    @Default(true) bool isOnline,
  }) = _SensorReading;

  factory SensorReading.fromJson(Map<String, dynamic> json) =>
      _$SensorReadingFromJson(json);
}

/// Historical sensor data point
@freezed
class SensorDataPoint with _$SensorDataPoint {
  const factory SensorDataPoint({
    required DateTime timestamp,
    required double value,
  }) = _SensorDataPoint;

  factory SensorDataPoint.fromJson(Map<String, dynamic> json) =>
      _$SensorDataPointFromJson(json);
}

/// Extensions for sensor types
extension SensorTypeExtensions on SensorType {
  String get displayName {
    switch (this) {
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.humidity:
        return 'Humidity';
      case SensorType.waterLevel:
        return 'Water Level';
      case SensorType.ph:
        return 'pH Level';
      case SensorType.electricalConductivity:
        return 'EC';
      case SensorType.lightIntensity:
        return 'Light';
      case SensorType.pressure:
        return 'Pressure';
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
      case SensorType.ph:
        return 'pH';
      case SensorType.electricalConductivity:
        return 'μS/cm';
      case SensorType.lightIntensity:
        return 'lux';
      case SensorType.pressure:
        return 'Pa';
    }
  }
}