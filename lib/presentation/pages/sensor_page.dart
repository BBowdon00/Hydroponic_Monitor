import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/sensor_tile.dart';
import '../../core/theme.dart';
import '../../domain/entities/sensor_data.dart';
import '../providers/data_providers.dart';
import '../providers/connection_status_provider.dart';
import '../providers/sensor_providers.dart';

/// Sensor page showing overview of sensor data and system status.
class SensorPage extends ConsumerStatefulWidget {
  const SensorPage({super.key});

  @override
  ConsumerState<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends ConsumerState<SensorPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor')),
      body: _buildSensorContent(),
    );
  }

  Widget _buildSensorContent() {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data services
        ref.invalidate(realTimeSensorDataProvider);
        ref.invalidate(realTimeSensorDataByTypeProvider);
        ref.invalidate(latestSensorReadingsProvider);
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
    // Try to get real-time data first, fall back to historical data
    final realTimeData = ref.watch(latestSensorDataProvider(sensorType));
    final historicalDataAsync = ref.watch(
      historicalLatestSensorDataProvider(sensorType),
    );
    final hasSensorData = ref.watch(hasSensorDataProvider);

    // Determine which data to use
    final sensorData = realTimeData ?? historicalDataAsync.asData?.value;

    if (!hasSensorData && sensorData == null) {
      return SensorTile(
        title: title,
        value: 'Waiting...',
        unit: sensorType.defaultUnit,
        icon: icon,
        color: color.withValues(alpha: 0.5),
        trend: SensorTrend.stable,
      );
    }

    if (sensorData == null) {
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
        formattedValue = '${sensorData.value.toStringAsFixed(1)}°C';
        break;
      case SensorType.humidity:
        formattedValue = '${sensorData.value.toStringAsFixed(0)}%';
        break;
      case SensorType.pH:
        formattedValue = sensorData.value.toStringAsFixed(2);
        break;
      case SensorType.powerUsage:
        if (sensorData.value > 1000) {
          formattedValue = '${(sensorData.value / 1000).toStringAsFixed(2)} kW';
        } else {
          formattedValue = '${sensorData.value.toStringAsFixed(1)} W';
        }
        break;
      default:
        formattedValue = sensorData.value.toStringAsFixed(1);
    }

    return SensorTile(
      title: title,
      value: formattedValue,
      unit: sensorData.unit,
      icon: icon,
      color: color,
      trend: _calculateTrend(sensorType, sensorData.value),
      // Coarsen timestamp so stale notifier only changes:
      // - in whole minute increments while < 60 minutes old
      // - in whole hour increments once >= 60 minutes old
      lastUpdated: _coarsenTimestamp(sensorData.timestamp),
    );
  }

  DateTime _coarsenTimestamp(DateTime ts) {
    final now = DateTime.now();
    final age = now.difference(ts);
    if (age.inMinutes < 60) {
      return DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute);
    }
    return DateTime(ts.year, ts.month, ts.day, ts.hour);
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

  void _showConnectionStatus(BuildContext context) {
    final connectionStatusAsync = ref.watch(connectionStatusProvider);
    final hasSensorData = ref.watch(hasSensorDataProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            connectionStatusAsync.when(
              data: (connectionStatus) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionRow(
                    'InfluxDB',
                    connectionStatus.influxConnected ? 'connected' : 'error',
                  ),
                  _buildConnectionRow(
                    'MQTT',
                    connectionStatus.mqttConnected ? 'connected' : 'error',
                  ),
                ],
              ),
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionRow('MQTT', 'loading'),
                  _buildConnectionRow('InfluxDB', 'loading'),
                ],
              ),
              error: (error, stack) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionRow('MQTT', 'error'),
                  _buildConnectionRow('InfluxDB', 'error'),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildConnectionRow(
              'Sensor Data',
              hasSensorData ? 'available' : 'no data',
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

    switch (status) {
      case 'connected':
      case 'available':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'connecting':
      case 'loading':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'error':
      case 'no data':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: AppTheme.spaceSm),
          Text('$service: '),
          Text(
            status.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
          ),
        ],
      ),
    );
  }
}
