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

/// Provider for device repository.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final mqttService = ref.read(mqttServiceProvider);

  return DeviceRepository(mqttService: mqttService);
});

/// Provider for initializing the data layer services.
final dataServicesInitializationProvider = FutureProvider<void>((ref) async {
  try {
    // Ensure environment variables from .env are loaded before any services
    // that read Env.* are created. This prevents empty/incorrect tokens
    // (causing InfluxDB 401) when tests or app initialization run.
    await Env.init();
    Logger.info('Initializing data services', tag: 'DataProviders');

    // Log basic env info for diagnostics in CI/tests
    Logger.debug(
      'Influx token present: ${Env.influxToken.isNotEmpty}',
      tag: 'DataProviders',
    );

    final sensorRepository = ref.read(sensorRepositoryProvider);
    final deviceRepository = ref.read(deviceRepositoryProvider);
    final mqttService = ref.read(mqttServiceProvider);

    // Initialize repositories (allow them to succeed even if underlying services fail)
    try {
      // Ensure MQTT and subscriptions are ready first
      await mqttService.ensureInitialized();

      final sensorResult = await sensorRepository.initialize();
      if (sensorResult is Failure) {
        Logger.warning(
          'Sensor repository initialization had issues: ${sensorResult.error}',
          tag: 'DataProviders',
        );
      } else {
        Logger.info(
          'Sensor repository initialized successfully',
          tag: 'DataProviders',
        );
      }
    } catch (e) {
      Logger.warning(
        'Exception during sensor repository initialization (continuing): $e',
        tag: 'DataProviders',
      );
    }

    try {
      // Prefer repository-level ensureInitialized if available
      try {
        if (deviceRepository is dynamic &&
            (deviceRepository.ensureInitialized is Function)) {
          final res = await deviceRepository.ensureInitialized();
          if (res is Failure) {
            Logger.warning(
              'Device repository ensureInitialized had issues: ${res.error}',
              tag: 'DataProviders',
            );
          } else {
            Logger.info(
              'Device repository ensured initialized',
              tag: 'DataProviders',
            );
          }
        } else {
          final deviceResult = await deviceRepository.initialize();
          if (deviceResult is Failure) {
            Logger.warning(
              'Device repository initialization had issues: ${deviceResult.error}',
              tag: 'DataProviders',
            );
          } else {
            Logger.info(
              'Device repository initialized successfully',
              tag: 'DataProviders',
            );
          }
        }
      } catch (inner) {
        Logger.warning(
          'Exception during device repository initialization (continuing): $inner',
          tag: 'DataProviders',
        );
      }
    } catch (e) {
      Logger.warning(
        'Exception during device repository initialization (continuing): $e',
        tag: 'DataProviders',
      );
    }

    Logger.info('Data services initialization completed', tag: 'DataProviders');
  } catch (e) {
    Logger.error(
      'Unexpected error during data services initialization: $e',
      tag: 'DataProviders',
      error: e,
    );
    // Don't rethrow - allow the app to continue even if services fail
  }
});

/// Provider for real-time sensor data stream.
final realTimeSensorDataProvider = StreamProvider<SensorData>((ref) {
  // Ensure data services (repositories, subscriptions) are initialized first.
  ref.watch(dataServicesInitializationProvider);

  final sensorRepository = ref.read(sensorRepositoryProvider);
  return sensorRepository.realTimeSensorData;
});

/// Provider for device status updates stream.
final deviceStatusUpdatesProvider = StreamProvider<Device>((ref) {
  // Ensure data services (repositories, subscriptions) are initialized first.
  ref.watch(dataServicesInitializationProvider);

  final deviceRepository = ref.read(deviceRepositoryProvider);
  return deviceRepository.deviceStatusUpdates;
});

/// Provider for MQTT connection status stream.
final mqttConnectionStatusProvider = StreamProvider<String>((ref) {
  final mqttService = ref.read(mqttServiceProvider);
  return mqttService.connectionStream;
});

/// Provider for InfluxDB connection status stream.
final influxConnectionStatusProvider = StreamProvider<String>((ref) {
  final influxService = ref.read(influxServiceProvider);
  return influxService.connectionStream;
});

/// Provider for latest sensor readings.
final latestSensorReadingsProvider = FutureProvider<List<SensorData>>((
  ref,
) async {
  final sensorRepository = ref.read(sensorRepositoryProvider);
  final result = await sensorRepository.getLatestReadings();

  return result.when(
    success: (data) => data,
    failure: (error) {
      Logger.error(
        'Failed to get latest sensor readings: $error',
        tag: 'DataProviders',
      );
      throw Exception('Failed to load sensor data');
    },
  );
});

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
