import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';

import '../../domain/entities/device.dart';
import '../../core/logger.dart';
import '../../core/errors.dart';
import 'data_providers.dart';

/// Model for device control state with confirmation tracking.
class DeviceControlState {
  const DeviceControlState({
    required this.deviceId,
    required this.deviceType,
    required this.isEnabled,
    required this.status,
    this.isPending = false,
    this.lastCommand,
    this.lastCommandTime,
    this.intensity,
    this.pendingCommandId,
  });

  final String deviceId;
  final DeviceType deviceType;
  final bool isEnabled;
  final DeviceStatus status;
  final bool isPending;
  final String? lastCommand;
  final DateTime? lastCommandTime;
  final double? intensity; // For variable intensity devices (fans, lights)
  final String? pendingCommandId; // For tracking command confirmation

  DeviceControlState copyWith({
    String? deviceId,
    DeviceType? deviceType,
    bool? isEnabled,
    DeviceStatus? status,
    bool? isPending,
    String? lastCommand,
    DateTime? lastCommandTime,
    double? intensity,
    String? pendingCommandId,
  }) {
    return DeviceControlState(
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      isEnabled: isEnabled ?? this.isEnabled,
      status: status ?? this.status,
      isPending: isPending ?? this.isPending,
      lastCommand: lastCommand ?? this.lastCommand,
      lastCommandTime: lastCommandTime ?? this.lastCommandTime,
      intensity: intensity ?? this.intensity,
      pendingCommandId: pendingCommandId ?? this.pendingCommandId,
    );
  }
}

/// Aggregated device control state for the dashboard.
class DeviceControlsState {
  const DeviceControlsState({this.devices = const {}, this.lastUpdate});

  final Map<String, DeviceControlState> devices;
  final DateTime? lastUpdate;

