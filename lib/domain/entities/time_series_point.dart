/// A single point in a time series for chart rendering.
class TimeSeriesPoint {
  const TimeSeriesPoint({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final double value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSeriesPoint &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp;

  @override
  int get hashCode => timestamp.hashCode;

  @override
  String toString() =>
      'TimeSeriesPoint(timestamp: $timestamp, value: $value)';
}
