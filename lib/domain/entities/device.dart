/// Domain entity for device control and status.
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.isEnabled = false,
    this.description,
    this.location,
    this.lastUpdate,
  });

  final String id;
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final bool isEnabled;
  final String? description;
  final String? location;
  final DateTime? lastUpdate;

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DeviceStatus? status,
    bool? isEnabled,
    String? description,
    String? location,
    DateTime? lastUpdate,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      isEnabled: isEnabled ?? this.isEnabled,
      description: description ?? this.description,
      location: location ?? this.location,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          status == other.status &&
          isEnabled == other.isEnabled &&
          description == other.description &&
          location == other.location &&
          lastUpdate == other.lastUpdate;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      status.hashCode ^
      isEnabled.hashCode ^
      description.hashCode ^
      location.hashCode ^
      lastUpdate.hashCode;

  @override
  String toString() =>
      'Device(id: $id, name: $name, type: $type, status: $status, enabled: $isEnabled)';
}

/// Types of devices in the hydroponic system.
enum DeviceType { pump, fan, heater, light, sensor, controller }

/// Status of devices in the system.
enum DeviceStatus { online, offline, pending, error, stopped, unknown }

extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.pump:
        return 'Pump';
      case DeviceType.fan:
        return 'Fan';
      case DeviceType.heater:
        return 'Heater';
      case DeviceType.light:
        return 'Light';
      case DeviceType.sensor:
        return 'Sensor';
      case DeviceType.controller:
        return 'Controller';
    }
  }
}

extension DeviceStatusExtension on DeviceStatus {
  String get displayName {
    switch (this) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.pending:
        return 'Pending';
      case DeviceStatus.error:
        return 'Error';
      case DeviceStatus.stopped:
        return 'Stopped';
      case DeviceStatus.unknown:
        return 'Unknown';
    }
  }
}
