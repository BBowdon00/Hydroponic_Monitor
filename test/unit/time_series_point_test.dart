import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/domain/entities/time_series_point.dart';

void main() {
  group('TimeSeriesPoint', () {
    test('should create TimeSeriesPoint with correct values', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0);
      final point = TimeSeriesPoint(timestamp: timestamp, value: 25.5);

      expect(point.timestamp, equals(timestamp));
      expect(point.value, equals(25.5));
    });

    test('should support equality comparison', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0);
      final point1 = TimeSeriesPoint(timestamp: timestamp, value: 25.5);
      final point2 = TimeSeriesPoint(timestamp: timestamp, value: 25.5);
      final point3 = TimeSeriesPoint(timestamp: timestamp, value: 26.0);

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });

    test('should have consistent hashCode for equal objects', () {
      final timestamp = DateTime(2024, 1, 1, 12, 0);
      final point1 = TimeSeriesPoint(timestamp: timestamp, value: 25.5);
      final point2 = TimeSeriesPoint(timestamp: timestamp, value: 25.5);

      expect(point1.hashCode, equals(point2.hashCode));
    });
  });

  group('TimeSeriesStats', () {
    test('should calculate stats from empty list', () {
      final stats = TimeSeriesStats.fromPoints([]);

      expect(stats.min, equals(0));
      expect(stats.max, equals(0));
      expect(stats.average, equals(0));
      expect(stats.count, equals(0));
    });

    test('should calculate stats from single point', () {
      final points = [
        TimeSeriesPoint(timestamp: DateTime(2024, 1, 1), value: 25.5),
      ];
      final stats = TimeSeriesStats.fromPoints(points);

      expect(stats.min, equals(25.5));
      expect(stats.max, equals(25.5));
      expect(stats.average, equals(25.5));
      expect(stats.count, equals(1));
    });

    test('should calculate stats from multiple points', () {
      final points = [
        TimeSeriesPoint(timestamp: DateTime(2024, 1, 1), value: 20.0),
        TimeSeriesPoint(timestamp: DateTime(2024, 1, 2), value: 25.0),
        TimeSeriesPoint(timestamp: DateTime(2024, 1, 3), value: 30.0),
      ];
      final stats = TimeSeriesStats.fromPoints(points);

      expect(stats.min, equals(20.0));
      expect(stats.max, equals(30.0));
      expect(stats.average, equals(25.0));
      expect(stats.count, equals(3));
    });

    test('should calculate average correctly for non-whole numbers', () {
      final points = [
        TimeSeriesPoint(timestamp: DateTime(2024, 1, 1), value: 22.5),
        TimeSeriesPoint(timestamp: DateTime(2024, 1, 2), value: 27.5),
      ];
      final stats = TimeSeriesStats.fromPoints(points);

      expect(stats.min, equals(22.5));
      expect(stats.max, equals(27.5));
      expect(stats.average, equals(25.0));
      expect(stats.count, equals(2));
    });
  });
}