  DeviceControlsState copyWith({
    Map<String, DeviceControlState>? devices,
    DateTime? lastUpdate,
  }) {
    return DeviceControlsState(
      devices: devices ?? this.devices,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// Get device state by ID, or return a default offline state.
  DeviceControlState getDeviceState(String deviceId, DeviceType deviceType) {
    return devices[deviceId] ??
        DeviceControlState(
          deviceId: deviceId,
          deviceType: deviceType,
          isEnabled: false,
          status: DeviceStatus.offline,
        );
  }

  /// Check if any device is pending.
  bool get hasAnyPending => devices.values.any((device) => device.isPending);

  /// Get system status based on individual device statuses.
  DeviceStatus get systemStatus {
    if (devices.isEmpty) return DeviceStatus.offline;

    final statuses = devices.values.map((d) => d.status).toSet();

    if (statuses.contains(DeviceStatus.error)) return DeviceStatus.error;
    if (statuses.contains(DeviceStatus.pending)) return DeviceStatus.pending;
    if (statuses.every((s) => s == DeviceStatus.offline)) {
      return DeviceStatus.offline;
    }
    if (statuses.every((s) => s == DeviceStatus.online)) {
      return DeviceStatus.online;
    }

    return DeviceStatus.online; // Mixed states, consider online
  }
}

/// Provider for device control states with MQTT integration.
final deviceControlsProvider =
    StateNotifierProvider<DeviceControlsNotifier, DeviceControlsState>((ref) {
      return DeviceControlsNotifier(ref);
    });

class DeviceControlsNotifier extends StateNotifier<DeviceControlsState> {
  DeviceControlsNotifier(this.ref) : super(const DeviceControlsState()) {
    _initialize();
  }

  final Ref ref;
  ProviderSubscription? _deviceStatusSubscription;
  final Map<String, Timer> _pendingTimeouts = {};

  void _initialize() {
    Logger.info('Initializing device controls provider', tag: 'DeviceControls');

    // Listen to device status updates from MQTT
    _deviceStatusSubscription = ref.listen(deviceStatusUpdatesProvider, (
      previous,
      next,
    ) {
      _onDeviceStatusUpdate(next);
    });

    // Initialize known devices with default states
    _initializeKnownDevices();
  }

  void _initializeKnownDevices() {
    // Initialize common hydroponic devices
    final knownDevices = {
      'rpi_pump_1': DeviceType.pump,
      'rpi_fan_1': DeviceType.fan,
      'rpi_fan_2': DeviceType.fan,
      'rpi_light_1': DeviceType.light,
      'rpi_heater_1': DeviceType.heater,
      'esp32_fan_3': DeviceType.fan,
      'esp32_light_2': DeviceType.light,
    };

    final newDevices = <String, DeviceControlState>{};
    for (final entry in knownDevices.entries) {
      newDevices[entry.key] = DeviceControlState(
        deviceId: entry.key,
        deviceType: entry.value,
        isEnabled: false,
        status: DeviceStatus.offline,
      );
    }

    state = state.copyWith(devices: newDevices);
  }

  void _onDeviceStatusUpdate(AsyncValue<Device> asyncDevice) {
    asyncDevice.when(
      data: (device) {
        _updateDeviceStatus(device);
      },
      loading: () {
        // Handle loading state if needed
      },
      error: (error, stackTrace) {
        Logger.error(
          'Error processing device update: $error',
          tag: 'DeviceControls',
        );
      },
    );
  }

  void _updateDeviceStatus(Device device) {
    final newDevices = Map<String, DeviceControlState>.from(state.devices);
    final currentState = newDevices[device.id];

    final updatedState =
        (currentState ??
                DeviceControlState(
                  deviceId: device.id,
                  deviceType: device.type,
                  isEnabled: device.isEnabled,
                  status: device.status,
                ))
            .copyWith(
              isEnabled: device.isEnabled,
              status: device.status,
              isPending: false, // Status update means command completed
            );

    newDevices[device.id] = updatedState;
    state = state.copyWith(devices: newDevices, lastUpdate: DateTime.now());

    // Clear any pending timeout for this device
    _clearPendingTimeout(device.id);

    Logger.info(
      'Updated device status: ${device.id} = ${device.status.displayName} (enabled: ${device.isEnabled})',
      tag: 'DeviceControls',
    );
  }

  /// Send command to control a device.
  Future<void> controlDevice(
    String deviceId,
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    Logger.info(
      'Sending device command: $deviceId -> $command',
      tag: 'DeviceControls',
    );

    // Update state to pending
    final newDevices = Map<String, DeviceControlState>.from(state.devices);
    final currentState = newDevices[deviceId];
    if (currentState != null) {
      final commandId = DateTime.now().millisecondsSinceEpoch.toString();
      newDevices[deviceId] = currentState.copyWith(
        isPending: true,
        lastCommand: command,
        lastCommandTime: DateTime.now(),
        pendingCommandId: commandId,
      );
      state = state.copyWith(devices: newDevices);

      // Set timeout for command confirmation
      _setPendingTimeout(deviceId, commandId);
    }

    // Send command via device repository
    final deviceRepository = ref.read(deviceRepositoryProvider);
    final result = await deviceRepository.controlDevice(
      deviceId,
      command,
      parameters: parameters,
    );

    if (result is Failure) {
      Logger.error(
        'Failed to send device command: ${result.error}',
        tag: 'DeviceControls',
      );
      // Reset pending state on failure
      if (currentState != null) {
        newDevices[deviceId] = currentState.copyWith(isPending: false);
        state = state.copyWith(devices: newDevices);
      }
    }
  }

  void _setPendingTimeout(String deviceId, String commandId) {
    _clearPendingTimeout(deviceId);

    _pendingTimeouts[deviceId] = Timer(const Duration(seconds: 10), () {
      Logger.warning(
        'Command timeout for device $deviceId',
        tag: 'DeviceControls',
      );
      _handleCommandTimeout(deviceId, commandId);
    });
  }

  void _clearPendingTimeout(String deviceId) {
    _pendingTimeouts[deviceId]?.cancel();
    _pendingTimeouts.remove(deviceId);
  }

  void _handleCommandTimeout(String deviceId, String commandId) {
    final newDevices = Map<String, DeviceControlState>.from(state.devices);
    final currentState = newDevices[deviceId];

    if (currentState != null && currentState.pendingCommandId == commandId) {
      newDevices[deviceId] = currentState.copyWith(
        isPending: false,
        status: DeviceStatus.error,
      );
      state = state.copyWith(devices: newDevices);
    }
  }

  /// Toggle device on/off.
  Future<void> toggleDevice(String deviceId, bool enabled) async {
    final command = enabled ? 'turn_on' : 'turn_off';
    await controlDevice(deviceId, command);
  }

  /// Set device intensity (for fans, lights).
  Future<void> setDeviceIntensity(String deviceId, double intensity) async {
    final newDevices = Map<String, DeviceControlState>.from(state.devices);
    final currentState = newDevices[deviceId];
    if (currentState != null) {
      newDevices[deviceId] = currentState.copyWith(intensity: intensity);
      state = state.copyWith(devices: newDevices);
    }

    // Send appropriate command based on device type
    final deviceType = currentState?.deviceType;
    switch (deviceType) {
      case DeviceType.fan:
        await controlDevice(
          deviceId,
          'set_fan_speed',
          parameters: {'speed': intensity},
        );
        break;
      case DeviceType.light:
        await controlDevice(
          deviceId,
          'set_light',
          parameters: {'brightness': intensity},
        );
        break;
      default:
        Logger.warning(
          'Intensity control not supported for device type: $deviceType',
          tag: 'DeviceControls',
        );
    }
  }

  /// Emergency stop all devices.
  Future<void> emergencyStopAll() async {
    Logger.warning('Emergency stop initiated', tag: 'DeviceControls');

    final deviceRepository = ref.read(deviceRepositoryProvider);
    final result = await deviceRepository.emergencyStopAll();

    if (result is Success) {
      // Update all devices to stopped state
      final newDevices = <String, DeviceControlState>{};
      for (final device in state.devices.values) {
        newDevices[device.deviceId] = device.copyWith(
          isEnabled: false,
          status: DeviceStatus.stopped,
          isPending: false,
        );
      }
      state = state.copyWith(devices: newDevices);
    }
  }

  @override
  void dispose() {
    _deviceStatusSubscription?.close();
    for (final timer in _pendingTimeouts.values) {
      timer.cancel();
    }
    _pendingTimeouts.clear();
    super.dispose();
  }
}

/// Convenience providers for specific device types.
final pumpControlProvider = Provider<DeviceControlState>((ref) {
  final controls = ref.watch(deviceControlsProvider);
  return controls.getDeviceState('rpi_pump_1', DeviceType.pump);
});

final fan1ControlProvider = Provider<DeviceControlState>((ref) {
  final controls = ref.watch(deviceControlsProvider);
  return controls.getDeviceState('rpi_fan_1', DeviceType.fan);
});

final fan2ControlProvider = Provider<DeviceControlState>((ref) {
  final controls = ref.watch(deviceControlsProvider);
  return controls.getDeviceState('rpi_fan_2', DeviceType.fan);
});

final lightControlProvider = Provider<DeviceControlState>((ref) {
  final controls = ref.watch(deviceControlsProvider);
  return controls.getDeviceState('rpi_light_1', DeviceType.light);
});

final heaterControlProvider = Provider<DeviceControlState>((ref) {
  final controls = ref.watch(deviceControlsProvider);
  return controls.getDeviceState('rpi_heater_1', DeviceType.heater);
});

/// System status provider.
final systemStatusProvider = Provider<DeviceStatus>((ref) {
  final controls = ref.watch(deviceControlsProvider);
  return controls.systemStatus;
});

/// Helper function to extract node name from device ID.
String _extractNodeFromDeviceId(String deviceId) {
  final parts = deviceId.split('_');
  return parts.isNotEmpty ? parts[0] : 'unknown';
}

/// Provider for devices grouped by node.
final devicesByNodeProvider = Provider<Map<String, List<DeviceControlState>>>((ref) {
  final controls = ref.watch(deviceControlsProvider);
  final devicesByNode = <String, List<DeviceControlState>>{};
  
  for (final device in controls.devices.values) {
    final node = _extractNodeFromDeviceId(device.deviceId);
    devicesByNode.putIfAbsent(node, () => []).add(device);
  }
  
  return devicesByNode;
});

/// Provider for node status (aggregated from devices on that node).
final nodeStatusProvider = Provider<Map<String, DeviceStatus>>((ref) {
  final devicesByNode = ref.watch(devicesByNodeProvider);
  final nodeStatuses = <String, DeviceStatus>{};
  
  for (final entry in devicesByNode.entries) {
    final node = entry.key;
    final devices = entry.value;
    
    if (devices.isEmpty) {
      nodeStatuses[node] = DeviceStatus.offline;
      continue;
    }
    
    // Determine node status based on device statuses
    final statuses = devices.map((d) => d.status).toSet();
    
    if (statuses.contains(DeviceStatus.error)) {
      nodeStatuses[node] = DeviceStatus.error;
    } else if (statuses.contains(DeviceStatus.pending)) {
      nodeStatuses[node] = DeviceStatus.pending;
    } else if (statuses.every((s) => s == DeviceStatus.offline)) {
      nodeStatuses[node] = DeviceStatus.offline;
    } else if (statuses.contains(DeviceStatus.online)) {
      nodeStatuses[node] = DeviceStatus.online;
    } else {
      nodeStatuses[node] = DeviceStatus.offline;
    }
  }
  
  return nodeStatuses;
});

/// Provider for devices on a specific node.
final devicesForNodeProvider = Provider.family<List<DeviceControlState>, String>((ref, node) {
  final devicesByNode = ref.watch(devicesByNodeProvider);
  return devicesByNode[node] ?? [];
});

/// Provider for status of a specific node.
final nodeStatusForProvider = Provider.family<DeviceStatus, String>((ref, node) {
  final nodeStatuses = ref.watch(nodeStatusProvider);
  return nodeStatuses[node] ?? DeviceStatus.offline;
});
