import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Sensor trend indicator.
enum SensorTrend { up, down, stable }

/// A card displaying sensor data with value, trend, and sparkline placeholder.
/// Follows Material 3 design principles with consistent spacing.
class SensorTile extends StatelessWidget {
  const SensorTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.trend,
    this.lastUpdated,
    super.key,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final SensorTrend trend;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildTrendIcon(),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),

            // Main value
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),

            // Stale data indicator
            if (_isDataStale()) ...[
              const SizedBox(height: AppTheme.spaceXs),
              _buildStaleIndicator(theme),
            ],

            const SizedBox(height: AppTheme.spaceSm),

            // Sparkline placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart,
                        color: color.withValues(alpha: 0.5),
                        size: 16,
                      ),
                      const SizedBox(width: AppTheme.spaceXs),
                      Text(
                        'Chart',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIcon() {
    IconData iconData;
    Color iconColor;

    switch (trend) {
      case SensorTrend.up:
        iconData = Icons.trending_up;
        iconColor = Colors.green;
        break;
      case SensorTrend.down:
        iconData = Icons.trending_down;
        iconColor = Colors.red;
        break;
      case SensorTrend.stable:
        iconData = Icons.trending_flat;
        iconColor = Colors.grey;
        break;
    }

    return Icon(iconData, color: iconColor, size: 16);
  }

  /// Checks if sensor data is considered stale (older than 60 seconds).
  bool _isDataStale() {
    if (lastUpdated == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastUpdated!);
    return difference.inSeconds > 60;
  }

  /// Builds the stale data indicator widget.
  Widget _buildStaleIndicator(ThemeData theme) {
    if (lastUpdated == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final difference = now.difference(lastUpdated!);
    final elapsedTime = _formatElapsedTime(difference);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.orange.shade700),
          const SizedBox(width: 2),
          Text(
            'Stale ($elapsedTime)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats elapsed time for display in coarse increments:
  /// < 60 minutes -> Xm ago
  /// >= 60 minutes -> Xh ago
  String _formatElapsedTime(Duration difference) {
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    return '${difference.inHours}h ago';
  }
}
