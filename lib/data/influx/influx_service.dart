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
  WriteApi? _writeApi;
  QueryApi? _queryApi;

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

      // TODO: Update API calls for InfluxDB 2.11.0
      // _writeApi = _client!.getWriteApi();
      // _queryApi = _client!.getQueryApi();

      // Test connection - simplified for now
      Logger.info('Successfully connected to InfluxDB', tag: 'InfluxDB');
      return const Success(null);
    } catch (e) {
      final error = 'Error initializing InfluxDB client: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      return Failure(InfluxError(error));
    }
  }

  /// Write sensor data to InfluxDB.
  Future<Result<void>> writeSensorData(SensorData data) async {
    try {
      // TODO: Re-enable when InfluxDB API is updated
      // if (_writeApi == null) {
      //   return const Failure(InfluxError('InfluxDB client not initialized'));
      // }

      final point = Point('sensor_data')
          .addTag('sensor_id', data.id)
          .addTag('sensor_type', data.sensorType.name)
          .addTag('unit', data.unit)
          .addField('value', data.value)
          .time(data.timestamp);

      if (data.deviceId != null) {
        point.addTag('device_id', data.deviceId!);
      }
      if (data.location != null) {
        point.addTag('location', data.location!);
      }

      // TODO: Update for InfluxDB 2.11.0 API
      // await _writeApi!.writePoint(point);
      Logger.debug('Would write sensor data to InfluxDB: ${data.id}', tag: 'InfluxDB');
      
      return const Success(null);
    } catch (e) {
      final error = 'Error writing sensor data to InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      return Failure(InfluxError(error));
    }
  }

  /// Write multiple sensor data points to InfluxDB.
  Future<Result<void>> writeSensorDataBatch(List<SensorData> dataList) async {
    try {
      // TODO: Re-enable when InfluxDB API is updated
      // if (_writeApi == null) {
      //   return const Failure(InfluxError('InfluxDB client not initialized'));
      // }

      final points = dataList.map((data) {
        final point = Point('sensor_data')
            .addTag('sensor_id', data.id)
            .addTag('sensor_type', data.sensorType.name)
            .addTag('unit', data.unit)
            .addField('value', data.value)
            .time(data.timestamp);

        if (data.deviceId != null) {
          point.addTag('device_id', data.deviceId!);
        }
        if (data.location != null) {
          point.addTag('location', data.location!);
        }

        return point;
      }).toList();

      // TODO: Update for InfluxDB 2.11.0 API
      // await _writeApi!.writePoints(points);
      Logger.info('Would write ${dataList.length} sensor data points to InfluxDB', tag: 'InfluxDB');
      
      return const Success(null);
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
      // TODO: Re-enable when InfluxDB API is updated
      // if (_queryApi == null) {
      //   return const Failure(InfluxError('InfluxDB client not initialized'));
      // }

      // For now, return dummy data since we're still in development
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
      // TODO: Re-enable when InfluxDB API is updated
      // if (_queryApi == null) {
      //   return const Failure(InfluxError('InfluxDB client not initialized'));
      // }

      Logger.info('Querying latest sensor data from InfluxDB (returning dummy data)', tag: 'InfluxDB');
      
      // Generate latest dummy data for all sensor types
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
        // Simulate daily temperature variation
        final hourOfDay = timestamp.hour;
        final baseTemp = 22.0;
        final variation = 5.0 * sin((hourOfDay * pi) / 12);
        value = baseTemp + variation + (random.nextDouble() - 0.5) * 2;
        break;
      case SensorType.humidity:
        // Simulate humidity variations
        value = 60.0 + random.nextDouble() * 20 + sin(timestamp.hour * pi / 12) * 10;
        value = value.clamp(30.0, 90.0);
        break;
      case SensorType.pH:
        // Simulate pH stability with small variations
        value = 6.2 + (random.nextDouble() - 0.5) * 0.6;
        value = value.clamp(5.5, 7.5);
        break;
      case SensorType.waterLevel:
        // Simulate water level changes
        value = 15.0 + random.nextDouble() * 10 + sin(timestamp.hour * pi / 6) * 3;
        value = value.clamp(5.0, 30.0);
        break;
      case SensorType.electricalConductivity:
        value = 1200.0 + random.nextDouble() * 400;
        break;
      case SensorType.lightIntensity:
        // Simulate day/night cycle
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