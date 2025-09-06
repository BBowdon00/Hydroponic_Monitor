import 'dart:async';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device.dart';
import '../mqtt/mqtt_service.dart';
import '../influx/influx_service.dart';

/// Unified service for managing all data sources and providing consolidated streams.
/// This service orchestrates MQTT and InfluxDB services and provides a single
/// point of access for data operations.
class DataService {
  DataService({
    required this.mqttService,
    required this.influxService,
  });

  final MqttService mqttService;
  final InfluxDbService influxService;

  // Connection status tracking
  final StreamController<ConnectionState> _connectionController =
      StreamController<ConnectionState>.broadcast();
  ConnectionState _currentConnectionState = const ConnectionState();

  StreamSubscription<String>? _mqttConnectionSubscription;
  StreamSubscription<String>? _influxConnectionSubscription;

  bool _isInitialized = false;
  final Completer<void> _initializationCompleter = Completer<void>();

  /// Stream of connection state changes for all services.
  Stream<ConnectionState> get connectionStream => _connectionController.stream;

  /// Current connection state.
  ConnectionState get connectionState => _currentConnectionState;

  /// Stream of real-time sensor data from MQTT.
  Stream<SensorData> get sensorDataStream => mqttService.sensorDataStream;

  /// Stream of device status updates from MQTT.
  Stream<Device> get deviceStatusStream => mqttService.deviceStatusStream;

  /// Check if the data service is initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize all data services and set up connection monitoring.
  Future<Result<void>> initialize() async {
    if (_isInitialized) {
      Logger.debug('DataService already initialized', tag: 'DataService');
      return const Success(null);
    }

    try {
      Logger.info('Initializing unified data service', tag: 'DataService');

      // Set up connection monitoring first
      _setupConnectionMonitoring();

      // Initialize MQTT service
      final mqttResult = await mqttService.connect();
      if (mqttResult is Failure) {
        Logger.warning(
          'MQTT initialization failed: ${mqttResult.error}',
          tag: 'DataService',
        );
        // Continue with InfluxDB even if MQTT fails
      } else {
        Logger.info('MQTT service initialized successfully', tag: 'DataService');
      }

      // Initialize InfluxDB service
      final influxResult = await influxService.initialize();
      if (influxResult is Failure) {
        Logger.warning(
          'InfluxDB initialization failed: ${influxResult.error}',
          tag: 'DataService',
        );
        // Continue even if InfluxDB fails (allows read-only mode)
      } else {
        Logger.info('InfluxDB service initialized successfully', tag: 'DataService');
      }

      _isInitialized = true;
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }

      Logger.info('DataService initialization completed', tag: 'DataService');
      return const Success(null);
    } catch (e) {
      final error = 'Error initializing data service: $e';
      Logger.error(error, tag: 'DataService', error: e);
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.completeError(e);
      }
      return Failure(UnknownError(error));
    }
  }

  /// Ensure the data service is initialized.
  Future<void> ensureInitialized({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isInitialized) return;
    
    try {
      await _initializationCompleter.future.timeout(timeout);
    } catch (e) {
      Logger.warning(
        'DataService initialization timeout or error: $e',
        tag: 'DataService',
      );
      // Continue execution to avoid blocking the app
    }
  }

  /// Set up monitoring for connection state changes.
  void _setupConnectionMonitoring() {
    // Monitor MQTT connection
    _mqttConnectionSubscription = mqttService.connectionStream.listen(
      (status) => _updateMqttConnectionState(status),
      onError: (error) {
        Logger.error('Error in MQTT connection stream: $error', tag: 'DataService');
        _updateMqttConnectionState('disconnected');
      },
    );

    // Monitor InfluxDB connection
    _influxConnectionSubscription = influxService.connectionStream.listen(
      (status) => _updateInfluxConnectionState(status),
      onError: (error) {
        Logger.error('Error in InfluxDB connection stream: $error', tag: 'DataService');
        _updateInfluxConnectionState('disconnected');
      },
    );
  }

  void _updateMqttConnectionState(String status) {
    final isConnected = status == 'connected' || status == 'reconnected';
    final now = DateTime.now();

    _currentConnectionState = _currentConnectionState.copyWith(
      mqttConnected: isConnected,
      mqttDisconnectedSince: isConnected ? null : 
          (_currentConnectionState.mqttDisconnectedSince ?? now),
    );

    _connectionController.add(_currentConnectionState);
    Logger.debug('MQTT connection state updated: $status', tag: 'DataService');
  }

  void _updateInfluxConnectionState(String status) {
    final isConnected = status == 'connected';
    final now = DateTime.now();

    _currentConnectionState = _currentConnectionState.copyWith(
      influxConnected: isConnected,
      influxDisconnectedSince: isConnected ? null : 
          (_currentConnectionState.influxDisconnectedSince ?? now),
    );

    _connectionController.add(_currentConnectionState);
    Logger.debug('InfluxDB connection state updated: $status', tag: 'DataService');
  }

  /// Get historical sensor data from InfluxDB.
  Future<Result<List<SensorData>>> getHistoricalSensorData({
    SensorType? sensorType,
    String? sensorId,
    String? deviceId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    return influxService.querySensorData(
      sensorType: sensorType,
      sensorId: sensorId,
      deviceId: deviceId,
      start: start,
      end: end,
      limit: limit,
    );
  }

  /// Get latest sensor readings from InfluxDB.
  Future<Result<List<SensorData>>> getLatestSensorReadings() async {
    return influxService.queryLatestSensorData();
  }

  /// Send a command to control a device via MQTT.
  Future<Result<void>> sendDeviceCommand(
    String deviceId,
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    Logger.info(
      'Sending device command via DataService: $deviceId -> $command',
      tag: 'DataService',
    );
    
    return mqttService.publishDeviceCommand(
      deviceId,
      command,
      parameters: parameters,
    );
  }

  /// Dispose of all resources.
  Future<void> dispose() async {
    try {
      Logger.info('Disposing DataService', tag: 'DataService');

      await _mqttConnectionSubscription?.cancel();
      await _influxConnectionSubscription?.cancel();

      await mqttService.disconnect();
      await influxService.close();

      if (!_connectionController.isClosed) {
        await _connectionController.close();
      }
    } catch (e) {
      Logger.error('Error disposing DataService: $e', tag: 'DataService', error: e);
    }
  }
}

/// Represents the connection state of all data services.
class ConnectionState {
  const ConnectionState({
    this.mqttConnected = false,
    this.influxConnected = false,
    this.mqttDisconnectedSince,
    this.influxDisconnectedSince,
  });

  final bool mqttConnected;
  final bool influxConnected;
  final DateTime? mqttDisconnectedSince;
  final DateTime? influxDisconnectedSince;

  /// True if at least one service is disconnected.
  bool get hasDisconnections => !mqttConnected || !influxConnected;

  /// True if all services are connected.
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

  ConnectionState copyWith({
    bool? mqttConnected,
    bool? influxConnected,
    DateTime? mqttDisconnectedSince,
    DateTime? influxDisconnectedSince,
  }) {
    return ConnectionState(
      mqttConnected: mqttConnected ?? this.mqttConnected,
      influxConnected: influxConnected ?? this.influxConnected,
      mqttDisconnectedSince: mqttDisconnectedSince ?? this.mqttDisconnectedSince,
      influxDisconnectedSince: influxDisconnectedSince ?? this.influxDisconnectedSince,
    );
  }

  @override
  String toString() {
    return 'ConnectionState(mqtt: $mqttConnected, influx: $influxConnected)';
  }
}