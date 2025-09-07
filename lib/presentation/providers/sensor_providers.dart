import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/sensor_data.dart';
import '../../core/logger.dart';
import 'data_providers.dart';

/// Provider for checking if sensor data is available (not waiting).
final hasSensorDataProvider = Provider<bool>((ref) {
  // Check if the real-time sensor data stream has provided any data
  final realTimeDataAsync = ref.watch(realTimeSensorDataProvider);
  return realTimeDataAsync.hasValue && !realTimeDataAsync.isLoading;
});

/// Provider for getting the latest reading of a specific sensor type from real-time stream.
/// This uses the most recent data from the real-time stream, falling back to historical data.
final latestSensorDataProvider = Provider.family<SensorData?, SensorType>((
  ref,
  sensorType,
) {
  // Get the most recent data from the real-time stream
  final realTimeDataAsync = ref.watch(realTimeSensorDataProvider);

  return realTimeDataAsync.when(
    data: (sensorData) {
      // Return the data if it matches the requested sensor type
      if (sensorData.sensorType == sensorType) {
        return sensorData;
      }
      // If the real-time data doesn't match, we don't have current data for this type
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for getting historical latest readings for all sensor types.
/// This provides a comprehensive view of the latest data for each sensor type.
final latestSensorReadingsProvider =
    FutureProvider<Map<SensorType, SensorData>>((ref) async {
      final sensorRepository = ref.read(sensorRepositoryProvider);
      final result = await sensorRepository.getLatestReadings();

      return result.when(
        success: (dataList) {
          // Group by sensor type, keeping the most recent reading for each type
          final Map<SensorType, SensorData> latestBySensorType = {};
          for (final data in dataList) {
            final existing = latestBySensorType[data.sensorType];
            if (existing == null ||
                data.timestamp.isAfter(existing.timestamp)) {
              latestBySensorType[data.sensorType] = data;
            }
          }
          return latestBySensorType;
        },
        failure: (error) {
          Logger.error(
            'Failed to get latest sensor readings: $error',
            tag: 'SensorProviders',
          );
          throw Exception('Failed to load sensor data');
        },
      );
    });

/// Provider for getting a specific sensor type's latest data from historical data.
/// This is useful for getting the most recent stored value for a sensor type.
final historicalLatestSensorDataProvider =
    FutureProvider.family<SensorData?, SensorType>((ref, sensorType) async {
      final latestReadings = await ref.watch(
        latestSensorReadingsProvider.future,
      );
      return latestReadings[sensorType];
    });
