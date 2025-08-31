// No unused imports
import 'dart:math';

import 'package:influxdb_client/api.dart';

import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../domain/entities/sensor_data.dart';

/// InfluxDB client for storing and querying time-series sensor data.
class InfluxDbService {
  InfluxDbService({
    required this.url,
    required this.token,
    required this.organization,
    required this.bucket,
  });

  final String url;
  final String token;
  final String organization;
  final String bucket;

  InfluxDBClient? _client;
  WriteService? _writeApi;
  QueryService? _queryApi;

  /// Initialize the InfluxDB client.
  Future<Result<void>> initialize() async {
    try {
      Logger.info('Initializing InfluxDB client for $url', tag: 'InfluxDB');

      _client = InfluxDBClient(
        url: url,
        token: token,
        org: organization,
        bucket: bucket,
      );

      // Initialize write and query APIs (2.11.0)
      _writeApi = _client!.getWriteService();
      _queryApi = _client!.getQueryService();

      Logger.info('Successfully connected to InfluxDB', tag: 'InfluxDB');
      return Success(null); // remove `const` unless Success has a const ctor
    } catch (e) {
      final error = 'Error initializing InfluxDB client: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      return Failure(InfluxError(error)); // remove `const` unless allowed
    }
  }

  /// Write sensor data to InfluxDB.
  Future<Result<void>> writeSensorData(SensorData data) async {
    try {
      if (_writeApi == null) {
        return Failure(InfluxError('InfluxDB client not initialized'));
      }

      final point = Point('sensor_data')
          .addTag('sensor_id', data.id)
          .addTag('sensor_type', data.sensorType.name)
          .addTag('unit', data.unit)
          .addField('value', data.value)
          .time(data.timestamp.toUtc()); // ensure UTC

      if (data.deviceId != null) {
        point.addTag('device_id', data.deviceId!);
      }
      if (data.location != null) {
        point.addTag('location', data.location!);
      }

      await _writeApi!.write(point);
      Logger.debug('Written sensor data to InfluxDB: ${data.id}', tag: 'InfluxDB');

      return Success(null);
    } catch (e) {
      final error = 'Error writing sensor data to InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      return Failure(InfluxError(error));
    }
  }

  /// Write multiple sensor data points to InfluxDB.
  Future<Result<void>> writeSensorDataBatch(List<SensorData> dataList) async {
    try {
      if (_writeApi == null) {
        return Failure(InfluxError('InfluxDB client not initialized'));
      }

      final points = dataList.map((data) {
        final p = Point('sensor_data')
            .addTag('sensor_id', data.id)
            .addTag('sensor_type', data.sensorType.name)
            .addTag('unit', data.unit)
            .addField('value', data.value)
            .time(data.timestamp.toUtc()); // ensure UTC

        if (data.deviceId != null) {
          p.addTag('device_id', data.deviceId!);
        }
        if (data.location != null) {
          p.addTag('location', data.location!);
        }
        return p;
      }).toList();

      await _writeApi!.write(points); // list write supported
      Logger.info('Written ${dataList.length} sensor data points to InfluxDB', tag: 'InfluxDB');

      return Success(null);
    } catch (e) {
      final error = 'Error writing sensor data batch to InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      return Failure(InfluxError(error));
    }
  }

