import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../domain/entities/sensor_data.dart';
import '../../presentation/pages/charts_page.dart';
import '../../presentation/providers/chart_providers.dart';

/// Card widget displaying a chart for a specific sensor type.
class SensorChartCard extends ConsumerWidget {
  const SensorChartCard({
    required this.sensorType,
    required this.range,
    super.key,
  });

  final SensorType sensorType;
  final ChartRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartDataAsync = ref.watch(
      sensorChartDataProvider((sensorType: sensorType, range: range)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon, label, and fallback badge
            _buildHeader(context, chartDataAsync),
            const SizedBox(height: AppTheme.spaceMd),

            // Chart area
            SizedBox(
              height: 200,
              child: chartDataAsync.when(
                data: (chartState) => _buildChart(context, chartState),
                loading: () => _buildLoadingSkeleton(context),
                error: (error, stack) => _buildError(context, ref, error),
              ),
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // Footer with stats
            chartDataAsync.when(
              data: (chartState) => _buildStats(context, chartState),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue chartDataAsync) {
    final theme = Theme.of(context);
    final isFallback = chartDataAsync.valueOrNull?.isFallback ?? false;

    return Row(
      children: [
        Icon(
          _getSensorIcon(),
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: Text(
            sensorType.displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (isFallback)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              'Simulated',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, ChartSeriesState chartState) {
    final theme = Theme.of(context);

    if (chartState.points.isEmpty) {
      return _buildEmptyState(context);
    }

    // Convert time series points to chart data
    final spots = chartState.points
        .asMap()
        .entries
        .map(
          (entry) => FlSpot(
            entry.key.toDouble(),
            entry.value.value,
          ),
        )
        .toList();

    // Calculate Y-axis bounds with 5% padding
    final minY = chartState.stats.min;
    final maxY = chartState.stats.max;
    final padding = (maxY - minY) * 0.05;
    final yMin = ((minY - padding).clamp(0, double.infinity)).toDouble();
    final yMax = (maxY + padding).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (yMax - yMin) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: spots.isEmpty ? 1 : (spots.length / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= chartState.points.length) {
                  return const SizedBox.shrink();
                }
                final point = chartState.points[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _formatTimestamp(point.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        minX: 0,
        maxX: spots.isEmpty ? 1.0 : (spots.length - 1).toDouble(),
        minY: yMin,
        maxY: yMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: theme.colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= chartState.points.length) {
                  return null;
                }
                final point = chartState.points[index];
                return LineTooltipItem(
                  '${point.value.toStringAsFixed(1)} ${sensorType.defaultUnit}\n${_formatTimestamp(point.timestamp)}',
                  theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Loading chart data...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'No data available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Failed to load chart',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          FilledButton.tonal(
            onPressed: () {
              // Invalidate this specific provider
              ref.invalidate(
                sensorChartDataProvider(
                  (sensorType: sensorType, range: range),
                ),
              );
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, ChartSeriesState chartState) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          context,
          label: 'Min',
          value:
              '${chartState.stats.min.toStringAsFixed(1)} ${sensorType.defaultUnit}',
        ),
        _buildStatItem(
          context,
          label: 'Avg',
          value:
              '${chartState.stats.average.toStringAsFixed(1)} ${sensorType.defaultUnit}',
        ),
        _buildStatItem(
          context,
          label: 'Max',
          value:
              '${chartState.stats.max.toStringAsFixed(1)} ${sensorType.defaultUnit}',
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  IconData _getSensorIcon() {
    switch (sensorType) {
      case SensorType.temperature:
        return Icons.thermostat;
      case SensorType.humidity:
        return Icons.water_drop;
      case SensorType.waterLevel:
        return Icons.waves;
      case SensorType.pH:
        return Icons.science;
      case SensorType.electricalConductivity:
        return Icons.electrical_services;
      case SensorType.lightIntensity:
        return Icons.light_mode;
      case SensorType.airQuality:
        return Icons.air;
      case SensorType.powerUsage:
        return Icons.power;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    // Format based on range
    switch (range) {
      case ChartRange.hour1:
        return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      case ChartRange.hours24:
        return '${timestamp.hour.toString().padLeft(2, '0')}:00';
      case ChartRange.days7:
      case ChartRange.days30:
        return '${timestamp.month}/${timestamp.day}';
    }
  }
}
