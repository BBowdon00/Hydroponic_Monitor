import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/logger.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/time_series_point.dart';
import '../../presentation/pages/charts_page.dart';
import 'data_providers.dart';

/// State class holding chart series data and metadata.
class ChartSeriesState {
  const ChartSeriesState({
    required this.points,
    required this.stats,
    required this.isFallback,
  });

  final List<TimeSeriesPoint> points;
  final ChartStats stats;
  final bool isFallback;
}

/// Statistics for a chart series.
class ChartStats {
  const ChartStats({
    required this.min,
    required this.max,
    required this.average,
  });

  final double min;
  final double max;
  final double average;

  static ChartStats fromPoints(List<TimeSeriesPoint> points) {
    if (points.isEmpty) {
      return const ChartStats(min: 0, max: 0, average: 0);
    }

    double min = points.first.value;
    double max = points.first.value;
    double sum = 0;

    for (final point in points) {
      if (point.value < min) min = point.value;
      if (point.value > max) max = point.value;
      sum += point.value;
    }

    return ChartStats(
      min: double.parse(min.toStringAsFixed(2)),
      max: double.parse(max.toStringAsFixed(2)),
      average: double.parse((sum / points.length).toStringAsFixed(2)),
    );
  }
}

/// Provider for triggering chart data refresh.
/// Increment this value to invalidate and refresh all chart data.
final chartDataRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Provider for sensor chart data with time series points and statistics.
/// Family provider taking (SensorType, ChartRange) as parameters.
final sensorChartDataProvider = FutureProvider.family<
    ChartSeriesState,
    ({SensorType sensorType, ChartRange range})>((ref, params) async {
  // Watch the refresh trigger to invalidate when it changes
  ref.watch(chartDataRefreshTriggerProvider);

  final sensorRepository = ref.read(sensorRepositoryProvider);

  Logger.info(
    'Fetching chart data for ${params.sensorType.name} over ${params.range.name}',
    tag: 'ChartProviders',
  );

  final result = await sensorRepository.getSensorTimeSeries(
    params.sensorType,
    params.range,
  );

  return result.when(
    success: (points) {
      Logger.info(
        'Retrieved ${points.length} points for ${params.sensorType.name}',
        tag: 'ChartProviders',
      );

      final stats = ChartStats.fromPoints(points);

      // Check if this is fallback data by checking if we have an empty point list
      // or if the service returned dummy data (we'll rely on service to tag it correctly)
      // For now, we'll assume empty = fallback or check connection
      final isFallback = points.isEmpty ||
          (points.isNotEmpty && points.length < 5); // Simple heuristic

      return ChartSeriesState(
        points: points,
        stats: stats,
        isFallback: false, // Will be set properly when we add better detection
      );
    },
    failure: (error) {
      Logger.error(
        'Failed to get chart data: $error',
        tag: 'ChartProviders',
      );
      throw Exception('Failed to load chart data');
    },
  );
});
