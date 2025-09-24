import 'dart:async';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/data/repos/device_repository.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';

/// Mock device repository for testing.
class MockDeviceRepository implements DeviceRepository {
  bool _initializationResult = true;
  bool _commandResult = true;
  Map<String, dynamic>? _lastCommand;
  final StreamController<Device> _deviceStatusController = 
      StreamController<Device>.broadcast();

  @override
  Stream<Device> get deviceStatusUpdates => _deviceStatusController.stream;

  /// Get the last command sent for testing.
  Map<String, dynamic>? get lastCommand => _lastCommand;

  /// Set whether commands should succeed or fail.
  void setCommandResult(bool success) {
    _commandResult = success;
  }

  /// Set whether initialization should succeed or fail.
  void setInitializationResult(bool success) {
    _initializationResult = success;
  }

  /// Emit a device status update for testing.
  void emitDeviceStatus(Device device) {
    _deviceStatusController.add(device);
  }

  @override
  Future<Result<void>> initialize() async {
    await Future.delayed(const Duration(milliseconds: 10)); // Simulate delay
    return _initializationResult 
        ? const Success(null)
        : const Failure(UnknownError('Mock initialization failure'));
  }

  @override
  Future<Result<void>> ensureInitialized({Duration timeout = const Duration(seconds: 5)}) async {
    return initialize();
  }

  @override
  Future<Result<void>> controlDevice(
    String deviceId,
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    _lastCommand = {
      'deviceId': deviceId,
      'command': command,
      'parameters': parameters ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await Future.delayed(const Duration(milliseconds: 10)); // Simulate delay
    
    return _commandResult
        ? const Success(null)
        : const Failure(UnknownError('Mock command failure'));
  }

  @override
  Future<Result<void>> turnOnDevice(String deviceId) {
    return controlDevice(deviceId, 'turn_on');
  }

  @override
  Future<Result<void>> turnOffDevice(String deviceId) {
    return controlDevice(deviceId, 'turn_off');
  }

  @override
  Future<Result<void>> setDevicePower(String deviceId, double powerLevel) {
    return controlDevice(deviceId, 'set_power', parameters: {'power_level': powerLevel});
  }

  @override
  Future<Result<void>> setTemperature(String deviceId, double temperature) {
    return controlDevice(deviceId, 'set_temperature', parameters: {'target_temperature': temperature});
  }

  @override
  Future<Result<void>> setFanSpeed(String deviceId, double speed) {
    return controlDevice(deviceId, 'set_fan_speed', parameters: {'speed': speed});
  }

  @override
  Future<Result<void>> startPump(String deviceId, {double? flowRate}) {
    final parameters = flowRate != null ? {'flow_rate': flowRate} : null;
    return controlDevice(deviceId, 'start_pump', parameters: parameters);
  }

  @override
  Future<Result<void>> stopPump(String deviceId) {
    return controlDevice(deviceId, 'stop_pump');
  }

  @override
  Future<Result<void>> setLightSettings(
    String deviceId, {
    double? brightness,
    String? color,
    bool? enabled,
  }) {
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

  @override
  Future<Result<void>> emergencyStopAll() {
    return controlDevice('*', 'emergency_stop');
  }

  @override
  Future<Result<void>> requestDeviceStatus(String deviceId) {
    return controlDevice(deviceId, 'get_status');
  }

  @override
  Future<Result<void>> requestAllDeviceStatus() {
    return controlDevice('*', 'get_status');
  }

  @override
  Future<void> dispose() async {
    await _deviceStatusController.close();
  }
}