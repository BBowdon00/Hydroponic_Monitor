import 'dart:async';

import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../domain/entities/reconnect_result.dart';
import 'mqtt/mqtt_service.dart';
import 'influx/influx_service.dart';

/// Service that handles manual reconnection of MQTT and InfluxDB services.
class ConnectionRecoveryService {
  ConnectionRecoveryService({
    required this.mqttService,
    required this.influxService,
  });

  final MqttService mqttService;
  final InfluxDbService influxService;

  DateTime? _lastAttempt;
  static const Duration _throttleInterval = Duration(seconds: 5);
  bool _inProgress = false;

  /// Performs a manual reconnection of both MQTT and InfluxDB services.
  /// 
  /// Returns a [ReconnectResult] with the outcome of both reconnection attempts.
  /// If [force] is false and a reconnection was attempted less than 5 seconds ago,
  /// this method will return immediately with the previous result status.
  Future<ReconnectResult> manualReconnect({bool force = false}) async {
    final now = DateTime.now();

    // Throttle consecutive attempts
    if (!force && 
        _lastAttempt != null && 
        now.difference(_lastAttempt!) < _throttleInterval) {
      Logger.debug(
        'Manual reconnect throttled - last attempt was ${now.difference(_lastAttempt!).inSeconds}s ago',
        tag: 'ConnectionRecovery',
      );
      return ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration.zero,
        errorMessage: 'Please wait ${_throttleInterval.inSeconds}s between reconnection attempts',
      );
    }

    // Prevent concurrent attempts
    if (_inProgress) {
      Logger.debug('Manual reconnect already in progress', tag: 'ConnectionRecovery');
      return ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration.zero,
        errorMessage: 'Reconnection already in progress',
      );
    }

    _inProgress = true;
    _lastAttempt = now;
    final startTime = DateTime.now();

    Logger.info(
      'Starting manual reconnection attempt${force ? ' (forced)' : ''}',
      tag: 'ConnectionRecovery',
    );

    bool mqttOk = false;
    bool influxOk = false;
    final errors = <String>[];

    try {
      // Reconnect MQTT
      try {
        Logger.info('Attempting MQTT reconnection...', tag: 'ConnectionRecovery');
        await _reconnectMqtt();
        mqttOk = true;
        Logger.info('MQTT reconnection successful', tag: 'ConnectionRecovery');
      } catch (e) {
        final error = 'MQTT reconnection failed: $e';
        Logger.warning(error, tag: 'ConnectionRecovery');
        errors.add(error);
      }

      // Test InfluxDB connection
      try {
        Logger.info('Attempting InfluxDB health check...', tag: 'ConnectionRecovery');
        final ok = await _testInfluxConnection();
        influxOk = ok;
        if (ok) {
          Logger.info('InfluxDB health check successful', tag: 'ConnectionRecovery');
        } else {
          Logger.warning('InfluxDB health check reported NOT healthy', tag: 'ConnectionRecovery');
        }
      } catch (e) {
        final error = 'InfluxDB health check failed: $e';
        Logger.warning(error, tag: 'ConnectionRecovery');
        errors.add(error);
      }

    } finally {
      _inProgress = false;
    }

    final elapsed = DateTime.now().difference(startTime);
    final result = ReconnectResult(
      mqttOk: mqttOk,
      influxOk: influxOk,
      elapsed: elapsed,
      errorMessage: errors.isNotEmpty ? errors.join('; ') : null,
    );

    // Log structured outcome
    Logger.info(
      'Manual reconnect completed: '
      'mqttOk=$mqttOk, influxOk=$influxOk, elapsed=${elapsed.inMilliseconds}ms'
      '${errors.isNotEmpty ? ', errors=${errors.length}' : ''}',
      tag: 'ConnectionRecovery',
    );

    return result;
  }

  /// Reconnects the MQTT service by disconnecting and reconnecting.
  Future<void> _reconnectMqtt() async {
    // Disconnect existing client
    await mqttService.disconnect();

    // Small delay to ensure clean disconnect
    await Future.delayed(const Duration(milliseconds: 100));

    // Reconnect
    final result = await mqttService.connect();
    if (result is Success) {
      // Connection successful, wait for initialization
      await mqttService.ensureInitialized();
    } else if (result is Failure) {
      throw Exception('MQTT connection failed: ${result.error}');
    }
  }

  /// Tests the InfluxDB connection with a lightweight health check query.
  Future<bool> _testInfluxConnection() async {
    try {
      // Attempt a health check without re-initializing if already created
      final healthy = await influxService.checkHealth();
      return healthy;
    } catch (e) {
      throw Exception('InfluxDB health check failed: $e');
    }
  }

  /// Whether a manual reconnect is currently in progress.
  bool get isInProgress => _inProgress;

  /// Time of the last reconnection attempt, if any.
  DateTime? get lastAttempt => _lastAttempt;

  /// Whether another reconnection attempt is allowed (not throttled).
  bool get canAttemptReconnect {
    if (_lastAttempt == null) return true;
    return DateTime.now().difference(_lastAttempt!) >= _throttleInterval;
  }
}