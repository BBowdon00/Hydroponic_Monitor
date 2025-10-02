/// A lightweight data point for time series charts.
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.timestamp, required this.value});

  final DateTime timestamp;
  final double value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSeriesPoint &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          value == other.value;

  @override
  int get hashCode => timestamp.hashCode ^ value.hashCode;

  @override
  String toString() => 'TimeSeriesPoint(timestamp: $timestamp, value: $value)';
}

/// Statistics computed from a list of time series points.
class TimeSeriesStats {
  const TimeSeriesStats({
    required this.min,
    required this.max,
    required this.average,
    required this.count,
  });

  final double min;
  final double max;
  final double average;
  final int count;

  /// Calculate statistics from a list of time series points.
  static TimeSeriesStats fromPoints(List<TimeSeriesPoint> points) {
    if (points.isEmpty) {
      return const TimeSeriesStats(min: 0, max: 0, average: 0, count: 0);
    }

    final values = points.map((p) => p.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final sum = values.reduce((a, b) => a + b);
    final average = sum / values.length;

    return TimeSeriesStats(
      min: min,
      max: max,
      average: average,
      count: values.length,
    );
  }

  @override
  String toString() =>
      'TimeSeriesStats(min: $min, max: $max, avg: $average, count: $count)';
}
