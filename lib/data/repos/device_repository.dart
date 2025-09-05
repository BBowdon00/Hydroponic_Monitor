import 'dart:async';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/device.dart';
import '../mqtt/mqtt_service.dart';

/// Repository for managing device control and status via MQTT.
class DeviceRepository {
  DeviceRepository({required this.mqttService});

  final MqttService mqttService;

  StreamSubscription<Device>? _mqttSubscription;

  /// Initialize the repository and start listening to device status updates.
  Future<Result<void>> initialize() async {
    try {
      Logger.info('Initializing device repository', tag: 'DeviceRepository');

      // Start listening to device status updates from MQTT so we can log
      // and perform any repository-level processing if needed.
      _mqttSubscription = mqttService.deviceStatusStream.listen(
        (device) {
          Logger.debug(
            'Received device status update: ${device.id}',
            tag: 'DeviceRepository',
          );
          // No internal buffering here; expose mqttService stream directly
          // via the public getter so subscribers receive buffered items.
        },
        onError: (error) {
          Logger.error(
            'Error in MQTT device status stream: $error',
            tag: 'DeviceRepository',
          );
        },
      );

      Logger.info(
        'Device repository initialized successfully',
        tag: 'DeviceRepository',
      );
      return const Success(null);
    } catch (e) {
      final error = 'Error initializing device repository: $e';
      Logger.error(error, tag: 'DeviceRepository', error: e);
      return Failure(UnknownError(error));
    }
  }

  /// Ensure repository and underlying services are initialized.
  Future<Result<void>> ensureInitialized({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await mqttService.ensureInitialized(timeout: timeout);
      return const Success(null);
    } catch (e) {
      final error = 'Error ensuring device repository initialized: $e';
      Logger.warning(error, tag: 'DeviceRepository');
      return Failure(UnknownError(error));
    }
  }

  /// Get real-time device status updates from MQTT.
  Stream<Device> get deviceStatusUpdates => mqttService.deviceStatusStream;

  /// Send a command to control a device.
  Future<Result<void>> controlDevice(
    String deviceId,
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    Logger.info(
      'Sending command to device $deviceId: $command',
      tag: 'DeviceRepository',
    );
    return mqttService.publishDeviceCommand(
      deviceId,
      command,
      parameters: parameters,
    );
  }

  /// Turn a device on.
  Future<Result<void>> turnOnDevice(String deviceId) async {
    return controlDevice(deviceId, 'turn_on');
  }

  /// Turn a device off.
  Future<Result<void>> turnOffDevice(String deviceId) async {
    return controlDevice(deviceId, 'turn_off');
  }

  /// Set device power level (for devices that support variable power).
  Future<Result<void>> setDevicePower(
    String deviceId,
    double powerLevel,
  ) async {
    return controlDevice(
      deviceId,
      'set_power',
      parameters: {'power_level': powerLevel},
    );
  }

  /// Set temperature for heating devices.
  Future<Result<void>> setTemperature(
    String deviceId,
    double temperature,
  ) async {
    return controlDevice(
      deviceId,
      'set_temperature',
      parameters: {'target_temperature': temperature},
    );
  }

  /// Set fan speed for ventilation devices.
  Future<Result<void>> setFanSpeed(String deviceId, double speed) async {
    return controlDevice(
      deviceId,
      'set_fan_speed',
      parameters: {'speed': speed},
    );
  }

  /// Start a pump with specified flow rate.
  Future<Result<void>> startPump(String deviceId, {double? flowRate}) async {
    final parameters = flowRate != null ? {'flow_rate': flowRate} : null;
    return controlDevice(deviceId, 'start_pump', parameters: parameters);
  }

  /// Stop a pump.
  Future<Result<void>> stopPump(String deviceId) async {
    return controlDevice(deviceId, 'stop_pump');
  }

  /// Set light brightness and color (if supported).
  Future<Result<void>> setLightSettings(
    String deviceId, {
    double? brightness,
    String? color,
    bool? enabled,
  }) async {
    final parameters = <String, dynamic>{};
    if (brightness != null) parameters['brightness'] = brightness;
    if (color != null) parameters['color'] = color;
    if (enabled != null) parameters['enabled'] = enabled;

    return controlDevice(
      deviceId,
      'set_light',
      parameters: parameters.isNotEmpty ? parameters : null,
    );
  }

  /// Emergency stop all devices.
  Future<Result<void>> emergencyStopAll() async {
    Logger.warning(
      'Emergency stop all devices initiated',
      tag: 'DeviceRepository',
    );
    return controlDevice('*', 'emergency_stop');
  }

  /// Request status update for a specific device.
  Future<Result<void>> requestDeviceStatus(String deviceId) async {
    return controlDevice(deviceId, 'get_status');
  }

  /// Request status update for all devices.
  Future<Result<void>> requestAllDeviceStatus() async {
    return controlDevice('*', 'get_status');
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    try {
      Logger.info('Disposing device repository', tag: 'DeviceRepository');
      await _mqttSubscription?.cancel();
      // No internal controller to close.
    } catch (e) {
      Logger.error(
        'Error disposing device repository: $e',
        tag: 'DeviceRepository',
        error: e,
      );
    }
  }
}
