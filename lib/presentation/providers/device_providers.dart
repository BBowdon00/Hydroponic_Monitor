import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/logger.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';

/// Mock device state notifier
class DeviceNotifier extends StateNotifier<List<Device>> {
  DeviceNotifier() : super(_initialDevices) {
    _startPeriodicUpdates();
  }

  Timer? _updateTimer;

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Update last update timestamps for online devices
      state = state.map((device) {
        if (device.status == DeviceStatus.online) {
          return device.copyWith(lastUpdate: DateTime.now());
        }
        return device;
      }).toList();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  /// Toggle device on/off with optimistic update
  Future<void> toggleDevice(String deviceId) async {
    Logger.info('Toggling device: $deviceId', tag: 'DeviceProvider');
    
    // Optimistic update
    state = state.map((device) {
      if (device.id == deviceId) {
        return device.copyWith(
          isOn: !device.isOn,
          lastUpdate: DateTime.now(),
        );
      }
      return device;
    }).toList();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // In a real app, this would make an MQTT publish or HTTP request
    Logger.info('Device toggle completed: $deviceId', tag: 'DeviceProvider');
  }

  /// Update device intensity with optimistic update
  Future<void> updateIntensity(String deviceId, double intensity) async {
    Logger.info('Updating device intensity: $deviceId -> $intensity', tag: 'DeviceProvider');
    
    // Optimistic update
    state = state.map((device) {
      if (device.id == deviceId) {
        return device.copyWith(
          intensity: intensity,
          lastUpdate: DateTime.now(),
        );
      }
      return device;
    }).toList();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    Logger.info('Device intensity update completed: $deviceId', tag: 'DeviceProvider');
  }

  /// Simulate device status changes
  void simulateStatusChange(String deviceId, DeviceStatus newStatus) {
    state = state.map((device) {
      if (device.id == deviceId) {
        return device.copyWith(
          status: newStatus,
          lastUpdate: DateTime.now(),
        );
      }
      return device;
    }).toList();
  }
}

/// Device state provider
final deviceProvider = StateNotifierProvider<DeviceNotifier, List<Device>>((ref) {
  return DeviceNotifier();
});

/// Provider for devices filtered by type
final devicesByTypeProvider = Provider.family<List<Device>, DeviceType?>((ref, type) {
  final devices = ref.watch(deviceProvider);
  if (type == null) return devices;
  return devices.where((device) => device.type == type).toList();
});

/// Provider for a specific device
final deviceByIdProvider = Provider.family<Device?, String>((ref, deviceId) {
  final devices = ref.watch(deviceProvider);
  try {
    return devices.firstWhere((device) => device.id == deviceId);
  } catch (e) {
    return null;
  }
});

/// Mock initial devices
final _initialDevices = [
  Device(
    id: 'pump_01',
    name: 'Water Pump',
    type: DeviceType.pump,
    status: DeviceStatus.online,
    isOn: false,
    intensity: 0.7,
    isControllable: true,
    location: 'Reservoir 1',
    lastUpdate: DateTime.now(),
  ),
  Device(
    id: 'fan_01',
    name: 'Exhaust Fan',
    type: DeviceType.fan,
    status: DeviceStatus.online,
    isOn: true,
    intensity: 0.5,
    isControllable: true,
    location: 'Greenhouse A',
    lastUpdate: DateTime.now(),
  ),
  Device(
    id: 'fan_02',
    name: 'Circulation Fan',
    type: DeviceType.fan,
    status: DeviceStatus.online,
    isOn: true,
    intensity: 0.3,
    isControllable: true,
    location: 'Greenhouse A',
    lastUpdate: DateTime.now(),
  ),
  Device(
    id: 'light_01',
    name: 'LED Grow Light',
    type: DeviceType.light,
    status: DeviceStatus.online,
    isOn: true,
    intensity: 0.8,
    isControllable: true,
    location: 'Growing Area',
    lastUpdate: DateTime.now(),
  ),
  Device(
    id: 'heater_01',
    name: 'Water Heater',
    type: DeviceType.heater,
    status: DeviceStatus.maintenance,
    isOn: false,
    isControllable: false,
    location: 'Reservoir 1',
    lastUpdate: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Device(
    id: 'valve_01',
    name: 'Drain Valve',
    type: DeviceType.valve,
    status: DeviceStatus.offline,
    isOn: false,
    isControllable: false,
    location: 'Reservoir 1',
    lastUpdate: DateTime.now().subtract(const Duration(hours: 6)),
  ),
];