import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'data_providers.dart';
import '../../core/logger.dart';

/// Combined connection status for MQTT and InfluxDB services.
class ConnectionStatus {
  const ConnectionStatus({
    required this.mqttConnected,
    required this.influxConnected,
    this.mqttDisconnectedSince,
    this.influxDisconnectedSince,
  });

  final bool mqttConnected;
  final bool influxConnected;
  final DateTime? mqttDisconnectedSince;
  final DateTime? influxDisconnectedSince;

  /// True if at least one service is disconnected.
  bool get hasDisconnections => !mqttConnected || !influxConnected;

  /// True if both services are connected.
  bool get allConnected => mqttConnected && influxConnected;

  /// Get the earliest disconnection time, or null if all connected.
  DateTime? get earliestDisconnection {
    if (allConnected) return null;

    if (!mqttConnected && !influxConnected) {
      if (mqttDisconnectedSince == null) return influxDisconnectedSince;
      if (influxDisconnectedSince == null) return mqttDisconnectedSince;
      return mqttDisconnectedSince!.isBefore(influxDisconnectedSince!)
          ? mqttDisconnectedSince
          : influxDisconnectedSince;
    }

    if (!mqttConnected) return mqttDisconnectedSince;
    if (!influxConnected) return influxDisconnectedSince;

    return null;
  }

  ConnectionStatus copyWith({
    bool? mqttConnected,
    bool? influxConnected,
    DateTime? mqttDisconnectedSince,
    DateTime? influxDisconnectedSince,
  }) {
    return ConnectionStatus(
      mqttConnected: mqttConnected ?? this.mqttConnected,
      influxConnected: influxConnected ?? this.influxConnected,
      mqttDisconnectedSince:
          mqttDisconnectedSince ?? this.mqttDisconnectedSince,
      influxDisconnectedSince:
          influxDisconnectedSince ?? this.influxDisconnectedSince,
    );
  }
}

/// Provider that tracks connection status for both MQTT and InfluxDB services.
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  // Watch the sensor repository init provider to ensure services are initialized
  final repositoryAsync = ref.watch(sensorRepositoryInitProvider);

  return repositoryAsync.when(
    data: (repository) {
      // Watch services so if configuration changes recreate them, we subscribe
      // to the new instances rather than continuing to receive events from an
      // obsolete service still attempting old host/port connections.
      final mqttService = ref.watch(mqttServiceProvider);
      final influxService = ref.watch(influxServiceProvider);

      // Initial state - both disconnected with current time
      final now = DateTime.now();
      var currentStatus = ConnectionStatus(
        mqttConnected: false,
        influxConnected: false,
        mqttDisconnectedSince: now,
        influxDisconnectedSince: now,
      );

      final controller = StreamController<ConnectionStatus>();

      // Subscribe to MQTT connection stream
      StreamSubscription<String>? mqttSubscription;
      StreamSubscription<String>? influxSubscription;

      void updateMqttStatus(String status) {
        // Treat 'connected' and 'reconnected' as connected states.
        final isConnected = status == 'connected' || status == 'reconnected';
        final now = DateTime.now();

        currentStatus = currentStatus.copyWith(
          mqttConnected: isConnected,
          mqttDisconnectedSince: isConnected
              ? null
              : (currentStatus.mqttDisconnectedSince ??
                    now), // Only set if not already set
        );
        Logger.debug(
          'connectionStatusProvider: MQTT status event=$status => mqttConnected=$isConnected earliestDisconnection=${currentStatus.earliestDisconnection}',
          tag: 'ConnectionStatus',
        );
        controller.add(currentStatus);
      }

      void updateInfluxStatus(String status) {
        // Only explicit 'connected' means healthy; anything else treat as disconnected
        final isConnected = status == 'connected';
        final now = DateTime.now();

        currentStatus = currentStatus.copyWith(
          influxConnected: isConnected,
          influxDisconnectedSince: isConnected
              ? null
              : (currentStatus.influxDisconnectedSince ??
                    now), // Only set if not already set
        );
        Logger.debug(
          'connectionStatusProvider: Influx status event=$status => influxConnected=$isConnected earliestDisconnection=${currentStatus.earliestDisconnection}',
          tag: 'ConnectionStatus',
        );
        controller.add(currentStatus);
      }

      // Set up subscriptions
      mqttSubscription = mqttService.connectionStream.listen(
        updateMqttStatus,
        onError: (error) {
          updateMqttStatus('disconnected');
        },
      );

      influxSubscription = influxService.connectionStream.listen(
        updateInfluxStatus,
        onError: (error) {
          updateInfluxStatus('disconnected');
        },
      );

      Logger.debug(
        'connectionStatusProvider: subscriptions established (will request status replay)',
        tag: 'ConnectionStatus',
      );

      // Emit initial state
      controller.add(currentStatus);

      // Force replay of last known statuses so we don't stay stuck in the
      // initial disconnected state if services were already connected before
      // this provider was (re)created (e.g. after dynamic config update).
      // These calls are no-ops if the services haven't set a status yet.
      try {
        mqttService.emitCurrentStatus();
        influxService.emitCurrentStatus();
      } catch (_) {
        // Non-fatal; initial state will update on next status event.
      }

      // If Influx never emits within grace period but repository init succeeded,
      // proactively trigger a health check (covers cases where initial event was lost).
      Timer(const Duration(seconds: 3), () async {
        if (controller.isClosed) return;
        if (!currentStatus.influxConnected) {
          Logger.debug(
            'connectionStatusProvider: no Influx event within 3s – forcing health check',
            tag: 'ConnectionStatus',
          );
          try {
            final ok = await influxService.checkHealth();
            updateInfluxStatus(ok ? 'connected' : 'disconnected');
          } catch (e) {
            updateInfluxStatus('disconnected');
          }
        }
      });

      // Cleanup function
      ref.onDispose(() {
        mqttSubscription?.cancel();
        influxSubscription?.cancel();
        controller.close();
      });

      return controller.stream;
    },
    loading: () {
      // While loading, return a stream with loading state
      return Stream.value(
        ConnectionStatus(
          mqttConnected: false,
          influxConnected: false,
          mqttDisconnectedSince: DateTime.now(),
          influxDisconnectedSince: DateTime.now(),
        ),
      );
    },
    error: (error, stack) {
      // On error, return a stream with error state
      return Stream.value(
        ConnectionStatus(
          mqttConnected: false,
          influxConnected: false,
          mqttDisconnectedSince: DateTime.now(),
          influxDisconnectedSince: DateTime.now(),
        ),
      );
    },
  );
});
