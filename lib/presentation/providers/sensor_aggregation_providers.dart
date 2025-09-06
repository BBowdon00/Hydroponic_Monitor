import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/sensor_data.dart';
import '../../core/logger.dart';
import 'system_providers.dart';

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

/// Provider for aggregating sensor readings from the repository.
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
  ProviderSubscription? _sensorReadingsSubscription;

  void _initialize() {
    Logger.info(
      'Initializing sensor aggregation provider',
      tag: 'SensorAggregation',
    );

    // Listen to latest sensor readings by type from repository
    _sensorReadingsSubscription = ref.listen(latestSensorReadingsByTypeProvider, (
      previous,
      next,
    ) {
      _onSensorReadingsUpdate(next);
    });
  }

  void _onSensorReadingsUpdate(AsyncValue<Map<SensorType, SensorData>> asyncData) {
    asyncData.when(
      data: (sensorDataByType) {
        final newReadings = <String, SensorReading>{};

        for (final sensorData in sensorDataByType.values) {
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

          newReadings[reading.key] = reading;
        }

        state = state.copyWith(
          readings: newReadings,
          lastUpdate: DateTime.now(),
        );

        Logger.debug(
          'Updated sensor aggregation with ${newReadings.length} readings',
          tag: 'SensorAggregation',
        );
      },
      loading: () {
        // Handle loading state if needed
      },
      error: (error, stackTrace) {
        Logger.error(
          'Error processing sensor readings: $error',
          tag: 'SensorAggregation',
        );
      },
    );
  }

  @override
  void dispose() {
    _sensorReadingsSubscription?.close();
    super.dispose();
  }
}

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
