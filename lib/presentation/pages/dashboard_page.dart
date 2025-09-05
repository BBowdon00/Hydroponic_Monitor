import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/sensor_tile.dart';
import '../../core/theme.dart';
import '../../domain/entities/sensor_data.dart';
import '../providers/sensor_aggregation_providers.dart';
import '../providers/device_control_providers.dart';
import '../providers/data_providers.dart';

/// Dashboard page showing overview of sensor data and system status.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    // Watch initialization status
    final dataInitialization = ref.watch(dataServicesInitializationProvider);
    final hasSensorData = ref.watch(hasSensorDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Connection status indicators
          IconButton(
            icon: Icon(
              hasSensorData ? Icons.wifi : Icons.wifi_off,
              color: hasSensorData ? Colors.green : Colors.orange,
            ),
            onPressed: () {
              // Show connection status dialog
              _showConnectionStatus(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Trigger data refresh
              ref.invalidate(dataServicesInitializationProvider);
            },
          ),
        ],
      ),
      body: dataInitialization.when(
        data: (_) => _buildDashboardContent(),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppTheme.spaceMd),
              Text('Initializing data services...'),
            ],
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: AppTheme.spaceMd),
              Text('Failed to initialize: $error'),
              const SizedBox(height: AppTheme.spaceMd),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(dataServicesInitializationProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data services
        ref.invalidate(dataServicesInitializationProvider);
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
                  _buildSensorGrid(crossAxisCount),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Device Control Section
                  Text(
                    'Device Control',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  _buildDeviceControls(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSensorGrid(int crossAxisCount) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: AppTheme.spaceMd,
      mainAxisSpacing: AppTheme.spaceMd,
      childAspectRatio: 1.5,
      children: [
        _buildSensorTile(
          SensorType.waterLevel,
          'Water Level',
          Icons.water_drop,
          Colors.blue,
        ),
        _buildSensorTile(
          SensorType.temperature,
          'Temperature',
          Icons.thermostat,
          Colors.orange,
        ),
        _buildSensorTile(
          SensorType.humidity,
          'Humidity',
          Icons.opacity,
          Colors.cyan,
        ),
        _buildSensorTile(
          SensorType.pH,
          'pH Level',
          Icons.science,
          Colors.green,
        ),
        _buildSensorTile(
          SensorType.electricalConductivity,
          'EC Level',
          Icons.electrical_services,
          Colors.purple,
        ),
        _buildSensorTile(
          SensorType.powerUsage,
          'Power Usage',
          Icons.bolt,
          Colors.yellow,
        ),
      ],
    );
  }

  Widget _buildSensorTile(
    SensorType sensorType,
    String title,
    IconData icon,
    Color color,
  ) {
    final sensorReading = ref.watch(latestSensorReadingProvider(sensorType));
    final hasSensorData = ref.watch(hasSensorDataProvider);

    if (!hasSensorData) {
      return SensorTile(
        title: title,
        value: 'Waiting...',
        unit: sensorType.defaultUnit,
        icon: icon,
        color: color.withValues(alpha: 0.5),
        trend: SensorTrend.stable,
      );
    }

    if (sensorReading == null) {
      return SensorTile(
        title: title,
        value: 'No Data',
        unit: sensorType.defaultUnit,
        icon: icon,
        color: Colors.grey,
        trend: SensorTrend.stable,
      );
    }

    // Format value based on sensor type
    String formattedValue;
    switch (sensorType) {
      case SensorType.temperature:
        formattedValue = '${sensorReading.value.toStringAsFixed(1)}°C';
        break;
      case SensorType.humidity:
        formattedValue = '${sensorReading.value.toStringAsFixed(0)}%';
        break;
      case SensorType.pH:
        formattedValue = sensorReading.value.toStringAsFixed(2);
        break;
      case SensorType.powerUsage:
        if (sensorReading.value > 1000) {
          formattedValue =
              '${(sensorReading.value / 1000).toStringAsFixed(2)} kW';
        } else {
          formattedValue = '${sensorReading.value.toStringAsFixed(1)} W';
        }
        break;
      default:
        formattedValue = sensorReading.value.toStringAsFixed(1);
    }

    return SensorTile(
      title: title,
      value: formattedValue,
      unit: sensorReading.unit,
      icon: icon,
      color: color,
      trend: _calculateTrend(sensorType, sensorReading.value),
    );
  }

  SensorTrend _calculateTrend(SensorType sensorType, double value) {
    // Simple trend calculation - in a real implementation, this would compare
    // with previous values to determine actual trend
    switch (sensorType) {
      case SensorType.temperature:
        if (value > 26) return SensorTrend.up;
        if (value < 20) return SensorTrend.down;
        return SensorTrend.stable;
      case SensorType.pH:
        if (value > 7.0) return SensorTrend.up;
        if (value < 6.0) return SensorTrend.down;
        return SensorTrend.stable;
      default:
        return SensorTrend.stable;
    }
  }

  Widget _buildDeviceControls() {
    final pumpState = ref.watch(pumpControlProvider);
    final fan1State = ref.watch(fan1ControlProvider);
    final fan2State = ref.watch(fan2ControlProvider);
    final lightState = ref.watch(lightControlProvider);

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
              isEnabled: pumpState.isEnabled,
              isPending: pumpState.isPending,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(pumpState.deviceId, enabled);
              },
            ),
            _buildSimpleDeviceCard(
              context,
              title: 'Fan 1',
              icon: Icons.air,
              color: Colors.cyan,
              isEnabled: fan1State.isEnabled,
              isPending: fan1State.isPending,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(fan1State.deviceId, enabled);
              },
            ),
            _buildSimpleDeviceCard(
              context,
              title: 'Fan 2',
              icon: Icons.air,
              color: Colors.teal,
              isEnabled: fan2State.isEnabled,
              isPending: fan2State.isPending,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(fan2State.deviceId, enabled);
              },
            ),
            _buildSimpleDeviceCard(
              context,
              title: 'LED Lights',
              icon: Icons.wb_sunny,
              color: Colors.amber,
              isEnabled: lightState.isEnabled,
              isPending: lightState.isPending,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(lightState.deviceId, enabled);
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

  void _showConnectionStatus(BuildContext context) {
    final mqttConnection = ref.read(mqttConnectionStatusProvider);
    final influxConnection = ref.read(influxConnectionStatusProvider);
    final hasSensorData = ref.watch(hasSensorDataProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionRow(
              'MQTT',
              mqttConnection.asData?.value ?? 'unknown',
            ),
            _buildConnectionRow(
              'InfluxDB',
              influxConnection.asData?.value ?? 'unknown',
            ),
            _buildConnectionRow(
              'Sensor Data',
              hasSensorData ? 'receiving' : 'waiting',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionRow(String service, String status) {
    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'connected':
      case 'receiving':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'disconnected':
      case 'waiting':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text('$service: '),
          Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
