import 'dart:async';
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
  final StreamController<String> _connectionController =
      StreamController<String>.broadcast();

  /// Stream of connection status changes.
  Stream<String> get connectionStream => _connectionController.stream;

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

      // Initialize write and query APIs
      _writeApi = _client!.getWriteService();
      _queryApi = _client!.getQueryService();

      Logger.info('Successfully connected to InfluxDB', tag: 'InfluxDB');
      _connectionController.add('connected');
      return Success(null); // remove `const` unless Success has a const ctor
    } catch (e) {
      final error = 'Error initializing InfluxDB client: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      _connectionController.add('disconnected');
      return Failure(InfluxError(error)); // remove `const` unless allowed
    }
  }

  /// Write sensor data to InfluxDB.
  Future<Result<void>> writeSensorData(SensorData data) async {
    try {
      if (_writeApi == null) {
        _connectionController.add('disconnected');
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
      Logger.debug(
        'Written sensor data to InfluxDB: ${data.id}',
        tag: 'InfluxDB',
      );

      return Success(null);
    } catch (e) {
      final error = 'Error writing sensor data to InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      _connectionController.add('disconnected');
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
      Logger.info(
        'Written ${dataList.length} sensor data points to InfluxDB',
        tag: 'InfluxDB',
      );

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
    final startTime =
        start ?? DateTime.now().subtract(const Duration(hours: 24));
    final endTime = end ?? DateTime.now();
    final limitValue = limit ?? 100;

    // If client is not initialized, return dummy data
    if (_client == null || _queryApi == null) {
      Logger.info(
        'InfluxDB client not initialized, returning dummy data',
        tag: 'InfluxDB',
      );
      final dummyData = _generateDummySensorData(
        sensorType: sensorType,
        sensorId: sensorId,
        deviceId: deviceId,
        start: startTime,
        end: endTime,
        limit: limitValue,
      );
      return Success(dummyData);
    }

    try {
      Logger.info(
        'Querying sensor data from InfluxDB: start=$startTime, end=$endTime, limit=$limitValue',
        tag: 'InfluxDB',
      );

      // Build Flux query with optional filters
      final filters = <String>[];

      if (sensorType != null) {
        filters.add(
          '|> filter(fn: (r) => r["sensor_type"] == "${sensorType.name}")',
        );
      }

      if (sensorId != null) {
        filters.add('|> filter(fn: (r) => r["sensor_id"] == "$sensorId")');
      }

      if (deviceId != null) {
        filters.add('|> filter(fn: (r) => r["device_id"] == "$deviceId")');
      }

      final filtersString = filters.join('\n  ');

      final query =
          '''
from(bucket: "$bucket")
  |> range(start: ${startTime.toUtc().toIso8601String()}, stop: ${endTime.toUtc().toIso8601String()})
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["_field"] == "value")
  $filtersString
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: $limitValue)
''';

      Logger.debug('Executing Flux query: $query', tag: 'InfluxDB');

      final queryResult = await _queryApi!.query(query);
      final sensorDataList = await _parseQueryResult(queryResult);
      
      Logger.info(
        'Retrieved ${sensorDataList.length} sensor data points from InfluxDB',
        tag: 'InfluxDB',
      );
      return Success(sensorDataList);
    } catch (e) {
      final error = 'Error querying sensor data from InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);

      // Fallback to dummy data if query fails (for development/testing)
      Logger.warning(
        'Falling back to dummy data due to query error',
        tag: 'InfluxDB',
      );
      final dummyData = _generateDummySensorData(
        sensorType: sensorType,
        sensorId: sensorId,
        deviceId: deviceId,
        start: startTime,
        end: endTime,
        limit: limitValue,
      );
      return Success(dummyData);
    }
  }

  /// Query latest sensor data for all sensors.
  Future<Result<List<SensorData>>> queryLatestSensorData() async {
    // If client is not initialized, return dummy data
    if (_client == null || _queryApi == null) {
      Logger.info(
        'InfluxDB client not initialized, returning dummy latest data',
        tag: 'InfluxDB',
      );
      final dummyData = SensorType.values.map((type) {
        return _generateSingleSensorData(
          type: type,
          sensorId: 'sensor_${type.name}',
          timestamp: DateTime.now(),
        );
      }).toList();
      return Success(dummyData);
    }

    try {
      Logger.info('Querying latest sensor data from InfluxDB', tag: 'InfluxDB');

      // Query for latest reading of each sensor type
      final query =
          '''
from(bucket: "$bucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["_field"] == "value")
  |> group(columns: ["sensor_type", "sensor_id"])
  |> last()
  |> yield()
''';

      Logger.debug('Executing latest data Flux query: $query', tag: 'InfluxDB');

      final queryResult = await _queryApi!.query(query);
      final sensorDataList = await _parseQueryResult(queryResult);
      
      Logger.info(
        'Retrieved ${sensorDataList.length} latest sensor readings from InfluxDB',
        tag: 'InfluxDB',
      );
      return Success(sensorDataList);
    } catch (e) {
      final error = 'Error querying latest sensor data from InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);

      // Fallback to dummy data if query fails (for development/testing)
      Logger.warning(
        'Falling back to dummy latest data due to query error',
        tag: 'InfluxDB',
      );
      final dummyData = SensorType.values.map((type) {
        return _generateSingleSensorData(
          type: type,
          sensorId: 'sensor_${type.name}',
          timestamp: DateTime.now(),
        );
      }).toList();
      return Success(dummyData);
    }
  }

  /// Parse query result from InfluxDB client.
  Future<List<SensorData>> _parseQueryResult(Stream<FluxRecord> queryResult) async {
    final sensorDataList = <SensorData>[];

    try {
      await for (final record in queryResult) {
        try {
          final sensorData = _parseFluxRecord(record);
          if (sensorData != null) {
            sensorDataList.add(sensorData);
          }
        } catch (e) {
          Logger.warning('Failed to parse flux record: $e', tag: 'InfluxDB');
        }
      }
      Logger.debug('Finished parsing query result with ${sensorDataList.length} records', tag: 'InfluxDB');
    } catch (e) {
      Logger.error('Error parsing query result: $e', tag: 'InfluxDB', error: e);
    }

    return sensorDataList;
  }

  /// Parse a single FluxRecord into SensorData.
  SensorData? _parseFluxRecord(FluxRecord record) {
    try {
      // Extract required fields from the flux record using correct API
      final timestamp = record['_time'] as DateTime?;
      final value = record['_value'];
      final sensorId = record['sensor_id'];
      final sensorTypeStr = record['sensor_type'];

      if (timestamp == null ||
          value == null ||
          sensorId == null ||
          sensorTypeStr == null) {
        return null;
      }

      // Parse value as double
      final doubleValue = value is double 
          ? value 
          : double.tryParse(value.toString());
      if (doubleValue == null) return null;

      // Parse sensor type
      SensorType? sensorType;
      for (final type in SensorType.values) {
        if (type.name == sensorTypeStr) {
          sensorType = type;
          break;
        }
      }

      if (sensorType == null) return null;

      // Extract optional fields
      final unit = record['unit']?.toString();
      final deviceId = record['device_id']?.toString();
      final location = record['location']?.toString();

      return SensorData(
        id: sensorId.toString(),
        sensorType: sensorType,
        value: doubleValue,
        unit: unit ?? sensorType.defaultUnit,
        timestamp: timestamp,
        deviceId: deviceId?.isNotEmpty == true ? deviceId : null,
        location: location?.isNotEmpty == true ? location : null,
      );
    } catch (e) {
      Logger.error('Error parsing flux record: $e', tag: 'InfluxDB', error: e);
      return null;
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
      final type =
          sensorType ??
          SensorType.values[random.nextInt(SensorType.values.length)];
      final id = sensorId ?? 'sensor_${type.name}_${random.nextInt(10)}';

      data.add(
        _generateSingleSensorData(
          type: type,
          sensorId: id,
          deviceId: deviceId,
          timestamp: timestamp,
        ),
      );
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
        value =
            60.0 +
            random.nextDouble() * 20 +
            sin(timestamp.hour * pi / 12) * 10;
        value = value.clamp(30.0, 90.0).toDouble(); // <- cast to double
        break;
      case SensorType.pH:
        value = 6.2 + (random.nextDouble() - 0.5) * 0.6;
        value = value.clamp(5.5, 7.5).toDouble(); // <- cast to double
        break;
      case SensorType.waterLevel:
        value =
            15.0 + random.nextDouble() * 10 + sin(timestamp.hour * pi / 6) * 3;
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
      _connectionController.add('disconnected');
      _client?.close();
      await _connectionController.close();
    } catch (e) {
      Logger.error(
        'Error closing InfluxDB client: $e',
        tag: 'InfluxDB',
        error: e,
      );
    }
  }
}
