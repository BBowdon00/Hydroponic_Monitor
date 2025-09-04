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
    host: Env.mqttHost,
    port: Env.mqttPort,
    clientId: 'hydroponic_monitor_${DateTime.now().millisecondsSinceEpoch}',
    username: Env.mqttUsername.isNotEmpty ? Env.mqttUsername : null,
    password: Env.mqttPassword.isNotEmpty ? Env.mqttPassword : null,
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
    Logger.info('Initializing data services', tag: 'DataProviders');

    final sensorRepository = ref.read(sensorRepositoryProvider);
    final deviceRepository = ref.read(deviceRepositoryProvider);

    // Initialize repositories with error handling
    try {
      final sensorResult = await sensorRepository.initialize();
      if (sensorResult is Failure) {
        Logger.error(
          'Failed to initialize sensor repository: ${sensorResult.error}',
          tag: 'DataProviders',
        );
        throw sensorResult.error;
      }
    } catch (e) {
      Logger.error(
        'Exception during sensor repository initialization: $e',
        tag: 'DataProviders',
        error: e,
      );
      throw NotInitializedError('Sensor repository initialization failed: $e');
    }

    try {
      final deviceResult = await deviceRepository.initialize();
      if (deviceResult is Failure) {
        Logger.error(
          'Failed to initialize device repository: ${deviceResult.error}',
          tag: 'DataProviders',
        );
        throw deviceResult.error;
      }
    } catch (e) {
      Logger.error(
        'Exception during device repository initialization: $e',
        tag: 'DataProviders',
        error: e,
      );
      throw NotInitializedError('Device repository initialization failed: $e');
    }

    Logger.info('Data services initialized successfully', tag: 'DataProviders');
  } catch (e) {
    Logger.error(
      'Error initializing data services: $e',
      tag: 'DataProviders',
      error: e,
    );
    
    // Wrap unknown errors in NotInitializedError for consistency
    if (e is! AppError) {
      throw NotInitializedError('Data services initialization failed: $e');
    }
    rethrow;
  }
});

/// Provider for real-time sensor data stream.
final realTimeSensorDataProvider = StreamProvider<SensorData>((ref) {
  final sensorRepository = ref.read(sensorRepositoryProvider);
  return sensorRepository.realTimeSensorData;
});

/// Provider for device status updates stream.
final deviceStatusUpdatesProvider = StreamProvider<Device>((ref) {
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
