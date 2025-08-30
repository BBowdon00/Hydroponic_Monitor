import 'package:freezed_annotation/freezed_annotation.dart';

part 'device.freezed.dart';
part 'device.g.dart';

/// Device types
enum DeviceType {
  pump,
  fan,
  light,
  heater,
  valve,
}

/// Device status
enum DeviceStatus {
  online,
  offline,
  error,
  maintenance,
}

/// Controllable device
@freezed
class Device with _$Device {
  const factory Device({
    required String id,
    required String name,
    required DeviceType type,
    required DeviceStatus status,
    required bool isOn,
    String? location,
    @Default(0.0) double intensity, // 0.0 to 1.0
    @Default(false) bool isControllable,
    DateTime? lastUpdate,
  }) = _Device;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}

/// Device command for control
@freezed
class DeviceCommand with _$DeviceCommand {
  const factory DeviceCommand.toggle({
    required String deviceId,
    required bool turnOn,
  }) = ToggleCommand;

  const factory DeviceCommand.setIntensity({
    required String deviceId,
    required double intensity,
  }) = SetIntensityCommand;

  factory DeviceCommand.fromJson(Map<String, dynamic> json) =>
      _$DeviceCommandFromJson(json);
}

/// Extensions for device types
extension DeviceTypeExtensions on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.pump:
        return 'Water Pump';
      case DeviceType.fan:
        return 'Fan';
      case DeviceType.light:
        return 'Light';
      case DeviceType.heater:
        return 'Heater';
      case DeviceType.valve:
        return 'Valve';
    }
  }

  bool get hasIntensityControl {
    switch (this) {
      case DeviceType.pump:
      case DeviceType.fan:
      case DeviceType.light:
        return true;
      case DeviceType.heater:
      case DeviceType.valve:
        return false;
    }
  }
}

/// Extensions for device status
extension DeviceStatusExtensions on DeviceStatus {
  String get displayName {
    switch (this) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.error:
        return 'Error';
      case DeviceStatus.maintenance:
        return 'Maintenance';
    }
  }
}