  /// Query sensor data from InfluxDB for a specific time range.
  Future<Result<List<SensorData>>> querySensorData({
    SensorType? sensorType,
    String? sensorId,
    String? deviceId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    try {
      // TODO: Replace dummy with Flux query via _queryApi
      Logger.info('Querying sensor data from InfluxDB (returning dummy data)', tag: 'InfluxDB');
      final dummyData = _generateDummySensorData(
        sensorType: sensorType,
        sensorId: sensorId,
        deviceId: deviceId,
        start: start ?? DateTime.now().subtract(const Duration(hours: 24)),
        end: end ?? DateTime.now(),
        limit: limit ?? 100,
      );
      return Success(dummyData);
    } catch (e) {
      final error = 'Error querying sensor data from InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      return Failure(InfluxError(error));
    }
  }

  /// Query latest sensor data for all sensors.
  Future<Result<List<SensorData>>> queryLatestSensorData() async {
    try {
      if (_queryApi == null) {
        return Failure(InfluxError('InfluxDB client not initialized'));
      }
      Logger.info('Querying latest sensor data from InfluxDB (returning dummy data)', tag: 'InfluxDB');
      final dummyData = SensorType.values.map((type) {
        return _generateSingleSensorData(
          type: type,
          sensorId: 'sensor_${type.name}',
          timestamp: DateTime.now(),
        );
      }).toList();
      return Success(dummyData);
    } catch (e) {
      final error = 'Error querying latest sensor data from InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      return Failure(InfluxError(error));
    }
  }

  /// Generate dummy sensor data for testing.
  List<SensorData> _generateDummySensorData({
    SensorType? sensorType,
    String? sensorId,
    String? deviceId,
    required DateTime start,
    required DateTime end,
    required int limit,
  }) {
    final random = Random();
    final duration = end.difference(start);
    final interval = duration ~/ limit;

    final data = <SensorData>[];

    for (int i = 0; i < limit; i++) {
      final timestamp = start.add(interval * i);
      final type = sensorType ?? SensorType.values[random.nextInt(SensorType.values.length)];
      final id = sensorId ?? 'sensor_${type.name}_${random.nextInt(10)}';

      data.add(_generateSingleSensorData(
        type: type,
        sensorId: id,
        deviceId: deviceId,
        timestamp: timestamp,
      ));
    }

    return data;
  }

  /// Generate a single sensor data point.
  SensorData _generateSingleSensorData({
    required SensorType type,
    required String sensorId,
    String? deviceId,
    required DateTime timestamp,
  }) {
    final random = Random();

    double value;
    switch (type) {
      case SensorType.temperature:
        final hourOfDay = timestamp.hour;
        final baseTemp = 22.0;
        final variation = 5.0 * sin((hourOfDay * pi) / 12);
        value = baseTemp + variation + (random.nextDouble() - 0.5) * 2;
        break;
      case SensorType.humidity:
        value = 60.0 + random.nextDouble() * 20 + sin(timestamp.hour * pi / 12) * 10;
        value = value.clamp(30.0, 90.0).toDouble(); // <- cast to double
        break;
      case SensorType.pH:
        value = 6.2 + (random.nextDouble() - 0.5) * 0.6;
        value = value.clamp(5.5, 7.5).toDouble(); // <- cast to double
        break;
      case SensorType.waterLevel:
        value = 15.0 + random.nextDouble() * 10 + sin(timestamp.hour * pi / 6) * 3;
        value = value.clamp(5.0, 30.0).toDouble(); // <- cast to double
        break;
      case SensorType.electricalConductivity:
        value = 1200.0 + random.nextDouble() * 400;
        break;
      case SensorType.lightIntensity:
        final hourOfDay = timestamp.hour;
        if (hourOfDay >= 6 && hourOfDay <= 18) {
          value = 15000.0 + random.nextDouble() * 10000;
        } else {
          value = random.nextDouble() * 100;
        }
        break;
      case SensorType.airQuality:
        value = 400.0 + random.nextDouble() * 200;
        break;
    }

    return SensorData(
      id: sensorId,
      sensorType: type,
      value: double.parse(value.toStringAsFixed(2)),
      unit: type.defaultUnit,
      timestamp: timestamp,
      deviceId: deviceId,
      location: 'hydroponic_system_1',
    );
  }

  /// Close the InfluxDB client.
  Future<void> close() async {
    try {
      Logger.info('Closing InfluxDB client', tag: 'InfluxDB');
      _client?.close();
    } catch (e) {
      Logger.error('Error closing InfluxDB client: $e', tag: 'InfluxDB', error: e);
    }
  }
}
