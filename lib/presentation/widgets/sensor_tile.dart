import 'package:flutter/material.dart';
import 'package:hydroponic_monitor/core/theme.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

/// Reusable sensor tile widget for dashboard
class SensorTile extends StatelessWidget {
  const SensorTile({
    super.key,
    required this.sensorReading,
    this.onTap,
    this.showSparkline = false,
    this.sparklineData = const [],
  });

  final SensorReading sensorReading;
  final VoidCallback? onTap;
  final bool showSparkline;
  final List<double> sparklineData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with sensor type and status
              Row(
                children: [
                  Icon(
                    _getIconForSensorType(sensorReading.type),
                    size: 20,
                    color: sensorReading.isOnline
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      sensorReading.type.displayName,
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusIndicator(isOnline: sensorReading.isOnline),
                ],
              ),
              
              const SizedBox(height: AppTheme.space12),
              
              // Value and unit
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatValue(sensorReading.value),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: sensorReading.isOnline
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Text(
                    sensorReading.unit,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              
              if (showSparkline && sparklineData.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space8),
                SizedBox(
                  height: 40,
                  child: _SparklineChart(data: sparklineData),
                ),
              ],
              
              const SizedBox(height: AppTheme.space8),
              
              // Location and timestamp
              if (sensorReading.location != null)
                Text(
                  sensorReading.location!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                _formatTimestamp(sensorReading.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSensorType(SensorType type) {
    switch (type) {
      case SensorType.temperature:
        return Icons.thermostat;
      case SensorType.humidity:
        return Icons.water_drop;
      case SensorType.waterLevel:
        return Icons.waves;
      case SensorType.ph:
        return Icons.science;
      case SensorType.electricalConductivity:
        return Icons.electrical_services;
      case SensorType.lightIntensity:
        return Icons.wb_sunny;
      case SensorType.pressure:
        return Icons.compress;
    }
  }

  String _formatValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Status indicator dot
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.isOnline});
  
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? colorScheme.primary : colorScheme.error,
      ),
    );
  }
}

/// Simple sparkline chart placeholder
class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.data});
  
  final List<double> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Center(
        child: Text(
          'Trend Chart',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}