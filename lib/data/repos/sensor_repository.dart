import 'dart:async';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/sensor_data.dart';
import '../services/data_service.dart';

/// Repository for sensor data operations and business logic.
/// Provides sensor data access, validation, and aggregation functionality.
class SensorRepository {
  SensorRepository({required this.dataService});

  final DataService dataService;

  // Cache for latest sensor readings by type
  final Map<SensorType, SensorData> _latestReadingsByType = {};
  final StreamController<Map<SensorType, SensorData>> _latestReadingsController =
      StreamController<Map<SensorType, SensorData>>.broadcast();

  StreamSubscription<SensorData>? _sensorDataSubscription;

  /// Initialize the repository and start processing sensor data.
  Future<Result<void>> initialize() async {
    try {
      Logger.info('Initializing sensor repository', tag: 'SensorRepository');

      // Ensure data service is ready
      await dataService.ensureInitialized();

      // Subscribe to real-time sensor data for caching and processing
      _sensorDataSubscription = dataService.sensorDataStream.listen(
        _processSensorData,
        onError: (e) {
          Logger.error(
            'Error processing sensor data: $e',
            tag: 'SensorRepository',
            error: e,
          );
        },
      );

      Logger.info(
        'Sensor repository initialized successfully',
        tag: 'SensorRepository',
      );
      return const Success(null);
    } catch (e) {
      final error = 'Error initializing sensor repository: $e';
      Logger.error(error, tag: 'SensorRepository', error: e);
      return Failure(UnknownError(error));
    }
  }

  /// Process incoming sensor data for caching and validation.
  void _processSensorData(SensorData sensorData) {
    try {
      Logger.debug(
        'Processing sensor data: ${sensorData.sensorType} = ${sensorData.value}',
        tag: 'SensorRepository',
      );

      // Validate sensor data
      if (_isValidSensorData(sensorData)) {
        // Update cache with latest reading
        _latestReadingsByType[sensorData.sensorType] = sensorData;

        // Emit updated latest readings
        _latestReadingsController.add(Map.from(_latestReadingsByType));
      } else {
        Logger.warning(
          'Invalid sensor data received: ${sensorData.id}',
          tag: 'SensorRepository',
        );
      }
    } catch (e) {
      Logger.error(
        'Error processing sensor data: $e',
        tag: 'SensorRepository',
        error: e,
      );
    }
  }

  /// Validate sensor data based on business rules.
  bool _isValidSensorData(SensorData data) {
    // Check for reasonable value ranges based on sensor type
    switch (data.sensorType) {
      case SensorType.temperature:
        return data.value >= -50.0 && data.value <= 80.0;
      case SensorType.humidity:
        return data.value >= 0.0 && data.value <= 100.0;
      case SensorType.pH:
        return data.value >= 0.0 && data.value <= 14.0;
      case SensorType.waterLevel:
        return data.value >= 0.0 && data.value <= 100.0;
      case SensorType.electricalConductivity:
        return data.value >= 0.0 && data.value <= 5000.0;
      case SensorType.lightIntensity:
        return data.value >= 0.0 && data.value <= 100000.0;
      case SensorType.airQuality:
        return data.value >= 0.0 && data.value <= 5000.0;
      case SensorType.powerUsage:
        return data.value >= 0.0 && data.value <= 10000.0;
    }
  }

  /// Get real-time sensor data stream.
  Stream<SensorData> get realTimeSensorData => dataService.sensorDataStream;

  /// Stream of latest sensor readings by type.
  Stream<Map<SensorType, SensorData>> get latestReadingsByType => _latestReadingsController.stream;

  /// Get the latest reading for a specific sensor type.
  SensorData? getLatestReading(SensorType sensorType) {
    return _latestReadingsByType[sensorType];
  }

  /// Get historical sensor data from InfluxDB.
  Future<Result<List<SensorData>>> getHistoricalData({
    SensorType? sensorType,
    String? sensorId,
    String? deviceId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    return dataService.getHistoricalSensorData(
      sensorType: sensorType,
      sensorId: sensorId,
      deviceId: deviceId,
      start: start,
      end: end,
      limit: limit,
    );
  }

  /// Get latest sensor readings for all sensors.
  Future<Result<List<SensorData>>> getLatestReadings() async {
    return dataService.getLatestSensorReadings();
  }

  /// Get sensor data for a specific sensor type over time.
  Future<Result<List<SensorData>>> getSensorTypeHistory(
    SensorType sensorType, {
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    return dataService.getHistoricalSensorData(
      sensorType: sensorType,
      start: start ?? DateTime.now().subtract(const Duration(hours: 24)),
      end: end ?? DateTime.now(),
      limit: limit ?? 100,
    );
  }

  /// Get aggregated sensor readings for dashboard display.
  Map<SensorType, SensorData> getLatestReadingsByType() {
    return Map.from(_latestReadingsByType);
  }

  /// Calculate average value for a sensor type over time.
  Future<Result<double?>> getAverageValue(
    SensorType sensorType, {
    Duration period = const Duration(hours: 1),
  }) async {
    try {
      final end = DateTime.now();
      final start = end.subtract(period);

      final result = await getSensorTypeHistory(
        sensorType,
        start: start,
        end: end,
        limit: 100,
      );

      if (result is Success<List<SensorData>>) {
        final data = (result as Success<List<SensorData>>).data;
        if (data.isEmpty) return const Success(null);
        
        final sum = data.fold<double>(0.0, (sum, reading) => sum + reading.value);
        final average = sum / data.length;
        return Success(average);
      } else {
        return result as Failure<double?>;
      }
    } catch (e) {
      final error = 'Error calculating average value: $e';
      Logger.error(error, tag: 'SensorRepository', error: e);
      return Failure(UnknownError(error));
    }
  }

  /// Check if sensor readings are within acceptable ranges.
  bool isSensorReadingNormal(SensorType sensorType, double value) {
    return _isValidSensorData(
      SensorData(
        id: 'validation',
        sensorType: sensorType,
        value: value,
        unit: sensorType.defaultUnit,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    try {
      Logger.info('Disposing sensor repository', tag: 'SensorRepository');
      await _sensorDataSubscription?.cancel();
      if (!_latestReadingsController.isClosed) {
        await _latestReadingsController.close();
      }
    } catch (e) {
      Logger.error(
        'Error disposing sensor repository: $e',
        tag: 'SensorRepository',
        error: e,
      );
    }
  }
}

