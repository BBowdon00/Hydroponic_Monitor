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
  bool _disposed = false;
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
      // Initialize MQTT service
      final mqttResult = await mqttService.connect();
      if (mqttResult is Failure) {
        if (strictInit) {
          _initialized = false;
          return Failure(mqttResult.error);
        }
        Logger.warning(
          'MQTT connection attempt failed (soft-fail). Operating in degraded mode: ${mqttResult.error}',
          tag: 'SensorRepository',
        );
        _startMqttRetryLoop();
      } else {
        // Wait explicitly for a connected status event to avoid premature success log.
        final connected = await _waitForMqttConnected(
          timeout: const Duration(seconds: 5),
        );
        if (connected) {
          Logger.info('MQTT connected successfully', tag: 'SensorRepository');
        } else {
          Logger.warning(
            'MQTT connect() returned success but no connected event observed within timeout – proceeding cautiously',
            tag: 'SensorRepository',
          );
        }
        await mqttService.ensureInitialized(timeout: const Duration(seconds: 4));
      }

      // Initialize InfluxDB service
      final influxResult = await influxService.initialize();
      if (influxResult is Failure) {
        if (strictInit) {
          _initialized = false;
          return Failure(influxResult.error);
        }
        Logger.warning(
          'InfluxDB connection failed (soft-fail). Historical data unavailable: ${influxResult.error}',
          tag: 'SensorRepository',
        );
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
      _disposed = true;
      // Cancel any pending MQTT retry loop so it doesn't continue using old host/port
      _retryTimer?.cancel();
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

  // --- Internal retry logic ---
  Timer? _retryTimer;
  int _retryAttempt = 0;
  Future<bool> _waitForMqttConnected({required Duration timeout}) async {
    if (mqttService.isConnected) return true;
    try {
      return await mqttService.connectionStream
          .where((s) => s == 'connected' || s == 'reconnected')
          .map((_) => true)
          .first
          .timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return mqttService.isConnected;
    }
  }
  void _startMqttRetryLoop() {
    if (_disposed) {
      Logger.debug('Skip retry loop start: repository disposed', tag: 'SensorRepository');
      return;
    }
    // Accessing private field of MqttService via dynamic for guard; safe in this controlled context.
  final retired = mqttService.isRetired;
    if (retired) {
      Logger.debug('Skip retry loop start: mqtt service retired', tag: 'SensorRepository');
      return;
    }
    _retryTimer?.cancel();
    const maxInterval = Duration(seconds: 30);
    // Exponential backoff with cap
    final delay = Duration(seconds: (1 << _retryAttempt).clamp(2, 30));
    _retryAttempt = (_retryAttempt + 1).clamp(0, 10);
    Logger.info(
      'Scheduling MQTT reconnect attempt in ${delay.inSeconds}s (attempt $_retryAttempt)',
      tag: 'SensorRepository',
    );
    _retryTimer = Timer(delay, () async {
      if (_disposed) {
        Logger.debug('Abort scheduled retry: repository disposed', tag: 'SensorRepository');
        return;
      }
  final retired = mqttService.isRetired;
      if (retired) {
        Logger.debug('Abort scheduled retry: mqtt service retired', tag: 'SensorRepository');
        return;
      }
      final result = await mqttService.connect();
      if (result is Success) {
        Logger.info('Background MQTT reconnect succeeded', tag: 'SensorRepository');
        _retryAttempt = 0; // reset
        await mqttService.ensureInitialized(timeout: const Duration(seconds: 4));
        return;
      }
      if (delay < maxInterval) {
        _startMqttRetryLoop();
      } else {
        Logger.warning(
          'Max MQTT retry interval reached; continuing retries at capped interval',
          tag: 'SensorRepository',
        );
        _startMqttRetryLoop();
      }
    });
  }
}
