import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';
import 'dart:math';

import '../widgets/sensor_tile.dart';
import '../../core/theme.dart';
import 'devices_page.dart';

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive grid: more columns on wider screens
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                  ? 3
                  : 2;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sensor Status Section
                    Text(
                      'Sensor Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppTheme.spaceMd,
                      mainAxisSpacing: AppTheme.spaceMd,
                      childAspectRatio: 1.5, // Smaller tiles
                      children: [
                        SensorTile(
                          title: 'Water Level',
                          value:
                              '${sensorData.waterLevel.toStringAsFixed(1)} cm',
                          unit: 'cm',
                          icon: Icons.water_drop,
                          color: Colors.blue,
                          trend: sensorData.waterLevelTrend,
                        ),
                        SensorTile(
                          title: 'Temperature',
                          value:
                              '${sensorData.temperature.toStringAsFixed(1)}°C',
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
                          value: 'N/A',
                          unit: 'mS/cm',
                          icon: Icons.electrical_services,
                          color: Colors.purple,
                          trend: sensorData.ecTrend,
                        ),
                        SensorTile(
                          title: 'Power Usage',
                          value: sensorData.powerUsage > 1000 
                              ? '${(sensorData.powerUsage / 1000).toStringAsFixed(2)} kW'
                              : '${sensorData.powerUsage.toStringAsFixed(1)} W',
                          unit: sensorData.powerUsage > 1000 ? 'kW' : 'W',
                          icon: Icons.bolt,
                          color: Colors.yellow,
                          trend: sensorData.powerTrend,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spaceLg),

                    // Device Control Section
                    Text(
                      'Device Control',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    _buildDeviceControls(ref),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceControls(WidgetRef ref) {
    final deviceStates = ref.watch(deviceStatesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppTheme.spaceMd,
          mainAxisSpacing: AppTheme.spaceMd,
          childAspectRatio: 2.5,
          children: [
            _buildSimpleDeviceCard(
              context,
              title: 'Water Pump',
              icon: Icons.water_drop,
              color: Colors.blue,
              isEnabled: deviceStates.pumpEnabled,
              isPending: deviceStates.pumpPending,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).togglePump(enabled);
              },
            ),
            _buildSimpleDeviceCard(
              context,
              title: 'Fan 1',
              icon: Icons.air,
              color: Colors.cyan,
              isEnabled: deviceStates.fansEnabled,
              isPending: deviceStates.fansPending,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).toggleFans(enabled);
              },
            ),
            _buildSimpleDeviceCard(
              context,
              title: 'Fan 2',
              icon: Icons.air,
              color: Colors.teal,
              isEnabled: deviceStates.fansEnabled, // Using same state for now
              isPending: deviceStates.fansPending,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).toggleFans(enabled);
              },
            ),
            _buildSimpleDeviceCard(
              context,
              title: 'LED Lights',
              icon: Icons.wb_sunny,
              color: Colors.amber,
              isEnabled: deviceStates.lightsEnabled,
              isPending: deviceStates.lightsPending,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).toggleLights(enabled);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimpleDeviceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required bool isEnabled,
    required bool isPending,
    required void Function(bool) onToggle,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceSm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceXs),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPending)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: isEnabled,
                    onChanged: isPending ? null : onToggle,
                    activeThumbColor: color,
                  ),
              ],
            ),
          ],
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
    required this.powerUsage,
    required this.waterLevelTrend,
    required this.temperatureTrend,
    required this.humidityTrend,
    required this.pHTrend,
    required this.ecTrend,
    required this.powerTrend,
  });

  final double waterLevel;
  final double temperature;
  final double humidity;
  final double pH;
  final double electricalConductivity;
  final double powerUsage;
  final SensorTrend waterLevelTrend;
  final SensorTrend temperatureTrend;
  final SensorTrend humidityTrend;
  final SensorTrend pHTrend;
  final SensorTrend ecTrend;
  final SensorTrend powerTrend;
}

/// Provider for mock sensor data with live updates.
final mockSensorDataProvider =
    StateNotifierProvider<MockSensorDataNotifier, SensorData>((ref) {
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
      powerUsage: 50.0 + _random.nextDouble() * 150.0, // 50-200 Watts
      waterLevelTrend:
          SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      temperatureTrend:
          SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      humidityTrend:
          SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      pHTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      ecTrend: SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
      powerTrend:
          SensorTrend.values[_random.nextInt(SensorTrend.values.length)],
    );
  }

  void updateValues() {
    // Simulate realistic sensor value changes
    state = SensorData(
      waterLevel: _updateValue(state.waterLevel, 10.0, 25.0, 0.2),
      temperature: _updateValue(state.temperature, 18.0, 30.0, 0.3),
      humidity: _updateValue(state.humidity, 40.0, 90.0, 1.0),
      pH: _updateValue(state.pH, 5.5, 8.0, 0.05),
      electricalConductivity: _updateValue(
        state.electricalConductivity,
        0.8,
        2.5,
        0.02,
      ),
      powerUsage: _updateValue(state.powerUsage, 30.0, 250.0, 5.0), // 30-250 Watts
      waterLevelTrend: _updateTrend(state.waterLevelTrend),
      temperatureTrend: _updateTrend(state.temperatureTrend),
      humidityTrend: _updateTrend(state.humidityTrend),
      pHTrend: _updateTrend(state.pHTrend),
      ecTrend: _updateTrend(state.ecTrend),
      powerTrend: _updateTrend(state.powerTrend),
    );
  }

  double _updateValue(
    double current,
    double min,
    double max,
    double maxChange,
  ) {
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
