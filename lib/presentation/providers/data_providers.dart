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
class _MqttServiceNotifier extends AutoDisposeNotifier<MqttService> {
  MqttService? _previous;

  @override
  MqttService build() {
    final mqttConfig = ref.watch(configControllerProvider).maybeWhen(
          data: (c) => c.mqtt,
          orElse: () => MqttConfig.fromEnv(),
        );

    // Dispose previous instance before creating a new one
    if (_previous != null) {
      _previous!.disconnect();
    }

    final service = MqttService(
      host: mqttConfig.host,
      port: mqttConfig.port,
      clientId: 'hydroponic_monitor_${DateTime.now().millisecondsSinceEpoch}',
      username: mqttConfig.username.isNotEmpty ? mqttConfig.username : null,
      password: mqttConfig.password.isNotEmpty ? mqttConfig.password : null,
      autoReconnect: !Env.isTest,
    );

    Logger.info('Instantiated MQTT service (${mqttConfig.host}:${mqttConfig.port})', tag: 'DataProviders');

    // Kick off connection (fire-and-forget)
    if (!Env.isTest) {
      // ignore: discarded_futures
      service.connect();
    }

    _previous = service;

    ref.onDispose(() {
      service.disconnect();
    });

    return service;
  }
}

final mqttServiceProvider = AutoDisposeNotifierProvider<_MqttServiceNotifier, MqttService>(() => _MqttServiceNotifier());

/// Provider for InfluxDB service configuration.
/// Watches configuration changes and recreates service with new settings.
class _InfluxServiceNotifier extends AutoDisposeNotifier<InfluxDbService> {
  InfluxDbService? _previous;

  @override
  InfluxDbService build() {
    final influxConfig = ref.watch(configControllerProvider).maybeWhen(
          data: (c) => c.influx,
          orElse: () => InfluxConfig.fromEnv(),
        );

    if (_previous != null) {
      _previous!.close();
    }

    final service = InfluxDbService(
      url: influxConfig.url,
      token: influxConfig.token,
      organization: influxConfig.organization,
      bucket: influxConfig.bucket,
    );
    Logger.info('Instantiated InfluxDB service (${influxConfig.url})', tag: 'DataProviders');

    if (!Env.isTest) {
      // ignore: discarded_futures
      service.initialize();
    }
    _previous = service;

    ref.onDispose(() => service.close());
    return service;
  }
}

final influxServiceProvider = AutoDisposeNotifierProvider<_InfluxServiceNotifier, InfluxDbService>(() => _InfluxServiceNotifier());

/// Provider for sensor repository.
final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  final mqttService = ref.watch(mqttServiceProvider); // watch so it rebuilds on new service
  final influxService = ref.watch(influxServiceProvider);

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
          throw Exception('Failed to initialize sensor repository: ${result.error}');
        })();
});

/// Provider for device repository.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);

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
