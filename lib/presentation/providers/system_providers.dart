import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/services/data_service.dart';
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
    host: Env.mqttHost,
    port: Env.mqttPort,
    clientId: 'hydroponic_monitor_${DateTime.now().millisecondsSinceEpoch}',
    username: Env.mqttUsername.isNotEmpty ? Env.mqttUsername : null,
    password: Env.mqttPassword.isNotEmpty ? Env.mqttPassword : null,
    autoReconnect: !Env.isTest,
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

/// Provider for the unified data service.
final dataServiceProvider = Provider<DataService>((ref) {
  final mqttService = ref.read(mqttServiceProvider);
  final influxService = ref.read(influxServiceProvider);

  return DataService(
    mqttService: mqttService,
    influxService: influxService,
  );
});

/// Provider for sensor repository.
final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  final dataService = ref.read(dataServiceProvider);
  return SensorRepository(dataService: dataService);
});

/// Provider for device repository.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final dataService = ref.read(dataServiceProvider);
  return DeviceRepository(dataService: dataService);
});

/// Provider for initializing the system.
final systemInitializationProvider = FutureProvider<void>((ref) async {
  try {
    Logger.info('Initializing hydroponic monitoring system', tag: 'SystemProviders');

    // Load environment configuration
    await Env.init();
    Logger.debug(
      'Environment loaded - InfluxDB token present: ${Env.influxToken.isNotEmpty}',
      tag: 'SystemProviders',
    );

    // Initialize data service
    final dataService = ref.read(dataServiceProvider);
    final dataInitResult = await dataService.initialize();
    if (dataInitResult is Failure) {
      Logger.warning(
        'Data service initialization issues: ${dataInitResult.error}',
        tag: 'SystemProviders',
      );
    }

    // Initialize repositories
    final sensorRepository = ref.read(sensorRepositoryProvider);
    final deviceRepository = ref.read(deviceRepositoryProvider);

    final sensorResult = await sensorRepository.initialize();
    if (sensorResult is Failure) {
      Logger.warning(
        'Sensor repository initialization issues: ${sensorResult.error}',
        tag: 'SystemProviders',
      );
    }

    final deviceResult = await deviceRepository.initialize();
    if (deviceResult is Failure) {
      Logger.warning(
        'Device repository initialization issues: ${deviceResult.error}',
        tag: 'SystemProviders',
      );
    }

    Logger.info('System initialization completed', tag: 'SystemProviders');
  } catch (e) {
    Logger.error(
      'System initialization error: $e',
      tag: 'SystemProviders',
      error: e,
    );
    // Don't rethrow - allow app to continue with degraded functionality
  }
});

/// Provider for connection status.
final connectionStatusProvider = StreamProvider<ConnectionState>((ref) {
  final dataService = ref.read(dataServiceProvider);
  return dataService.connectionStream;
});

/// Provider for real-time sensor data stream.
final realTimeSensorDataProvider = StreamProvider<SensorData>((ref) {
  // Ensure system is initialized
  ref.watch(systemInitializationProvider);
  
  final dataService = ref.read(dataServiceProvider);
  return dataService.sensorDataStream;
});

/// Provider for device status updates stream.
final deviceStatusUpdatesProvider = StreamProvider<Device>((ref) {
  // Ensure system is initialized
  ref.watch(systemInitializationProvider);
  
  final dataService = ref.read(dataServiceProvider);
  return dataService.deviceStatusStream;
});

/// Provider for latest sensor readings by type.
final latestSensorReadingsByTypeProvider = StreamProvider<Map<SensorType, SensorData>>((ref) {
  // Ensure system is initialized
  ref.watch(systemInitializationProvider);
  
  final sensorRepository = ref.read(sensorRepositoryProvider);
  return sensorRepository.latestReadingsByType;
});

/// Provider for device states.
final deviceStatesProvider = StreamProvider<Map<String, Device>>((ref) {
  // Ensure system is initialized
  ref.watch(systemInitializationProvider);
  
  final deviceRepository = ref.read(deviceRepositoryProvider);
  return deviceRepository.deviceStatesStream;
});

/// Provider for latest sensor readings (legacy compatibility).
final latestSensorReadingsProvider = FutureProvider<List<SensorData>>((ref) async {
  final sensorRepository = ref.read(sensorRepositoryProvider);
  final result = await sensorRepository.getLatestReadings();

  return result.when(
    success: (data) => data,
    failure: (error) {
      Logger.error(
        'Failed to get latest sensor readings: $error',
        tag: 'SystemProviders',
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
            tag: 'SystemProviders',
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