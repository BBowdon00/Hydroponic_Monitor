import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/mqtt/mqtt_service.dart';
import '../../data/influx/influx_service.dart';
import '../../data/repos/sensor_repository.dart';
import '../../data/repos/device_repository.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device.dart';
import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../core/env.dart';
import 'config_provider.dart';

/// Provider for MQTT service configuration.
final mqttServiceProvider = Provider<MqttService>((ref) {
  final configAsync = ref.watch(configProvider);
  final previousState = _cachedMqttSnapshot;

  // Helper: derive effective port based on platform when user supplies a "default" opposite-port.
  int _effectivePort(int rawPort) {
    // Desired behavior:
    //   - On web (websocket): prefer 9001. If config/raw gives 1883 (typical TCP port) or 0, coerce to 9001.
    //   - On non-web: prefer 1883. If config/raw gives 9001 (websocket port) or 0, coerce to 1883.
    if (kIsWeb) {
      if (rawPort == 0 || rawPort == 1883) return 9001;
      return rawPort;
    } else {
      if (rawPort == 0 || rawPort == 9001) return 1883;
      return rawPort;
    }
  }

  // Provider suspends until config is ready (no placeholder service)
  final cfg = configAsync.requireValue.mqtt;
  final newHost = cfg.host;
  final newPort = _effectivePort(cfg.port);
  final newUsername = cfg.username.trim().isEmpty
      ? null
      : cfg.username.trim();
  final newPassword = cfg.password.trim().isEmpty
      ? null
      : cfg.password.trim();

  // Reuse existing service if config unchanged.
  if (previousState != null &&
      previousState.host == newHost &&
      previousState.port == newPort &&
      previousState.username == newUsername &&
      previousState.password == newPassword) {
    Logger.debug(
      'MQTT provider reuse: rawHost=$newHost rawPort=${cfg.port} effectivePort=$newPort (web=$kIsWeb)',
      tag: 'DataProviders',
    );
    return previousState.service;
  }

  Logger.info(
    'MQTT provider creating new service: rawHost=$newHost rawPort=${cfg.port} effectivePort=$newPort (web=$kIsWeb)',
    tag: 'DataProviders',
  );

  final service = MqttService(
    host: newHost,
    port: newPort,
    clientId: _stableClientId,
    username: newUsername,
    password: newPassword,
    autoReconnect: !Env.isTest,
  );

  // Dispose old service asynchronously (do not await) so any pending reconnect logic stops.
  if (previousState?.service != null) {
    () async {
      try {
        previousState!.service.retire();
        await previousState.service.dispose();
      } catch (_) {}
    }();
  }

  _cachedMqttSnapshot = _MqttConfigSnapshot(
    host: newHost,
    port: newPort,
    username: newUsername,
    password: newPassword,
    service: service,
  );

  // Ensure service is disconnected when provider is disposed (e.g., during hot reload/tests teardown)
  ref.onDispose(() async {
    if (_cachedMqttSnapshot?.service == service) {
      try {
        await service.disconnect();
      } catch (_) {}
    }
  });

  return service;
});

// Stable client identifier for the app lifecycle.
const String _stableClientId = 'hydroponic_monitor_client';

// Internal snapshot to compare config fields and retain service.
class _MqttConfigSnapshot {
  _MqttConfigSnapshot({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.service,
  });
  final String host;
  final int port;
  final String? username;
  final String? password;
  final MqttService service;
}

// Module-level cached snapshot (not a provider) to avoid mutating provider state during build.
_MqttConfigSnapshot? _cachedMqttSnapshot;

/// Provider that performs the initial MQTT connection after config is ready.
/// This eliminates duplicate connects and ensures proper ordering.
final mqttConnectionProvider = FutureProvider<void>((ref) async {
  // 1. Wait for runtime config (eliminates placeholder service churn)
  final configAsync = ref.watch(configProvider);
  if (!configAsync.hasValue) {
    throw Exception('Config not ready');
  }
  
  // 2. Acquire service (built with final config)
  final service = ref.watch(mqttServiceProvider);
  
  // 3. Connect once
  final sw = Stopwatch()..start();
  final attempt = service.incrementAttempt();
  final result = await service.connect();
  
  result.when(
    success: (_) => Logger.info(
      'MQTT connected (attempt=$attempt, ms=${sw.elapsedMilliseconds})',
      tag: 'MQTT',
    ),
    failure: (e) => Logger.error(
      'MQTT connect failed (attempt=$attempt): $e',
      tag: 'MQTT',
    ),
  );
});

