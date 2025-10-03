@Tags(['integration'])
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import '../test_utils.dart';

// Integration test that seeds historical data into InfluxDB using the
// public InfluxDbService API (writeSensorData / writeSensorDataBatch) so
// charts and time-series queries have meaningful history.
// Run: flutter test test/integration/influx_seed_integration_test.dart --tags integration

class _SeedWindow {
  final Duration span; // total historical span to cover
  final Duration interval; // spacing of points
  const _SeedWindow(this.span, this.interval);
}

// Windows align with chart ranges: 1h, 24h, 7d, 30d
const windows = <_SeedWindow>[
  _SeedWindow(Duration(hours: 1), Duration(minutes: 5)),
  _SeedWindow(Duration(hours: 24), Duration(minutes: 30)),
  _SeedWindow(Duration(days: 7), Duration(hours: 2)),
  _SeedWindow(Duration(days: 30), Duration(hours: 6)),
];

// Sensor types we want robust history for (subset for speed)
const seededTypes = [
  SensorType.temperature,
  SensorType.humidity,
  SensorType.pH,
  SensorType.waterLevel,
  SensorType.powerUsage,
];

SensorData _synthPoint(SensorType type, DateTime ts, int i) {
  // Deterministic waveform per type using sine/cosine
  final phase = (i % 360) * math.pi / 180;
  double base;
  double amp;
  switch (type) {
    case SensorType.temperature:
      base = 22; amp = 3; break;
    case SensorType.humidity:
      base = 55; amp = 10; break;
    case SensorType.pH:
      base = 6.2; amp = 0.12; break;
    case SensorType.waterLevel:
      base = 70; amp = 6; break;
    case SensorType.powerUsage:
      base = 120; amp = 30; break;
    case SensorType.electricalConductivity:
      base = 1100; amp = 200; break;
    case SensorType.lightIntensity:
      base = 15000; amp = 5000; break;
    case SensorType.airQuality:
      base = 400; amp = 80; break;
  }
  final value = base + amp * (0.6 * math.sin(phase) + 0.4 * math.cos(phase / 2));
  return SensorData(
    id: '${type.name}_1',
    sensorType: type,
    value: double.parse(value.toStringAsFixed(type == SensorType.pH ? 2 : 1)),
    unit: type.defaultUnit,
    timestamp: ts.toUtc(),
    deviceId: '1',
    deviceNode: 'rpi',
    location: 'tent1',
  );
}

Future<List<SensorData>> _buildSeries(SensorType type) async {
  final now = DateTime.now();
  final all = <SensorData>[];
  for (final w in windows) {
    final start = now.subtract(w.span);
    var t = start;
    var i = 0;
    while (t.isBefore(now)) {
      all.add(_synthPoint(type, t, i));
      t = t.add(w.interval);
      i++;
    }
  }
  return all;
}

void main() {
  group('Influx seeding via InfluxDbService', () {
    late InfluxDbService influx;

    setUpAll(() async {
      // Reuse TestConfig constants from existing integration harness
      influx = InfluxDbService(
        url: TestConfig.testInfluxUrl,
        token: TestConfig.testInfluxToken,
        organization: TestConfig.testInfluxOrg,
        bucket: TestConfig.testInfluxBucket,
      );
  final init = await influx.initialize();
  expect(init, isA<Success<void>>(), reason: 'Influx initialization failed');
    });

    tearDownAll(() async {
      await influx.close();
    });

    test('seed historical data for charts', tags: ['integration'], () async {
      // For each sensor type build a synthetic multi-window series then write in batches
      const batchSize = 500;
      for (final type in seededTypes) {
        final series = await _buildSeries(type);
        // chunk
        for (var offset = 0; offset < series.length; offset += batchSize) {
          final slice = series.sublist(offset, math.min(offset + batchSize, series.length));
          final result = await influx.writeSensorDataBatch(slice);
          expect(result, isA<Success<void>>(), reason: 'Failed writing batch for ${type.name}');
        }
      }

      // Simple verification: latest query returns at least one reading per seeded type
      final latestResult = await influx.queryLatestSensorData();
      expect(latestResult, isA<Success<List<SensorData>>>());
      final latest = (latestResult as Success<List<SensorData>>).data;
      final typesReturned = latest.map((e) => e.sensorType).toSet();
      for (final t in seededTypes) {
        expect(typesReturned.contains(t), isTrue, reason: 'Missing latest reading for ${t.name}');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
