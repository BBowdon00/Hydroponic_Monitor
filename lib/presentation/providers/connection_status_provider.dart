import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'data_providers.dart';

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
  final mqttService = ref.read(mqttServiceProvider);
  final influxService = ref.read(influxServiceProvider);

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
    final isConnected = status == 'connected';
    final now = DateTime.now();

    currentStatus = currentStatus.copyWith(
      mqttConnected: isConnected,
      mqttDisconnectedSince: isConnected
          ? null
          : (currentStatus.mqttDisconnectedSince ??
                now), // Only set if not already set
    );
    controller.add(currentStatus);
  }

  void updateInfluxStatus(String status) {
    final isConnected = status == 'connected';
    final now = DateTime.now();

    currentStatus = currentStatus.copyWith(
      influxConnected: isConnected,
      influxDisconnectedSince: isConnected
          ? null
          : (currentStatus.influxDisconnectedSince ??
                now), // Only set if not already set
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

  // Emit initial state
  controller.add(currentStatus);

  // Cleanup function
  ref.onDispose(() {
    mqttSubscription?.cancel();
    influxSubscription?.cancel();
    controller.close();
  });

  return controller.stream;
});
