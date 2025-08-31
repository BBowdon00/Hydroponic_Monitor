import 'package:flutter/material.dart';
import '../widgets/status_badge.dart';
import '../../core/theme.dart';

/// A card for controlling individual devices.
/// Includes toggle switch, optional intensity slider, and pending state indicator.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isEnabled,
    required this.isPending,
    required this.onToggle,
    this.intensity,
    this.onIntensityChanged,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final bool isPending;
  final void Function(bool enabled) onToggle;
  final double? intensity;
  final ValueChanged<double>? onIntensityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with icon, title, and toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPending)
                  const SizedBox(
                    width: 20,
                    height: 20,
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

            // Intensity slider (if applicable)
            if (intensity != null && onIntensityChanged != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Row(
                children: [
                  Text('Intensity', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Slider(
                      value: intensity!,
                      onChanged: isEnabled && !isPending
                          ? onIntensityChanged
                          : null,
                      activeColor: color,
                      divisions: 10,
                      label: '${(intensity! * 100).round()}%',
                    ),
                  ),
                  Text(
                    '${(intensity! * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            // Status indicator
            const SizedBox(height: AppTheme.spaceSm),
            StatusBadge(label: _getStatusLabel(), status: _getDeviceStatus()),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel() {
    if (isPending) return 'Updating...';
    if (isEnabled) return 'Online';
    return 'Offline';
  }

  DeviceStatus _getDeviceStatus() {
    if (isPending) return DeviceStatus.pending;
    if (isEnabled) return DeviceStatus.online;
    return DeviceStatus.offline;
  }
}
