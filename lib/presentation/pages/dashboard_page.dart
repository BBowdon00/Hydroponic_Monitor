import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';
import 'dart:math';

import '../widgets/sensor_tile.dart';
import '../../core/theme.dart';

/// Dashboard page showing overview of sensor data and system status.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Start mock data updates
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      ref.read(mockSensorDataProvider.notifier).updateValues();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensorData = ref.watch(mockSensorDataProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(mockSensorDataProvider.notifier).updateValues();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(mockSensorDataProvider.notifier).updateValues();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: AppTheme.spaceMd,
            mainAxisSpacing: AppTheme.spaceMd,
            childAspectRatio: 1.2,
            children: [
              SensorTile(
                title: 'Water Level',
                value: '${sensorData.waterLevel.toStringAsFixed(1)} cm',
                unit: 'cm',
                icon: Icons.water_drop,
                color: Colors.blue,
                trend: sensorData.waterLevelTrend,
              ),
              SensorTile(
                title: 'Temperature',
                value: '${sensorData.temperature.toStringAsFixed(1)}°C',
                unit: '°C',
                icon: Icons.thermostat,
                color: Colors.orange,
                trend: sensorData.temperatureTrend,
              ),
              SensorTile(
                title: 'Humidity',
                value: '${sensorData.humidity.toStringAsFixed(0)}%',
                unit: '%',
                icon: Icons.opacity,
                color: Colors.cyan,
                trend: sensorData.humidityTrend,
              ),
              SensorTile(
                title: 'pH Level',
                value: sensorData.pH.toStringAsFixed(2),
                unit: 'pH',
                icon: Icons.science,
                color: Colors.green,
                trend: sensorData.pHTrend,
              ),
              SensorTile(
                title: 'EC Level',
                value: '${sensorData.electricalConductivity.toStringAsFixed(1)} mS/cm',
                unit: 'mS/cm',
                icon: Icons.electrical_services,
                color: Colors.purple,
                trend: sensorData.ecTrend,
              ),
              SensorTile(
                title: 'Light Level',
                value: '${sensorData.lightLevel.toStringAsFixed(0)} lux',
                unit: 'lux',
                icon: Icons.wb_sunny,
                color: Colors.amber,
                trend: sensorData.lightTrend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mock sensor data for demonstration.
class SensorData {
  const SensorData({
    required this.waterLevel,
    required this.temperature,
    required this.humidity,
    required this.pH,
    required this.electricalConductivity,
    required this.lightLevel,
    required this.waterLevelTrend,
    required this.temperatureTrend,
    required this.humidityTrend,
    required this.pHTrend,
    required this.ecTrend,
    required this.lightTrend,
  });

  final double waterLevel;
  final double temperature;
  final double humidity;
  final double pH;
  final double electricalConductivity;
  final double lightLevel;
  final SensorTrend waterLevelTrend;
  final SensorTrend temperatureTrend;
  final SensorTrend humidityTrend;
  final SensorTrend pHTrend;
  final SensorTrend ecTrend;
  final SensorTrend lightTrend;
}

/// Provider for mock sensor data with live updates.
final mockSensorDataProvider = StateNotifierProvider<MockSensorDataNotifier, SensorData>((ref) {
  return MockSensorDataNotifier();
});

class MockSensorDataNotifier extends StateNotifier<SensorData> {
  MockSensorDataNotifier() : super(_generateInitialData());

  static final Random _random = Random();

  static SensorData _generateInitialData() {
    return SensorData(
      waterLevel: 15.0 + _random.nextDouble() * 5.0,
      temperature: 22.0 + _random.nextDouble() * 6.0,
      humidity: 65.0 + _random.nextDouble() * 10.0,
      pH: 6.0 + _random.nextDouble() * 2.0,
      electricalConductivity: 1.2 + _random.nextDouble() * 0.8,
      lightLevel: 800.0 + _random.nextDouble() * 400.0,
      waterLevelTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      temperatureTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      humidityTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      pHTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      ecTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      lightTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
    );
  }

  void updateValues() {
    // Simulate realistic sensor value changes
    state = SensorData(
      waterLevel: _updateValue(state.waterLevel, 10.0, 25.0, 0.2),
      temperature: _updateValue(state.temperature, 18.0, 30.0, 0.3),
      humidity: _updateValue(state.humidity, 40.0, 90.0, 1.0),
      pH: _updateValue(state.pH, 5.5, 8.0, 0.05),
      electricalConductivity: _updateValue(state.electricalConductivity, 0.8, 2.5, 0.02),
      lightLevel: _updateValue(state.lightLevel, 200.0, 1500.0, 10.0),
      waterLevelTrend: _updateTrend(state.waterLevelTrend),
      temperatureTrend: _updateTrend(state.temperatureTrend),
      humidityTrend: _updateTrend(state.humidityTrend),
      pHTrend: _updateTrend(state.pHTrend),
      ecTrend: _updateTrend(state.ecTrend),
      lightTrend: _updateTrend(state.lightTrend),
    );
  }

  double _updateValue(double current, double min, double max, double maxChange) {
    final change = (_random.nextDouble() - 0.5) * 2 * maxChange;
    final newValue = current + change;
    return newValue.clamp(min, max);
  }

  SensorTrend _updateTrend(SensorTrend current) {
    // 70% chance to keep the same trend, 30% chance to change
    if (_random.nextDouble() < 0.7) {
      return current;
    }
    return SensorTrend.values[_random.nextInt(SensorTrend.values.length)];
  }
}