import 'dart:async';
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

// =============================================================================
// SENSOR AGGREGATION MODELS (consolidated from sensor_aggregation_providers.dart)
// =============================================================================

/// Model for aggregated sensor readings by device/sensor type.
class SensorReading {
  const SensorReading({
    required this.sensorType,
    required this.deviceId,
    required this.deviceNode,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.location,
  });

  final SensorType sensorType;
  final String deviceId;
  final String deviceNode;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String? location;

  /// Unique key for this sensor reading (deviceNode + sensorType + deviceId)
  String get key => '${deviceNode}_${sensorType.name}_$deviceId';

  SensorReading copyWith({
    SensorType? sensorType,
    String? deviceId,
    String? deviceNode,
    double? value,
    String? unit,
    DateTime? timestamp,
    String? location,
  }) {
    return SensorReading(
      sensorType: sensorType ?? this.sensorType,
      deviceId: deviceId ?? this.deviceId,
      deviceNode: deviceNode ?? this.deviceNode,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
    );
  }
}

/// State for managing current sensor readings.
class SensorAggregationState {
  const SensorAggregationState({this.readings = const {}, this.lastUpdate});

  final Map<String, SensorReading> readings;
  final DateTime? lastUpdate;

  SensorAggregationState copyWith({
    Map<String, SensorReading>? readings,
    DateTime? lastUpdate,
  }) {
    return SensorAggregationState(
      readings: readings ?? this.readings,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// Get the latest reading for a specific sensor type.
  SensorReading? getLatestReading(SensorType sensorType) {
    final matchingReadings = readings.values
        .where((reading) => reading.sensorType == sensorType)
        .toList();

    if (matchingReadings.isEmpty) return null;

    // Return the most recent reading
    matchingReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matchingReadings.first;
  }

  /// Get all readings for a specific device node.
  List<SensorReading> getReadingsForNode(String deviceNode) {
    return readings.values
        .where((reading) => reading.deviceNode == deviceNode)
        .toList();
  }
}

// =============================================================================
// SERVICE AND REPOSITORY PROVIDERS
// =============================================================================

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

// =============================================================================
// CONSOLIDATED SENSOR AGGREGATION (replaces sensor_aggregation_providers.dart)
// =============================================================================

/// Provider for aggregating and managing current sensor readings.
/// This replaces the previous separate sensor aggregation provider file.
final sensorAggregationProvider =
    StateNotifierProvider<SensorAggregationNotifier, SensorAggregationState>((
      ref,
    ) {
      return SensorAggregationNotifier(ref);
    });

class SensorAggregationNotifier extends StateNotifier<SensorAggregationState> {
  SensorAggregationNotifier(this.ref) : super(const SensorAggregationState()) {
    _initialize();
  }

  final Ref ref;
  StreamSubscription<SensorData>? _sensorSubscription;

  void _initialize() {
    Logger.info(
      'Initializing consolidated sensor aggregation provider',
      tag: 'DataProviders',
    );

    // Ensure data services are initialized
    ref.listen(dataServicesInitializationProvider, (_, __) {
      _setupSensorSubscription();
    });
    
    // Try to setup subscription immediately if services are ready
    _setupSensorSubscription();
  }

  void _setupSensorSubscription() {
    try {
      // Cancel existing subscription
      _sensorSubscription?.cancel();
      
      final sensorRepository = ref.read(sensorRepositoryProvider);
      
      // Listen to real-time sensor data stream directly from repository
      _sensorSubscription = sensorRepository.realTimeSensorData.listen(
        _onSensorData,
        onError: (error) {
          Logger.error(
            'Error in sensor data stream: $error',
            tag: 'DataProviders',
          );
        },
      );
      
      Logger.debug('Sensor subscription established', tag: 'DataProviders');
    } catch (e) {
      Logger.warning(
        'Could not setup sensor subscription: $e',
        tag: 'DataProviders',
      );
    }
  }

  void _onSensorData(SensorData sensorData) {
    // Extract device node from sensor data
    final deviceParts = sensorData.deviceId?.split('_') ?? ['unknown'];
    final deviceNode = deviceParts.isNotEmpty ? deviceParts[0] : 'unknown';

    final reading = SensorReading(
      sensorType: sensorData.sensorType,
      deviceId: sensorData.deviceId ?? 'unknown',
      deviceNode: deviceNode,
      value: sensorData.value,
      unit: sensorData.unit,
      timestamp: sensorData.timestamp,
      location: sensorData.location,
    );

    _updateReading(reading);
  }

  void _updateReading(SensorReading reading) {
    final newReadings = Map<String, SensorReading>.from(state.readings);
    newReadings[reading.key] = reading;

    state = state.copyWith(readings: newReadings, lastUpdate: DateTime.now());

    Logger.debug(
      'Updated sensor reading: ${reading.sensorType.name} = ${reading.value}${reading.unit}',
      tag: 'DataProviders',
    );
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }
}

// =============================================================================
// STREAM AND STATUS PROVIDERS  
// =============================================================================

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

/// Consolidated connection status provider.
/// This replaces the previous separate connection_status_provider.dart.
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

// =============================================================================
// SENSOR DATA PROVIDERS (using consolidated aggregation)
// =============================================================================

/// Provider for getting the latest reading of a specific sensor type.
final latestSensorReadingProvider = Provider.family<SensorReading?, SensorType>(
  (ref, sensorType) {
    final aggregationState = ref.watch(sensorAggregationProvider);
    return aggregationState.getLatestReading(sensorType);
  },
);

/// Provider for checking if sensor data is available (not waiting).
final hasSensorDataProvider = Provider<bool>((ref) {
  final aggregationState = ref.watch(sensorAggregationProvider);
  return aggregationState.readings.isNotEmpty;
});

/// Provider for getting all current sensor readings.
final currentSensorReadingsProvider = Provider<List<SensorReading>>((ref) {
  final aggregationState = ref.watch(sensorAggregationProvider);
  return aggregationState.readings.values.toList();
});

/// Provider for real-time sensor data stream (for backward compatibility).
final realTimeSensorDataProvider = StreamProvider<SensorData>((ref) {
  // Ensure data services (repositories, subscriptions) are initialized first.
  ref.watch(dataServicesInitializationProvider);

  final sensorRepository = ref.read(sensorRepositoryProvider);
  return sensorRepository.realTimeSensorData;
});

// =============================================================================
// HISTORICAL DATA PROVIDERS
// =============================================================================

/// Provider for latest sensor readings from InfluxDB.
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

// =============================================================================
// RESULT EXTENSION UTILITY
// =============================================================================

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