/// Provider for InfluxDB service configuration.
final influxServiceProvider = Provider<InfluxDbService>((ref) {
  final configAsync = ref.watch(configProvider);
  
  // Provider suspends until config is ready (no fallback to env vars)
  final cfg = configAsync.requireValue.influx;

  final service = InfluxDbService(
    url: InfluxDbService.normalizeUrl(cfg.url),
    token: cfg.token,
    organization: cfg.org,
    bucket: cfg.bucket,
  );

  ref.onDispose(() async {
    try {
      await service.close();
    } catch (_) {}
  });

  return service;
});

/// Provider that performs the initial InfluxDB connection after config is ready.
/// This eliminates duplicate connects and ensures proper ordering.
final influxConnectionProvider = FutureProvider<void>((ref) async {
  // 1. Wait for runtime config (eliminates early initialization)
  final configAsync = ref.watch(configProvider);
  if (!configAsync.hasValue) {
    throw Exception('Config not ready');
  }
  
  // 2. Acquire service (built with final config)
  final service = ref.watch(influxServiceProvider);
  
  // 3. Initialize once
  final sw = Stopwatch()..start();
  final attempt = service.incrementAttempt();
  final result = await service.initialize();
  
  result.when(
    success: (_) => Logger.info(
      'InfluxDB connected (attempt=$attempt, ms=${sw.elapsedMilliseconds})',
      tag: 'InfluxDB',
    ),
    failure: (e) => Logger.error(
      'InfluxDB connect failed (attempt=$attempt): $e',
      tag: 'InfluxDB',
    ),
  );
});

/// Provider for sensor repository.
final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  // Watch services so repository rebuilds when configuration changes recreate them.
  final mqttService = ref.watch(mqttServiceProvider);
  final influxService = ref.watch(influxServiceProvider);
  final repository = SensorRepository(
    mqttService: mqttService,
    influxService: influxService,
  );
  Logger.info(
    'Created SensorRepository instance=${identityHashCode(repository)} (mqttInstance=${identityHashCode(mqttService)})',
    tag: 'DataProviders',
  );
  ref.onDispose(() async {
    Logger.info(
      'Disposing SensorRepository instance=${identityHashCode(repository)}',
      tag: 'DataProviders',
    );
    try {
      await repository.dispose();
    } catch (_) {}
  });
  return repository;
});

/// Provider that ensures sensor repository initialization and provides initialization status.
final sensorRepositoryInitProvider = FutureProvider<SensorRepository>((
  ref,
) async {
  // Await both MQTT and InfluxDB connections (ensures proper ordering)
  try {
    await ref.watch(mqttConnectionProvider.future);
  } catch (e) {
    Logger.warning(
      'MQTT connection failed during init: $e',
      tag: 'DataProviders',
    );
    // Continue in degraded mode
  }
  
  try {
    await ref.watch(influxConnectionProvider.future);
  } catch (e) {
    Logger.warning(
      'InfluxDB connection failed during init: $e',
      tag: 'DataProviders',
    );
    // Continue in degraded mode
  }
  
  // Watch repository so init re-runs on configuration-driven rebuild.
  final repository = ref.watch(sensorRepositoryProvider);

  Logger.info(
    'Starting sensor repository initialization...',
    tag: 'DataProviders',
  );

  // Initialize the repository (services already connected)
  final result = await repository.initialize();

  return result.when(
    success: (_) {
      Logger.info(
        'Sensor repository initialized successfully',
        tag: 'DataProviders',
      );
      return repository;
    },
    failure: (error) {
      Logger.error(
        'Failed to initialize sensor repository: $error',
        tag: 'DataProviders',
      );
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
