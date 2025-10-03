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
  String? _lastConnectionStatus;
  Timer? _healthTimer;

  /// Stream of connection status changes.
  Stream<String> get connectionStream {
    // Return a broadcast stream that first replays the last status
    // then forwards live updates from the controller.
    return Stream.multi((controller) {
      // Replay last status to new subscribers first
      if (_lastConnectionStatus != null) {
        controller.add(_lastConnectionStatus!);
      }

      // Forward live updates
      final sub = _connectionController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );

      controller.onCancel = () {
        sub.cancel();
      };
    }, isBroadcast: true);
  }

  /// Re-emit the last known connection status (e.g., after manual reconnect) so
  /// any dependent combined status providers can refresh without waiting for
  /// another periodic health check.
  void emitCurrentStatus() {
    if (_lastConnectionStatus != null && !_connectionController.isClosed) {
      Logger.debug(
        'InfluxDbService.emitCurrentStatus => ${_lastConnectionStatus!}',
        tag: 'InfluxDB',
      );
      _connectionController.add(_lastConnectionStatus!);
    } else {
      Logger.debug(
        'InfluxDbService.emitCurrentStatus skipped (status=${_lastConnectionStatus}, closed=${_connectionController.isClosed})',
        tag: 'InfluxDB',
      );
    }
  }

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
      // Perform explicit health check so we don't report connected when server is down
      final healthy = await checkHealth();
      if (healthy) {
        Logger.info(
          'Successfully connected to InfluxDB (health pass)',
          tag: 'InfluxDB',
        );
        _startHealthMonitoring();
        // Ensure status replay for late subscribers.
        emitCurrentStatus();
        return Success(null);
      } else {
        final error = 'InfluxDB health check failed during initialization';
        Logger.warning(error, tag: 'InfluxDB');
        return Failure(InfluxError(error));
      }
    } catch (e) {
      final error = 'Error initializing InfluxDB client: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      _lastConnectionStatus = 'disconnected';
      _connectionController.add('disconnected');
      return Failure(InfluxError(error)); // remove `const` unless allowed
    }
  }

  /// Explicit lightweight health check.
  /// Strategy:
  /// 1. Use Ping API (fast, minimal auth requirement) to verify server reachability.
  /// 2. Use Ready API to verify the instance is ready (not initializing / upgrading).
  /// If both pass, we mark as connected. Any failure marks disconnected.
  Future<bool> checkHealth() async {
    try {
      if (_client == null) {
        Logger.debug(
          'Creating InfluxDB client for health check',
          tag: 'InfluxDB',
        );
        _client = InfluxDBClient(
          url: url,
          token: token,
          org: organization,
          bucket: bucket,
        );
        _writeApi = _client!.getWriteService();
        _queryApi = _client!.getQueryService();
      }

      var healthy = false;
      // Step 1: ping
      bool pingIndicatesReachable = false;
      try {
        await _client!.getPingApi().getPing();
        pingIndicatesReachable = true; // reachable
      } catch (e) {
        // In some InfluxDB setups the ping endpoint can return a 400 while the instance is otherwise healthy.
        // If we detect a 400 ApiException, we will proceed to the READY check before declaring failure.
        if (e is ApiException && e.code == 400) {
          Logger.debug(
            'Ping returned 400 (tolerated) – proceeding to READY check',
            tag: 'InfluxDB',
          );
          pingIndicatesReachable =
              true; // treat as soft success, defer real decision to READY
        } else {
          Logger.debug('Ping failed: $e', tag: 'InfluxDB');
        }
      }

      // Step 2: always attempt ready (even if ping failed) – it gives definitive cluster readiness.
      try {
        final ready = await _client!.getReadyApi().getReady();
        healthy = (ready.status == ReadyStatusEnum.ready);
      } catch (e) {
        // If READY fails but ping looked fine, log separately for diagnostics.
        Logger.debug(
          'Ready check failed: $e (pingReachable=$pingIndicatesReachable)',
          tag: 'InfluxDB',
        );
        healthy = false;
      }
      if (healthy) {
        if (_lastConnectionStatus != 'connected') {
          _lastConnectionStatus = 'connected';
          _connectionController.add('connected');
          // (Re)start monitoring on transition to connected
          _startHealthMonitoring();
        }
        return true;
      } else {
        if (_lastConnectionStatus != 'disconnected') {
          _lastConnectionStatus = 'disconnected';
          _connectionController.add('disconnected');
        }
        return false;
      }
    } catch (e) {
      Logger.warning('InfluxDB health check error: $e', tag: 'InfluxDB');
      if (_lastConnectionStatus != 'disconnected') {
        _lastConnectionStatus = 'disconnected';
        _connectionController.add('disconnected');
      }
      return false;
    }
  }

  void _startHealthMonitoring() {
    // Ensure only one timer
    _healthTimer?.cancel();
    // Run periodic health checks every minute while app stays alive.
    _healthTimer = Timer.periodic(const Duration(minutes: 1), (t) async {
      // Only run if we still think we're connected to avoid spamming when down.
      if (_lastConnectionStatus == 'connected') {
        final ok = await checkHealth();
        if (!ok) {
          Logger.warning(
            'InfluxDB became unhealthy during periodic check',
            tag: 'InfluxDB',
          );
        }
      }
    });
  }
  /// Write sensor data to InfluxDB.
  Future<Result<void>> writeSensorData(SensorData data) async {
    try {
      if (_writeApi == null) {
        _connectionController.add('disconnected');
        return Failure(InfluxError('InfluxDB client not initialized'));
      }
          Logger.debug(
            'InfluxDbService connection status -> disconnected (exception path)',
            tag: 'InfluxDB',
          );
          _connectionController.add('disconnected');
      // Use 'sensor' measurement with proper tag structure
      final point = Point('sensor')
          .addTag('deviceType', data.sensorType.name)
          .addTag(
            'deviceID',
            data.deviceId ?? '1',
          ) // Default to '1' if not specified
          .addTag('location', data.location ?? 'tent') // Default location
          .addTag('project', 'hydroponic_monitor') // Project identifier
          .addField('value', data.value)
          .time(data.timestamp.toUtc()); // ensure UTC

      // Add deviceNode if provided
      if (data.deviceNode != null) {
        point.addTag('deviceNode', data.deviceNode!);
      }

      await _writeApi!.write(point);
      Logger.debug(
        'Written sensor data to InfluxDB: ${data.sensorType.name}/${data.deviceId}',
        tag: 'InfluxDB',
      );

      return Success(null);
    } catch (e) {
      final error = 'Error writing sensor data to InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      _lastConnectionStatus = 'disconnected';
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
        // Use 'sensor' measurement with proper tag structure
        final p = Point('sensor')
            .addTag('deviceType', data.sensorType.name)
            .addTag(
              'deviceID',
              data.deviceId ?? '1',
            ) // Default to '1' if not specified
            .addTag('location', data.location ?? 'tent') // Default location
            .addTag('project', 'hydroponic_monitor') // Project identifier
            .addField('value', data.value)
            .time(data.timestamp.toUtc()); // ensure UTC

        // Add deviceNode if provided
        if (data.deviceNode != null) {
          p.addTag('deviceNode', data.deviceNode!);
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
          '|> filter(fn: (r) => r["deviceType"] == "${sensorType.name}")',
        );
      }

      if (sensorId != null) {
        filters.add('|> filter(fn: (r) => r["deviceID"] == "$sensorId")');
      }

      if (deviceId != null) {
        filters.add('|> filter(fn: (r) => r["deviceNode"] == "$deviceId")');
      }

      final filtersString = filters.join('\n  ');

      final query =
          '''
from(bucket: "$bucket")
  |> range(start: ${startTime.toUtc().toIso8601String()}, stop: ${endTime.toUtc().toIso8601String()})
  |> filter(fn: (r) => r["_measurement"] == "sensor")
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
      // Mark healthy since query succeeded
      if (_lastConnectionStatus != 'connected') {
        _lastConnectionStatus = 'connected';
        _connectionController.add('connected');
      }
      return Success(sensorDataList);
    } catch (e) {
      final error = 'Error querying sensor data from InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      // Mark disconnected on failure
      if (_lastConnectionStatus != 'disconnected') {
        _lastConnectionStatus = 'disconnected';
        _connectionController.add('disconnected');
      }

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
          sensorId: '1', // Use deviceID format
          timestamp: DateTime.now(),
        );
      }).toList();
      return Success(dummyData);
    }

    try {
      Logger.info('Querying latest sensor data from InfluxDB', tag: 'InfluxDB');

      // Query for latest reading of each sensor type
      // Updated to match actual tag structure: deviceType, deviceID, location, deviceNode, project
      final query =
          '''
from(bucket: "$bucket")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor")
  |> filter(fn: (r) => r["_field"] == "value")
  |> group(columns: ["deviceType", "deviceID"])
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
      if (_lastConnectionStatus != 'connected') {
        _lastConnectionStatus = 'connected';
        _connectionController.add('connected');
      }
      return Success(sensorDataList);
    } catch (e) {
      final error = 'Error querying latest sensor data from InfluxDB: $e';
      Logger.error(error, tag: 'InfluxDB', error: e);
      if (_lastConnectionStatus != 'disconnected') {
        _lastConnectionStatus = 'disconnected';
        _connectionController.add('disconnected');
      }

      // Fallback to dummy data if query fails (for development/testing)
      Logger.warning(
        'Falling back to dummy latest data due to query error',
        tag: 'InfluxDB',
      );
      final dummyData = SensorType.values.map((type) {
        return _generateSingleSensorData(
          type: type,
          sensorId: '1', // Use deviceID format
          timestamp: DateTime.now(),
        );
      }).toList();
      return Success(dummyData);
    }
  }

  /// Parse query result from InfluxDB client.
  Future<List<SensorData>> _parseQueryResult(
    Stream<FluxRecord> queryResult,
  ) async {
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
      Logger.debug(
        'Finished parsing query result with ${sensorDataList.length} records',
        tag: 'InfluxDB',
      );
    } catch (e) {
      Logger.error('Error parsing query result: $e', tag: 'InfluxDB', error: e);
    }

    return sensorDataList;
  }

  /// Parse a single FluxRecord into SensorData.
  SensorData? _parseFluxRecord(FluxRecord record) {
    try {
      // Extract required fields from the flux record using the new tag structure
      final timestampRaw = record['_time'];
      final value = record['_value'];
      final sensorId = record['deviceID'];
      final sensorTypeStr = record['deviceType'];

      if (timestampRaw == null ||
          value == null ||
          sensorId == null ||
          sensorTypeStr == null) {
        return null;
      }

      // Parse timestamp - handle both String and DateTime types
      DateTime? timestamp;
      if (timestampRaw is DateTime) {
        timestamp = timestampRaw;
      } else if (timestampRaw is String) {
        timestamp = DateTime.tryParse(timestampRaw);
      }

      if (timestamp == null) {
        Logger.error(
          'Failed to parse timestamp: $timestampRaw',
          tag: 'InfluxDB',
        );
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

      // Extract optional fields using new tag structure
      final deviceNode = record['deviceNode']?.toString();
      final location = record['location']?.toString();
      final project = record['project']
          ?.toString(); // Available but not currently used

      return SensorData(
        id: '${sensorType.name}_$sensorId', // Construct ID from type and deviceID
        sensorType: sensorType,
        value: doubleValue,
        unit: sensorType.defaultUnit,
        timestamp: timestamp,
        deviceId: sensorId.toString(),
        deviceNode: deviceNode?.isNotEmpty == true ? deviceNode : null,
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

    // Define realistic device nodes for different sensor types
    final deviceNodes = ['rpi', 'esp32', 'esp32_1', 'esp32_2'];

    for (int i = 0; i < limit; i++) {
      final timestamp = start.add(interval * i);
      final type =
          sensorType ??
          SensorType.values[random.nextInt(SensorType.values.length)];
      final id = sensorId ?? '1'; // Use deviceID format

      // Assign realistic device nodes based on sensor type
      String assignedDeviceNode;
      if (deviceId != null) {
        assignedDeviceNode = deviceId;
      } else {
        // Assign nodes based on sensor characteristics
        switch (type) {
          case SensorType.temperature:
          case SensorType.humidity:
          case SensorType.pH:
          case SensorType.electricalConductivity:
            assignedDeviceNode = 'rpi'; // Main sensor hub
            break;
          case SensorType.waterLevel:
          case SensorType.lightIntensity:
          case SensorType.airQuality:
            assignedDeviceNode = 'esp32_1'; // Environmental sensors
            break;
          case SensorType.powerUsage:
            assignedDeviceNode = 'esp32_2'; // Power monitoring
            break;
        }
      }

      data.add(
        _generateSingleSensorData(
          type: type,
          sensorId: id,
          deviceNode: assignedDeviceNode,
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
    String? deviceNode,
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
      case SensorType.powerUsage:
        // Power usage varies based on time of day (lights, heaters, etc.)
        final hourOfDay = timestamp.hour;
        final baseUsage = 50.0; // Base system power
        if (hourOfDay >= 6 && hourOfDay <= 18) {
          // Daytime with lights on
          value = baseUsage + 120.0 + random.nextDouble() * 80;
        } else {
          // Night time, lower usage
          value = baseUsage + random.nextDouble() * 50;
        }
        break;
    }

    // Assign default device node if not provided
    final node = deviceNode ?? _getDefaultDeviceNode(type);

    return SensorData(
      id: '${type.name}_$sensorId', // Construct ID from type and deviceID
      sensorType: type,
      value: double.parse(value.toStringAsFixed(2)),
      unit: type.defaultUnit,
      timestamp: timestamp,
      deviceId: sensorId,
      deviceNode: node,
      location: 'tent', // Default location as per MQTT patterns
    );
  }

  /// Get default device node assignment for sensor types.
  String _getDefaultDeviceNode(SensorType type) {
    switch (type) {
      case SensorType.temperature:
      case SensorType.humidity:
      case SensorType.pH:
      case SensorType.electricalConductivity:
        return 'rpi'; // Main sensor hub
      case SensorType.waterLevel:
      case SensorType.lightIntensity:
      case SensorType.airQuality:
        return 'esp32_1'; // Environmental sensors
      case SensorType.powerUsage:
        return 'esp32_2'; // Power monitoring
    }
  }

  /// Close the InfluxDB client.
  Future<void> close() async {
    try {
      Logger.info('Closing InfluxDB client', tag: 'InfluxDB');
      _connectionController.add('disconnected');
      _healthTimer?.cancel();
      _healthTimer = null;
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
