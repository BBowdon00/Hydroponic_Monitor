import 'dart:async';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/sensor_data.dart';
import '../mqtt/mqtt_service.dart';
import '../influx/influx_service.dart';

/// Repository for managing sensor data from MQTT and InfluxDB.
class SensorRepository {
  // Memoization flag for initialization
  bool _initialized = false;
  SensorRepository({required this.mqttService, required this.influxService});

  final MqttService mqttService;
  final InfluxDbService influxService;

  StreamSubscription<SensorData>? _mqttSubscription;

  /// Memoized initialization method
  Future<Result<void>> initialize() async {
    if (_initialized) {
      Logger.debug('SensorRepository already initialized', tag: 'SensorRepository');
      return const Success<void>(null);
    }
    try {
      Logger.info('Initializing sensor repository', tag: 'SensorRepository');
      _initialized = true;

      // Initialize MQTT service
      final mqttResult = await mqttService.connect();
      if (mqttResult is Failure) {
        Logger.warning(
          'MQTT connection failed during initialization: ${mqttResult.error}',
          tag: 'SensorRepository',
        );
        _initialized = false;
        return mqttResult;
      } else {
        Logger.info('MQTT connected successfully', tag: 'SensorRepository');
      }

      // Initialize InfluxDB service for reading historical data
      final influxResult = await influxService.initialize();
      if (influxResult is Failure) {
        Logger.warning(
          'InfluxDB connection failed during initialization: ${influxResult.error}',
          tag: 'SensorRepository',
        );
        _initialized = false;
        return influxResult;
      } else {
        Logger.info('InfluxDB connected successfully', tag: 'SensorRepository');
      }

      // Subscribe to MQTT sensor stream for real-time monitoring only
      _mqttSubscription = mqttService.sensorDataStream.listen(
        (sensorData) {
          Logger.debug(
            'Received sensor data: ${sensorData.sensorType} = ${sensorData.value}',
            tag: 'SensorRepository',
          );
          // Note: No longer writing to InfluxDB - data writing removed
        },
        onError: (e) {
          Logger.error(
            'MQTT sensor stream error: $e',
            tag: 'SensorRepository',
            error: e,
          );
        },
      );

      Logger.info(
        'Sensor repository initialized successfully',
        tag: 'SensorRepository',
      );
      return const Success<void>(null);
    } catch (e) {
      _initialized = false;
      final error = 'Error initializing sensor repository: $e';
      Logger.error(error, tag: 'SensorRepository', error: e);
      return Failure(UnknownError(error));
    }
  }

  /// Get real-time sensor data stream from MQTT.
  Stream<SensorData> get realTimeSensorData => mqttService.sensorDataStream;

  /// Get historical sensor data from InfluxDB.
  Future<Result<List<SensorData>>> getHistoricalData({
    SensorType? sensorType,
    String? sensorId,
    String? deviceId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    return influxService.querySensorData(
      sensorType: sensorType,
      sensorId: sensorId,
      deviceId: deviceId,
      start: start,
      end: end,
      limit: limit,
    );
  }

  /// Get latest sensor readings for all sensors.
  Future<Result<List<SensorData>>> getLatestReadings() async {
    return influxService.queryLatestSensorData();
  }

  /// Get sensor data for a specific sensor type over time.
  Future<Result<List<SensorData>>> getSensorTypeHistory(
    SensorType sensorType, {
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    return influxService.querySensorData(
      sensorType: sensorType,
      start: start ?? DateTime.now().subtract(const Duration(hours: 24)),
      end: end ?? DateTime.now(),
      limit: limit ?? 100,
    );
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    try {
      Logger.info('Disposing sensor repository', tag: 'SensorRepository');
      await _mqttSubscription?.cancel();
      await mqttService.disconnect();
      await influxService.close();
    } catch (e) {
      Logger.error(
        'Error disposing sensor repository: $e',
        tag: 'SensorRepository',
        error: e,
      );
    }
  }
}
