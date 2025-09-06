import 'dart:async';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/device.dart';
import '../services/data_service.dart';

/// Repository for device management and business logic.
/// Handles device control commands, status tracking, and device-specific operations.
class DeviceRepository {
  DeviceRepository({required this.dataService});

  final DataService dataService;

  // Device state tracking
  final Map<String, Device> _knownDevices = {};
  final StreamController<Map<String, Device>> _deviceStatesController =
      StreamController<Map<String, Device>>.broadcast();

  StreamSubscription<Device>? _deviceStatusSubscription;

  /// Initialize the repository and start processing device updates.
  Future<Result<void>> initialize() async {
    try {
      Logger.info('Initializing device repository', tag: 'DeviceRepository');

      // Ensure data service is ready
      await dataService.ensureInitialized();

      // Initialize known devices with default states
      _initializeKnownDevices();

      // Subscribe to device status updates
      _deviceStatusSubscription = dataService.deviceStatusStream.listen(
        _processDeviceUpdate,
        onError: (error) {
          Logger.error(
            'Error processing device update: $error',
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

  /// Initialize known devices with default offline states.
  void _initializeKnownDevices() {
    final defaultDevices = [
      Device(
        id: 'rpi_pump_1',
        name: 'Water Pump 1',
        type: DeviceType.pump,
        status: DeviceStatus.offline,
        isEnabled: false,
        lastUpdate: DateTime.now(),
      ),
      Device(
        id: 'rpi_fan_1',
        name: 'Exhaust Fan 1',
        type: DeviceType.fan,
        status: DeviceStatus.offline,
        isEnabled: false,
        lastUpdate: DateTime.now(),
      ),
      Device(
        id: 'rpi_fan_2',
        name: 'Circulation Fan 2',
        type: DeviceType.fan,
        status: DeviceStatus.offline,
        isEnabled: false,
        lastUpdate: DateTime.now(),
      ),
      Device(
        id: 'rpi_light_1',
        name: 'Grow Light 1',
        type: DeviceType.light,
        status: DeviceStatus.offline,
        isEnabled: false,
        lastUpdate: DateTime.now(),
      ),
      Device(
        id: 'rpi_heater_1',
        name: 'Water Heater 1',
        type: DeviceType.heater,
        status: DeviceStatus.offline,
        isEnabled: false,
        lastUpdate: DateTime.now(),
      ),
    ];

    for (final device in defaultDevices) {
      _knownDevices[device.id] = device;
    }

    _deviceStatesController.add(Map.from(_knownDevices));
  }

  /// Process device status updates and apply business logic.
  void _processDeviceUpdate(Device device) {
    try {
      Logger.debug(
        'Processing device update: ${device.id} -> ${device.status}',
        tag: 'DeviceRepository',
      );

      // Update device state
      _knownDevices[device.id] = device;

      // Apply business rules
      _applyDeviceBusinessRules(device);

      // Emit updated device states
      _deviceStatesController.add(Map.from(_knownDevices));
    } catch (e) {
      Logger.error(
        'Error processing device update: $e',
        tag: 'DeviceRepository',
        error: e,
      );
    }
  }

  /// Apply business rules based on device updates.
  void _applyDeviceBusinessRules(Device device) {
    // Example business rule: Log critical device status changes
    if (device.status == DeviceStatus.error) {
      Logger.warning(
        'Device ${device.id} reported error status',
        tag: 'DeviceRepository',
      );
    }

    // Example: Check for device timeout (device hasn't updated in a while)
    final timeSinceUpdate = DateTime.now().difference(device.lastUpdate ?? DateTime.now());
    if (timeSinceUpdate > const Duration(minutes: 5) && device.status == DeviceStatus.online) {
      Logger.warning(
        'Device ${device.id} may be stale (last update: ${timeSinceUpdate.inMinutes}m ago)',
        tag: 'DeviceRepository',
      );
    }
  }

  /// Get real-time device status updates stream.
  Stream<Device> get deviceStatusUpdates => dataService.deviceStatusStream;

  /// Stream of all device states.
  Stream<Map<String, Device>> get deviceStatesStream => _deviceStatesController.stream;

  /// Get current state of all known devices.
  Map<String, Device> getAllDeviceStates() {
    return Map.from(_knownDevices);
  }

  /// Get device state by ID.
  Device? getDeviceState(String deviceId) {
    return _knownDevices[deviceId];
  }

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

    // Validate command before sending
    if (!_isValidDeviceCommand(deviceId, command, parameters)) {
      final error = 'Invalid command for device $deviceId: $command';
      Logger.warning(error, tag: 'DeviceRepository');
      return Failure(ValidationError(error));
    }

    return dataService.sendDeviceCommand(deviceId, command, parameters: parameters);
  }

  /// Validate device commands based on business rules.
  bool _isValidDeviceCommand(
    String deviceId, 
    String command, 
    Map<String, dynamic>? parameters,
  ) {
    final device = _knownDevices[deviceId];
    if (device == null) {
      Logger.warning('Unknown device: $deviceId', tag: 'DeviceRepository');
      return true; // Allow commands to unknown devices
    }

    // Device type specific validation
    switch (device.type) {
      case DeviceType.pump:
        return _isPumpCommandValid(command, parameters);
      case DeviceType.fan:
        return _isFanCommandValid(command, parameters);
      case DeviceType.light:
        return _isLightCommandValid(command, parameters);
      case DeviceType.heater:
        return _isHeaterCommandValid(command, parameters);
      default:
        return true; // Allow all commands for unknown device types
    }
  }

  bool _isPumpCommandValid(String command, Map<String, dynamic>? parameters) {
    const validCommands = ['turn_on', 'turn_off', 'start_pump', 'stop_pump'];
    return validCommands.contains(command);
  }

  bool _isFanCommandValid(String command, Map<String, dynamic>? parameters) {
    const validCommands = ['turn_on', 'turn_off', 'set_fan_speed'];
    if (!validCommands.contains(command)) return false;
    
    if (command == 'set_fan_speed') {
      final speed = parameters?['speed'] as double?;
      return speed != null && speed >= 0.0 && speed <= 100.0;
    }
    return true;
  }

  bool _isLightCommandValid(String command, Map<String, dynamic>? parameters) {
    const validCommands = ['turn_on', 'turn_off', 'set_light'];
    if (!validCommands.contains(command)) return false;
    
    if (command == 'set_light') {
      final brightness = parameters?['brightness'] as double?;
      return brightness == null || (brightness >= 0.0 && brightness <= 100.0);
    }
    return true;
  }

  bool _isHeaterCommandValid(String command, Map<String, dynamic>? parameters) {
    const validCommands = ['turn_on', 'turn_off', 'set_temperature'];
    if (!validCommands.contains(command)) return false;
    
    if (command == 'set_temperature') {
      final temp = parameters?['target_temperature'] as double?;
      return temp == null || (temp >= 0.0 && temp <= 50.0);
    }
    return true;
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

  /// Check if a device is currently online and responding.
  bool isDeviceHealthy(String deviceId) {
    final device = _knownDevices[deviceId];
    if (device == null) return false;
    
    final timeSinceUpdate = DateTime.now().difference(device.lastUpdate ?? DateTime.now());
    return device.status == DeviceStatus.online && 
           timeSinceUpdate < const Duration(minutes: 2);
  }

  /// Get list of devices by type.
  List<Device> getDevicesByType(DeviceType type) {
    return _knownDevices.values
        .where((device) => device.type == type)
        .toList();
  }

  /// Get system health status based on critical devices.
  bool get isSystemHealthy {
    final criticalDevices = ['rpi_pump_1']; // Define critical devices
    return criticalDevices.every((deviceId) => isDeviceHealthy(deviceId));
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    try {
      Logger.info('Disposing device repository', tag: 'DeviceRepository');
      await _deviceStatusSubscription?.cancel();
      if (!_deviceStatesController.isClosed) {
        await _deviceStatesController.close();
      }
    } catch (e) {
      Logger.error(
        'Error disposing device repository: $e',
        tag: 'DeviceRepository',
        error: e,
      );
    }
  }
}
