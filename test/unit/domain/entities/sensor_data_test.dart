import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

void main() {
  group('SensorReading', () {
    test('should create sensor reading with all required fields', () {
      // Arrange
      final timestamp = DateTime.now();
      
      // Act
      final reading = SensorReading(
        id: 'temp_01',
        type: SensorType.temperature,
        value: 23.5,
        unit: '°C',
        timestamp: timestamp,
        location: 'Greenhouse A',
      );
      
      // Assert
      expect(reading.id, 'temp_01');
      expect(reading.type, SensorType.temperature);
      expect(reading.value, 23.5);
      expect(reading.unit, '°C');
      expect(reading.timestamp, timestamp);
      expect(reading.location, 'Greenhouse A');
      expect(reading.isOnline, true); // Default value
    });

    test('should handle offline sensor status', () {
      // Arrange & Act
      final reading = SensorReading(
        id: 'temp_01',
        type: SensorType.temperature,
        value: 0.0,
        unit: '°C',
        timestamp: DateTime.now(),
        isOnline: false,
      );
      
      // Assert
      expect(reading.isOnline, false);
    });
  });

  group('SensorType extensions', () {
    test('should return correct display names', () {
      expect(SensorType.temperature.displayName, 'Temperature');
      expect(SensorType.humidity.displayName, 'Humidity');
      expect(SensorType.waterLevel.displayName, 'Water Level');
      expect(SensorType.ph.displayName, 'pH Level');
      expect(SensorType.electricalConductivity.displayName, 'EC');
      expect(SensorType.lightIntensity.displayName, 'Light');
      expect(SensorType.pressure.displayName, 'Pressure');
    });

    test('should return correct default units', () {
      expect(SensorType.temperature.defaultUnit, '°C');
      expect(SensorType.humidity.defaultUnit, '%');
      expect(SensorType.waterLevel.defaultUnit, 'cm');
      expect(SensorType.ph.defaultUnit, 'pH');
      expect(SensorType.electricalConductivity.defaultUnit, 'μS/cm');
      expect(SensorType.lightIntensity.defaultUnit, 'lux');
      expect(SensorType.pressure.defaultUnit, 'Pa');
    });
  });

  group('SensorDataPoint', () {
    test('should create data point with timestamp and value', () {
      // Arrange
      final timestamp = DateTime.now();
      
      // Act
      final dataPoint = SensorDataPoint(
        timestamp: timestamp,
        value: 25.0,
      );
      
      // Assert
      expect(dataPoint.timestamp, timestamp);
      expect(dataPoint.value, 25.0);
    });
  });
}