import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/mqtt/mqtt_service.dart';
import '../../data/influx/influx_service.dart';
import '../../data/repos/sensor_repository.dart';
import '../../data/repos/device_repository.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/app_config.dart';
import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../core/env.dart';
import 'config_controller.dart';

/// Provider for MQTT service configuration.
/// Watches configuration changes and recreates service with new settings.
final mqttServiceProvider = Provider<MqttService>((ref) {
  // Watch configuration, falling back to environment if config not loaded
  final configAsync = ref.watch(configControllerProvider);
  final config = configAsync.whenData((config) => config.mqtt).value ?? MqttConfig.fromEnv();
  
  Logger.info('Creating MQTT service with host: ${config.host}:${config.port}', 
      tag: 'DataProviders');

  return MqttService(
    host: config.host,
    port: config.port,
    clientId: 'hydroponic_monitor_${DateTime.now().millisecondsSinceEpoch}',
    username: config.username.isNotEmpty ? config.username : null,
    password: config.password.isNotEmpty ? config.password : null,
    // Disable auto reconnect during tests to avoid connection loops; enabled by default otherwise.
    autoReconnect: !Env.isTest ? true : false,
  );
});

/// Provider for InfluxDB service configuration.
/// Watches configuration changes and recreates service with new settings.
final influxServiceProvider = Provider<InfluxDbService>((ref) {
  // Watch configuration, falling back to environment if config not loaded
  final configAsync = ref.watch(configControllerProvider);
  final config = configAsync.whenData((config) => config.influx).value ?? InfluxConfig.fromEnv();
  
  Logger.info('Creating InfluxDB service with URL: ${config.url}', 
      tag: 'DataProviders');

  return InfluxDbService(
    url: config.url,
    token: config.token,
    organization: config.organization,
    bucket: config.bucket,
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
final sensorRepositoryInitProvider = FutureProvider<SensorRepository>((
  ref,
) async {
  final repository = ref.read(sensorRepositoryProvider);

  Logger.info(
    'Starting sensor repository initialization...',
    tag: 'DataProviders',
  );

  // Initialize the repository
  final result = await repository.initialize();

  return result is Success
      ? (() {
          Logger.info(
            'Sensor repository initialized successfully',
            tag: 'DataProviders',
          );
          return repository;
        })()
      : (() {
          Logger.error(
            'Failed to initialize sensor repository: ${(result as Failure).error}',
            tag: 'DataProviders',
          );
          throw Exception('Failed to initialize sensor repository: ${(result as Failure).error}');
        })();
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

      return result is Success
          ? (result as Success).data
          : (() {
              Logger.error(
                'Failed to get sensor type history: ${(result as Failure).error}',
                tag: 'DataProviders',
              );
              throw Exception('Failed to load historical data');
            })();
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
