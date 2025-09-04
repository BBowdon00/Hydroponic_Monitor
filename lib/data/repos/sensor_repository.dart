import 'dart:async';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/sensor_data.dart';
import '../mqtt/mqtt_service.dart';
import '../influx/influx_service.dart';

/// Repository for managing sensor data from MQTT and InfluxDB.
class SensorRepository {
  SensorRepository({required this.mqttService, required this.influxService});

  final MqttService mqttService;
  final InfluxDbService influxService;

  StreamSubscription<SensorData>? _mqttSubscription;

  /// Initialize the repository and start listening to MQTT data.
  Future<Result<void>> initialize() async {
    try {
      Logger.info('Initializing sensor repository', tag: 'SensorRepository');

      // Initialize MQTT service (non-blocking - continue if it fails)
      final mqttResult = await mqttService.connect();
      if (mqttResult is Failure) {
        Logger.warning(
          'MQTT connection failed - sensor data will not be available: ${mqttResult.error}',
          tag: 'SensorRepository',
        );
      } else {
        Logger.info('MQTT connected successfully', tag: 'SensorRepository');
        
        // Only start listening to sensor data if MQTT connected successfully
        _mqttSubscription = mqttService.sensorDataStream.listen(
          (sensorData) async {
            final result = await influxService.writeSensorData(sensorData);
            if (result is Failure) {
              Logger.error(
                'Failed to store sensor data in InfluxDB: ${result.error}',
                tag: 'SensorRepository',
              );
            }
          },
          onError: (error) {
            Logger.error(
              'Error in MQTT sensor data stream: $error',
              tag: 'SensorRepository',
            );
          },
        );
      }

      // Initialize InfluxDB service (non-blocking - continue if it fails)
      final influxResult = await influxService.initialize();
      if (influxResult is Failure) {
        Logger.warning(
          'InfluxDB connection failed - data storage will not be available: ${influxResult.error}',
          tag: 'SensorRepository',
        );
      } else {
        Logger.info('InfluxDB connected successfully', tag: 'SensorRepository');
      }

      Logger.info(
        'Sensor repository initialized successfully',
        tag: 'SensorRepository',
      );
      return const Success(null);
    } catch (e) {
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

  /// Manually store sensor data (for testing or backup).
  Future<Result<void>> storeSensorData(SensorData data) async {
    return influxService.writeSensorData(data);
  }

  /// Store multiple sensor data points.
  Future<Result<void>> storeSensorDataBatch(List<SensorData> dataList) async {
    return influxService.writeSensorDataBatch(dataList);
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
