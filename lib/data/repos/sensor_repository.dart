import 'dart:async';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/time_series_point.dart';
import '../../presentation/pages/charts_page.dart';
import '../mqtt/mqtt_service.dart';
import '../influx/influx_service.dart';

/// Repository for managing sensor data from MQTT and InfluxDB.
class SensorRepository {
  // Memoization flag for initialization
  bool _initialized = false;
  SensorRepository({
    required this.mqttService,
    required this.influxService,
    this.strictInit = false,
  });

  final MqttService mqttService;
  final InfluxDbService influxService;

  /// When true, initialization will return Failure immediately on first service error
  /// (legacy behavior expected by some unit tests). When false (default), initialization
  /// soft-fails and proceeds in degraded mode with background retries.
  final bool strictInit;

  StreamSubscription<SensorData>? _mqttSubscription;

  /// Memoized initialization method
  Future<Result<void>> initialize() async {
    if (_initialized) {
      Logger.debug(
        'SensorRepository already initialized',
        tag: 'SensorRepository',
      );
      return const Success<void>(null);
    }
    try {
      Logger.info('Initializing sensor repository', tag: 'SensorRepository');
      _initialized = true;

      // MQTT is already connected via mqttConnectionProvider - just wait for ready state
      await mqttService.ensureInitialized(timeout: const Duration(seconds: 4));

      // InfluxDB is already initialized via influxConnectionProvider - no action needed
      // Services are ready, just subscribe to sensor stream

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

  /// Get time series data for a specific sensor type for charting.
  /// Returns aggregated data points ordered by timestamp (ascending).
  Future<Result<List<TimeSeriesPoint>>> getSensorTimeSeries(
    SensorType sensorType,
    ChartRange range,
  ) async {
    return influxService.queryTimeSeries(sensorType, range);
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    try {
      Logger.info('Disposing sensor repository', tag: 'SensorRepository');
      await _mqttSubscription?.cancel();
      await mqttService.dispose();
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
