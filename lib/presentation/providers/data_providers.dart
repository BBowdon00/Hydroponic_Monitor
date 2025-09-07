import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/mqtt/mqtt_service.dart';
import '../../data/influx/influx_service.dart';
import '../../data/repos/sensor_repository.dart';
import '../../data/repos/device_repository.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device.dart';
import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../core/env.dart';

/// Provider for MQTT service configuration.
final mqttServiceProvider = Provider<MqttService>((ref) {
  return MqttService(
    host: Env.mqttHost, // <-- MQTT broker host
    port: Env.mqttPort, // <-- MQTT broker port
    clientId: 'hydroponic_monitor_${DateTime.now().millisecondsSinceEpoch}',
    username: Env.mqttUsername.isNotEmpty ? Env.mqttUsername : null,
    password: Env.mqttPassword.isNotEmpty ? Env.mqttPassword : null,
    // Disable auto reconnect during tests to avoid connection loops; enabled by default otherwise.
    autoReconnect: !Env.isTest ? true : false,
  );
});

/// Provider for InfluxDB service configuration.
final influxServiceProvider = Provider<InfluxDbService>((ref) {
  return InfluxDbService(
    url: Env.influxUrl,
    token: Env.influxToken,
    organization: Env.influxOrg,
    bucket: Env.influxBucket,
  );
});

/// Provider for sensor repository.
final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  final mqttService = ref.read(mqttServiceProvider);
  final influxService = ref.read(influxServiceProvider);

  return SensorRepository(
    mqttService: mqttService,
    influxService: influxService,
  );
});

/// Provider that ensures sensor repository initialization and provides initialization status.
final sensorRepositoryInitProvider = FutureProvider<SensorRepository>((ref) async {
  final repository = ref.read(sensorRepositoryProvider);
  
  // Initialize the repository
  final result = await repository.initialize();
  
  return result.when(
    success: (_) {
      Logger.info('Sensor repository initialized successfully', tag: 'DataProviders');
      return repository;
    },
    failure: (error) {
      Logger.error('Failed to initialize sensor repository: $error', tag: 'DataProviders');
      throw Exception('Failed to initialize sensor repository: $error');
    },
  );
});

/// Provider for device repository.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final mqttService = ref.read(mqttServiceProvider);

  return DeviceRepository(mqttService: mqttService);
});

/// Provider for real-time sensor data stream.
/// This initializes the repository on demand and provides the stream.
final realTimeSensorDataProvider = StreamProvider<SensorData>((ref) {
  final repositoryAsync = ref.watch(sensorRepositoryInitProvider);
  return repositoryAsync.when(
    data: (repository) => repository.realTimeSensorData,
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Provider for device status updates stream.
/// The repository will handle its own initialization when the stream is accessed.
final deviceStatusUpdatesProvider = StreamProvider<Device>((ref) {
  final deviceRepository = ref.read(deviceRepositoryProvider);
  return deviceRepository.deviceStatusUpdates;
});

// Individual connection status providers removed - use connectionStatusProvider instead

/// Provider for historical sensor data for a specific type.
final sensorTypeHistoryProvider =
    FutureProvider.family<List<SensorData>, SensorType>((
      ref,
      sensorType,
    ) async {
      final sensorRepository = ref.read(sensorRepositoryProvider);
      final result = await sensorRepository.getSensorTypeHistory(
        sensorType,
        start: DateTime.now().subtract(const Duration(hours: 24)),
        limit: 100,
      );

      return result.when(
        success: (data) => data,
        failure: (error) {
          Logger.error(
            'Failed to get sensor type history: $error',
            tag: 'DataProviders',
          );
          throw Exception('Failed to load historical data');
        },
      );
    });

/// Extension to handle Result types more easily.
extension ResultExtension<T> on Result<T> {
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).data);
    } else {
      return failure((this as Failure<T>).error);
    }
  }
}
