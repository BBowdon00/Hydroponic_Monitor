import 'dart:async';

import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../domain/entities/reconnect_result.dart';
import 'mqtt/mqtt_service.dart';
import 'influx/influx_service.dart';
import 'dart:math';

/// Service that handles manual reconnection of MQTT and InfluxDB services.
class ConnectionRecoveryService {
  ConnectionRecoveryService({
    required this.mqttService,
    required this.influxService,
    this.onMqttReconnect,
  });

  final MqttService mqttService;
  final InfluxDbService influxService;
  /// Optional callback invoked after a successful MQTT client recreation & initialization.
  final void Function()? onMqttReconnect;

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
    if (!force && _lastAttempt != null && now.difference(_lastAttempt!) < _throttleInterval) {
      final wait = _throttleInterval - now.difference(_lastAttempt!);
      Logger.debug(
        'Manual reconnect throttled - retry in ${wait.inMilliseconds}ms',
        tag: 'ConnectionRecovery',
      );
      return ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration.zero,
        errorMessage: 'Please wait ${wait.inSeconds + 1}s before retrying',
        errorCodes: const [ReconnectErrorType.throttled],
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
        errorCodes: const [ReconnectErrorType.concurrentAttempt],
      );
    }

    _inProgress = true;
    _lastAttempt = now;
    final startTime = DateTime.now();

    Logger.info(
      'Starting manual reconnection attempt${force ? ' (forced)' : ''}',
      tag: 'ConnectionRecovery',
    );

    // Small jitter to desynchronize repeated reconnect cycles (50-200ms)
    final jitter = Duration(milliseconds: 50 + Random().nextInt(150));
    await Future.delayed(jitter);

  bool mqttOk = false;
  bool influxOk = false;
  final errors = <String>[];
  final errorCodes = <ReconnectErrorType>[];

  // NOTE: We previously considered toggling autoReconnect during manual cycles.
  // Removed direct access to avoid dependency on mock implementations; revisit if setter is exposed.

    try {
      // Reconnect MQTT
      try {
        Logger.info('Attempting MQTT reconnection...', tag: 'ConnectionRecovery');
        // Auto-reconnect suppression skipped (no safe toggle available)
  await _reconnectMqtt();
        mqttOk = true;
        Logger.info('MQTT reconnection successful', tag: 'ConnectionRecovery');
  // Invoke hook so higher layers (e.g., providers) can normalize pending state.
  onMqttReconnect?.call();
      } catch (e) {
        final error = 'MQTT reconnection failed: $e';
        Logger.warning(error, tag: 'ConnectionRecovery');
        errors.add(error);
        errorCodes.add(ReconnectErrorType.mqttUnknown); // refine mapping later
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
          errorCodes.add(ReconnectErrorType.influxUnhealthy);
        }
      } catch (e) {
        final error = 'InfluxDB health check failed: $e';
        Logger.warning(error, tag: 'ConnectionRecovery');
        errors.add(error);
        errorCodes.add(ReconnectErrorType.influxInitFailed);
      }
    } finally {
      _inProgress = false;
      // restore any auto reconnect preference (noop if client recreated with same setting)
      // mqttService exposes autoReconnect getter only; if a setter is added, restore it here.
    }

    final elapsed = DateTime.now().difference(startTime);
    final result = ReconnectResult(
      mqttOk: mqttOk,
      influxOk: influxOk,
      elapsed: elapsed,
      errorMessage: errors.isNotEmpty ? errors.join('; ') : null,
      errorCodes: errorCodes,
    );

    // Force re-emit of current statuses so UI banners update immediately even
    // if they subscribed after the original 'connected' events or no state
    // transition (e.g., service already considered connected) occurred.
    try {
      if (mqttOk) {
        mqttService.emitCurrentStatus();
      }
      if (influxOk) {
        influxService.emitCurrentStatus();
      }
    } catch (e) {
      Logger.debug('Non-fatal: emitCurrentStatus failed: $e', tag: 'ConnectionRecovery');
    }

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
  /// This follows TASK008 requirements: teardown + reconnect handshake with new client.
  Future<void> _reconnectMqtt() async {
    try {
      // Step 1: Reset existing client (dispose client but keep streams)
      await mqttService.reset();

      // Step 2: Small delay to ensure clean disconnect and resource cleanup
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 3: Reconnect with new client instance
      final result = await mqttService.connect();
      if (result is Success) {
        // Step 4: Wait for initialization and topic subscriptions
        await mqttService.ensureInitialized();
        Logger.debug(
          'MQTT client successfully recreated and subscribed',
          tag: 'ConnectionRecovery',
        );
      } else if (result is Failure) {
        throw Exception('MQTT connection failed: ${result.error}');
      }
    } catch (e) {
      Logger.error(
        'Error during MQTT reconnection: $e',
        tag: 'ConnectionRecovery',
      );
      rethrow;
    }
  }

  /// Tests the InfluxDB connection with a lightweight health check query.
  Future<bool> _testInfluxConnection() async {
    try {
      // If query api not ready, perform a lightweight init attempt.
      final needsInit =
          // Access internal fields via public behavior: if health check always returns false and previous init failed.
          // We approximate by performing a health check; if false, try initialize()
          false; // Placeholder logic (InfluxDbService does not expose direct readiness flags)
      // First health attempt
      final healthy = await influxService.checkHealth();
      if (healthy) return true;
      // Attempt re-initialize if still unhealthy (simulate re-init path)
      final init = await influxService.initialize();
      if (init is Success) {
        final recheck = await influxService.checkHealth();
        return recheck;
      }
      return false;
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
