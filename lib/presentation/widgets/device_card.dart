import 'package:flutter/material.dart';
import 'package:hydroponic_monitor/core/theme.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';

/// Reusable device card widget for device controls
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    this.onToggle,
    this.onIntensityChanged,
    this.isPending = false,
  });

  final Device device;
  final VoidCallback? onToggle;
  final ValueChanged<double>? onIntensityChanged;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with device info and status
            Row(
              children: [
                Icon(
                  _getIconForDeviceType(device.type),
                  size: 24,
                  color: _getStatusColor(device.status, colorScheme),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        device.type.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  status: device.status,
                  isOn: device.isOn,
                ),
              ],
            ),
            
            if (device.location != null) ...[
              const SizedBox(height: AppTheme.space8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Text(
                    device.location!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: AppTheme.space16),
            
            // Controls
            Row(
              children: [
                // Power toggle
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: device.isControllable && !isPending
                        ? onToggle
                        : null,
                    icon: isPending
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Icon(device.isOn ? Icons.power_off : Icons.power),
                    label: Text(device.isOn ? 'Turn Off' : 'Turn On'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: device.isOn
                          ? colorScheme.secondary
                          : colorScheme.primary,
                      foregroundColor: device.isOn
                          ? colorScheme.onSecondary
                          : colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            
            // Intensity control
            if (device.type.hasIntensityControl && device.isOn) ...[
              const SizedBox(height: AppTheme.space16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Intensity',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        '${(device.intensity * 100).round()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Slider(
                    value: device.intensity,
                    onChanged: device.isControllable && !isPending
                        ? onIntensityChanged
                        : null,
                    divisions: 10,
                    label: '${(device.intensity * 100).round()}%',
                  ),
                ],
              ),
            ],
            
            // Last update timestamp
            if (device.lastUpdate != null) ...[
              const SizedBox(height: AppTheme.space8),
              Text(
                'Last update: ${_formatTimestamp(device.lastUpdate!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForDeviceType(DeviceType type) {
    switch (type) {
      case DeviceType.pump:
        return Icons.water_drop;
      case DeviceType.fan:
        return Icons.air;
      case DeviceType.light:
        return Icons.lightbulb;
      case DeviceType.heater:
        return Icons.heat_pump;
      case DeviceType.valve:
        return Icons.valve;
    }
  }

  Color _getStatusColor(DeviceStatus status, ColorScheme colorScheme) {
    switch (status) {
      case DeviceStatus.online:
        return colorScheme.primary;
      case DeviceStatus.offline:
        return colorScheme.onSurfaceVariant;
      case DeviceStatus.error:
        return colorScheme.error;
      case DeviceStatus.maintenance:
        return colorScheme.tertiary;
    }
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