import 'package:hooks_riverpod/hooks_riverpod.dart';

// Import the new system providers and re-export them for backward compatibility
import 'system_providers.dart';

// Re-export the main providers for backward compatibility
export 'system_providers.dart' show
    mqttServiceProvider,
    influxServiceProvider,
    dataServiceProvider,
    sensorRepositoryProvider,
    deviceRepositoryProvider,
    systemInitializationProvider,
    connectionStatusProvider,
    realTimeSensorDataProvider,
    deviceStatusUpdatesProvider,
    latestSensorReadingsProvider,
    sensorTypeHistoryProvider,
    ResultExtension;

// Legacy provider aliases for backward compatibility
final dataServicesInitializationProvider = systemInitializationProvider;

// Legacy connection status providers
final mqttConnectionStatusProvider = StreamProvider<String>((ref) {
  final connectionState = ref.watch(connectionStatusProvider);
  return connectionState.when(
    data: (state) => Stream.value(state.mqttConnected ? 'connected' : 'disconnected'),
    loading: () => Stream.value('connecting'),
    error: (_, __) => Stream.value('disconnected'),
  );
});

final influxConnectionStatusProvider = StreamProvider<String>((ref) {
  final connectionState = ref.watch(connectionStatusProvider);
  return connectionState.when(
    data: (state) => Stream.value(state.influxConnected ? 'connected' : 'disconnected'),
    loading: () => Stream.value('connecting'),
    error: (_, __) => Stream.value('disconnected'),
  );
});
