import 'dart:async';
import 'dart:math';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

/// Mock sensor data provider with live updates
final sensorDataProvider = StreamProvider.autoDispose<List<SensorReading>>((ref) {
  late Timer timer;
  late StreamController<List<SensorReading>> controller;
  final random = Random();

  // Mock sensor configurations
  final sensors = [
    (type: SensorType.temperature, baseValue: 22.0, variance: 3.0),
    (type: SensorType.humidity, baseValue: 65.0, variance: 10.0),
    (type: SensorType.waterLevel, baseValue: 45.0, variance: 5.0),
    (type: SensorType.ph, baseValue: 6.2, variance: 0.5),
    (type: SensorType.electricalConductivity, baseValue: 1200.0, variance: 200.0),
    (type: SensorType.lightIntensity, baseValue: 25000.0, variance: 5000.0),
  ];

  controller = StreamController<List<SensorReading>>();

  void generateData() {
    final readings = sensors.map((sensor) {
      final variance = (random.nextDouble() - 0.5) * 2 * sensor.variance;
      final value = (sensor.baseValue + variance).clamp(0.0, double.infinity);
      
      return SensorReading(
        id: 'sensor_${sensor.type.name}',
        type: sensor.type,
        value: value,
        unit: sensor.type.defaultUnit,
        timestamp: DateTime.now(),
        location: _getLocationForSensor(sensor.type),
        isOnline: random.nextDouble() > 0.05, // 95% uptime
      );
    }).toList();

    controller.add(readings);
  }

  // Generate initial data and start timer
  generateData();
  timer = Timer.periodic(const Duration(seconds: 2), (_) => generateData());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provider for historical sensor data (mock sparkline data)
final sensorHistoryProvider = Provider.family<List<double>, SensorType>((ref, sensorType) {
  final random = Random();
  final baseValue = _getBaseValueForSensor(sensorType);
  final variance = _getVarianceForSensor(sensorType);
  
  // Generate 20 historical points
  return List.generate(20, (index) {
    final variation = (random.nextDouble() - 0.5) * 2 * variance;
    return (baseValue + variation).clamp(0.0, double.infinity);
  });
});

String _getLocationForSensor(SensorType type) {
  switch (type) {
    case SensorType.temperature:
    case SensorType.humidity:
      return 'Greenhouse A';
    case SensorType.waterLevel:
    case SensorType.ph:
    case SensorType.electricalConductivity:
      return 'Reservoir 1';
    case SensorType.lightIntensity:
      return 'Growing Area';
    case SensorType.pressure:
      return 'System';
  }
}

double _getBaseValueForSensor(SensorType type) {
  switch (type) {
    case SensorType.temperature:
      return 22.0;
    case SensorType.humidity:
      return 65.0;
    case SensorType.waterLevel:
      return 45.0;
    case SensorType.ph:
      return 6.2;
    case SensorType.electricalConductivity:
      return 1200.0;
    case SensorType.lightIntensity:
      return 25000.0;
    case SensorType.pressure:
      return 101325.0;
  }
}

double _getVarianceForSensor(SensorType type) {
  switch (type) {
    case SensorType.temperature:
      return 3.0;
    case SensorType.humidity:
      return 10.0;
    case SensorType.waterLevel:
      return 5.0;
    case SensorType.ph:
      return 0.5;
    case SensorType.electricalConductivity:
      return 200.0;
    case SensorType.lightIntensity:
      return 5000.0;
    case SensorType.pressure:
      return 1000.0;
  }
}