import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/connection_recovery_service.dart';
import '../../domain/entities/reconnect_result.dart';
import 'data_providers.dart';

/// State for manual reconnection attempts.
class ManualReconnectState {
  const ManualReconnectState({
    this.inProgress = false,
    this.lastResult,
    this.lastAttempt,
  });

  /// Whether a reconnection is currently in progress.
  final bool inProgress;

  /// Result of the last reconnection attempt, if any.
  final ReconnectResult? lastResult;

  /// Timestamp of the last reconnection attempt, if any.
  final DateTime? lastAttempt;

  /// Whether another reconnection attempt can be made (not throttled).
  bool get canAttempt {
    if (lastAttempt == null) return true;
    return DateTime.now().difference(lastAttempt!) >= const Duration(seconds: 5);
  }

  ManualReconnectState copyWith({
    bool? inProgress,
    ReconnectResult? lastResult,
    DateTime? lastAttempt,
  }) {
    return ManualReconnectState(
      inProgress: inProgress ?? this.inProgress,
      lastResult: lastResult ?? this.lastResult,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }

  @override
  String toString() {
    return 'ManualReconnectState(inProgress: $inProgress, canAttempt: $canAttempt, lastResult: $lastResult)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ManualReconnectState &&
        other.inProgress == inProgress &&
        other.lastResult == lastResult &&
        other.lastAttempt == lastAttempt;
  }

  @override
  int get hashCode => Object.hash(inProgress, lastResult, lastAttempt);
}

/// Notifier for manual reconnection state and operations.
class ManualReconnectNotifier extends StateNotifier<ManualReconnectState> {
  ManualReconnectNotifier(this._connectionRecoveryService) : super(const ManualReconnectState());

  final ConnectionRecoveryService _connectionRecoveryService;

  /// Attempts a manual reconnection of MQTT and InfluxDB services.
  /// Returns the result and updates the state accordingly.
  Future<ReconnectResult> attemptReconnect({bool force = false}) async {
    if (state.inProgress && !force) {
      return ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration.zero,
        errorMessage: 'Reconnection already in progress',
      );
    }

    if (!force && !state.canAttempt) {
      return ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration.zero,
        errorMessage: 'Please wait 5 seconds between reconnection attempts',
      );
    }

    // Set in-progress state
    state = state.copyWith(
      inProgress: true,
      lastAttempt: DateTime.now(),
    );

    try {
      final result = await _connectionRecoveryService.manualReconnect(force: force);
      
      // Update state with result
      state = state.copyWith(
        inProgress: false,
        lastResult: result,
      );

      return result;
    } catch (e) {
      // Handle unexpected errors
      final result = ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration.zero,
        errorMessage: 'Unexpected error during reconnection: $e',
      );

      state = state.copyWith(
        inProgress: false,
        lastResult: result,
      );

      return result;
    }
  }
}

/// Provider for the connection recovery service.
final connectionRecoveryServiceProvider = Provider<ConnectionRecoveryService>((ref) {
  final mqttService = ref.read(mqttServiceProvider);
  final influxService = ref.read(influxServiceProvider);

  return ConnectionRecoveryService(
    mqttService: mqttService,
    influxService: influxService,
  );
});

/// Provider for manual reconnection state and operations.
final manualReconnectProvider = StateNotifierProvider<ManualReconnectNotifier, ManualReconnectState>((ref) {
  final connectionRecoveryService = ref.read(connectionRecoveryServiceProvider);
  return ManualReconnectNotifier(connectionRecoveryService);
});