import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/sensor_data.dart';
import '../../core/logger.dart';
import 'data_providers.dart';

/// Provider for checking if sensor data is available (not waiting).
final hasSensorDataProvider = Provider<bool>((ref) {
  Logger.info('hasSensorDataProvider accessed', tag: 'SensorProviders');
  // Check if the accumulated real-time sensor data has provided any data
  final realTimeDataByTypeAsync = ref.watch(realTimeSensorDataByTypeProvider);
  return realTimeDataByTypeAsync.when(
    data: (sensorDataByType) => sensorDataByType.isNotEmpty,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider that maintains the latest reading for each sensor type from real-time stream.
/// This accumulates sensor data by type so all sensor types can display current values.
final realTimeSensorDataByTypeProvider =
    StreamProvider<Map<SensorType, SensorData>>((ref) {
      Logger.info(
        'realTimeSensorDataByTypeProvider accessed',
        tag: 'SensorProviders',
      );

      return ref
          .watch(sensorRepositoryInitProvider)
          .when(
            data: (repository) {
              Logger.info(
                'Repository initialized, creating sensor data stream',
                tag: 'SensorProviders',
              );
              final Map<SensorType, SensorData> sensorDataByType = {};

              // Transform the repository stream to accumulate data by type
              return repository.realTimeSensorData.map((sensorData) {
                sensorDataByType[sensorData.sensorType] = sensorData;
                return Map<SensorType, SensorData>.from(sensorDataByType);
              });
            },
            loading: () {
              Logger.info(
                'Repository still loading...',
                tag: 'SensorProviders',
              );
              return const Stream.empty();
            },
            error: (error, stack) {
              Logger.error(
                'Repository initialization failed: $error',
                tag: 'SensorProviders',
              );
              return Stream.error(error, stack);
            },
          );
    });

/// Provider for getting the latest reading of a specific sensor type from real-time stream.
/// This uses the most recent data from the accumulated real-time stream, falling back to historical data.
final latestSensorDataProvider = Provider.family<SensorData?, SensorType>((
  ref,
  sensorType,
) {
  // Get the accumulated real-time data by type
  final realTimeDataByTypeAsync = ref.watch(realTimeSensorDataByTypeProvider);

  return realTimeDataByTypeAsync.when(
    data: (sensorDataByType) {
      // Return the latest data for the requested sensor type
      return sensorDataByType[sensorType];
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
