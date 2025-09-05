import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../domain/entities/device.dart';

/// A badge showing device or system status with appropriate color coding.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.status,
    this.showIcon = true,
    super.key,
  });

  final String label;
  final DeviceStatus status;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusConfig = _getStatusConfig();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: statusConfig.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: statusConfig.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(statusConfig.icon, size: 14, color: statusConfig.color),
            const SizedBox(width: AppTheme.spaceXs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusConfig.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case DeviceStatus.online:
        return const _StatusConfig(
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case DeviceStatus.offline:
        return const _StatusConfig(
          color: Colors.grey,
          icon: Icons.radio_button_unchecked,
        );
      case DeviceStatus.pending:
        return const _StatusConfig(
          color: Colors.orange,
          icon: Icons.hourglass_empty,
        );
      case DeviceStatus.error:
        return const _StatusConfig(color: Colors.red, icon: Icons.error);
      case DeviceStatus.stopped:
        return const _StatusConfig(color: Colors.red, icon: Icons.stop_circle);
    }
  }
}

class _StatusConfig {
  const _StatusConfig({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
