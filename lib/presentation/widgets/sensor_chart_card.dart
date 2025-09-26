import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/time_series_point.dart';
import '../pages/charts_page.dart';
import '../providers/sensor_providers.dart';

/// Widget that displays a chart for a specific sensor type.
class SensorChartCard extends ConsumerWidget {
  const SensorChartCard({
    super.key,
    required this.sensorType,
    required this.range,
  });

  final SensorType sensorType;
  final ChartRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartDataAsync = ref.watch(
      chartDataProvider((sensorType: sensorType, range: range)),
    );
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme),
            const SizedBox(height: AppTheme.spaceMd),
            SizedBox(
              height: 200,
              child: chartDataAsync.when(
                data: (chartData) => _buildChart(context, chartData),
                loading: () => _buildLoadingState(context),
                error: (error, stack) =>
                    _buildErrorState(context, error.toString()),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            chartDataAsync.when(
              data: (chartData) => _buildStats(context, theme, chartData.stats),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(
          _getSensorIcon(sensorType),
          size: 24,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Text(
          sensorType.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          _getRangeLabel(range),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, ChartDataState chartData) {
    if (chartData.points.isEmpty) {
      return _buildEmptyState(context);
    }

    return LineChart(_buildLineChartData(context, chartData.points));
  }

  LineChartData _buildLineChartData(
    BuildContext context,
    List<TimeSeriesPoint> points,
  ) {
    final theme = Theme.of(context);
    final spots = points.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: math.max(points.length / 5, 1).toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= points.length) return const Text('');

              final timestamp = points[index].timestamp;
              return Text(
                _formatTimestamp(timestamp, range),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: null,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                _formatValue(value, sensorType),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.2),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(
    BuildContext context,
    ThemeData theme,
    TimeSeriesStats stats,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          context,
          theme,
          'Min',
          '${stats.min.toStringAsFixed(1)}${sensorType.defaultUnit}',
        ),
        _buildStatItem(
          context,
          theme,
          'Avg',
          '${stats.average.toStringAsFixed(1)}${sensorType.defaultUnit}',
        ),
        _buildStatItem(
          context,
          theme,
          'Max',
          '${stats.max.toStringAsFixed(1)}${sensorType.defaultUnit}',
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Loading chart data...',
            style: theme.textTheme.bodyMedium?.copyWith(
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
            Icons.analytics_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'No Data Available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 32, color: theme.colorScheme.error),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Failed to load chart',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSensorIcon(SensorType type) {
    switch (type) {
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
        return Icons.wb_sunny;
      case SensorType.airQuality:
        return Icons.air;
      case SensorType.powerUsage:
        return Icons.power;
    }
  }

  String _getRangeLabel(ChartRange range) {
    switch (range) {
      case ChartRange.hour1:
        return '1 Hour';
      case ChartRange.hours24:
        return '24 Hours';
      case ChartRange.days7:
        return '7 Days';
    }
  }

  String _formatTimestamp(DateTime timestamp, ChartRange range) {
    switch (range) {
      case ChartRange.hour1:
        return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      case ChartRange.hours24:
        return '${timestamp.hour.toString().padLeft(2, '0')}:00';
      case ChartRange.days7:
        return '${timestamp.day}/${timestamp.month}';
    }
  }

  String _formatValue(double value, SensorType sensorType) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
