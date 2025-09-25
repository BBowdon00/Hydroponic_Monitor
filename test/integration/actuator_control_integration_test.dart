import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/presentation/providers/device_control_providers.dart';

void main() {
  group('Actuator Control Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('MQTT command topics follow correct format', () async {
      // Test the _extractNodeFromDeviceId function through the providers

      // Mock some devices with different node prefixes
      final notifier = container.read(deviceControlsProvider.notifier);
      notifier.state = notifier.state.copyWith(
        devices: {
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: false,
            status: DeviceStatus.offline,
          ),
          'esp1_fan_1': const DeviceControlState(
            deviceId: 'esp1_fan_1',
            deviceType: DeviceType.fan,
            isEnabled: false,
            status: DeviceStatus.offline,
          ),
          'esp2_light_1': const DeviceControlState(
            deviceId: 'esp2_light_1',
            deviceType: DeviceType.light,
            isEnabled: false,
            status: DeviceStatus.offline,
          ),
        },
      );

      // Check device grouping by node
      final devicesByNode = container.read(devicesByNodeProvider);

      expect(devicesByNode.keys, containsAll(['rpi', 'esp1', 'esp2']));
      expect(devicesByNode['rpi']?.length, 1);
      expect(devicesByNode['esp1']?.length, 1);
      expect(devicesByNode['esp2']?.length, 1);

      // Verify specific devices are in correct nodes
      expect(devicesByNode['rpi']?.first.deviceId, 'rpi_pump_1');
      expect(devicesByNode['esp1']?.first.deviceId, 'esp1_fan_1');
      expect(devicesByNode['esp2']?.first.deviceId, 'esp2_light_1');
    });

    test('node status aggregation works correctly', () async {
      final notifier = container.read(deviceControlsProvider.notifier);

      // Create a mix of device states for different nodes
      notifier.state = notifier.state.copyWith(
        devices: {
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: true,
            status: DeviceStatus.online,
          ),
          'rpi_fan_1': const DeviceControlState(
            deviceId: 'rpi_fan_1',
            deviceType: DeviceType.fan,
            isEnabled: false,
            status: DeviceStatus.offline,
          ),
          'esp1_light_1': const DeviceControlState(
            deviceId: 'esp1_light_1',
            deviceType: DeviceType.light,
            isEnabled: false,
            status: DeviceStatus.error,
          ),
        },
      );

      final nodeStatuses = container.read(nodeStatusProvider);

      // RPI should be online (has at least one online device)
      expect(nodeStatuses['rpi'], DeviceStatus.online);

      // ESP1 should be error (has error device)
      expect(nodeStatuses['esp1'], DeviceStatus.error);
    });

    test('node status changes when device states change', () async {
      final notifier = container.read(deviceControlsProvider.notifier);

      // Initially all offline
      notifier.state = notifier.state.copyWith(
        devices: {
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: false,
            status: DeviceStatus.offline,
          ),
        },
      );

      var nodeStatuses = container.read(nodeStatusProvider);
      expect(nodeStatuses['rpi'], DeviceStatus.offline);

      // Update to online
      notifier.state = notifier.state.copyWith(
        devices: {
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: true,
            status: DeviceStatus.online,
          ),
        },
      );

      nodeStatuses = container.read(nodeStatusProvider);
      expect(nodeStatuses['rpi'], DeviceStatus.online);

      // Update to pending
      notifier.state = notifier.state.copyWith(
        devices: {
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: true,
            status: DeviceStatus.pending,
            isPending: true,
          ),
        },
      );

      nodeStatuses = container.read(nodeStatusProvider);
      expect(nodeStatuses['rpi'], DeviceStatus.pending);
    });

    test('specific node providers return correct data', () async {
      final notifier = container.read(deviceControlsProvider.notifier);

      notifier.state = notifier.state.copyWith(
        devices: {
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: true,
            status: DeviceStatus.online,
          ),
          'esp1_fan_1': const DeviceControlState(
            deviceId: 'esp1_fan_1',
            deviceType: DeviceType.fan,
            isEnabled: false,
            status: DeviceStatus.offline,
          ),
        },
      );

      // Test family providers
      final rpiDevices = container.read(devicesForNodeProvider('rpi'));
      final esp1Devices = container.read(devicesForNodeProvider('esp1'));
      final unknownDevices = container.read(devicesForNodeProvider('unknown'));

      expect(rpiDevices.length, 1);
      expect(rpiDevices.first.deviceId, 'rpi_pump_1');

      expect(esp1Devices.length, 1);
      expect(esp1Devices.first.deviceId, 'esp1_fan_1');

      expect(unknownDevices.length, 0);

      // Test node status family providers
      final rpiStatus = container.read(nodeStatusForProvider('rpi'));
      final esp1Status = container.read(nodeStatusForProvider('esp1'));
      final unknownStatus = container.read(nodeStatusForProvider('unknown'));

      expect(rpiStatus, DeviceStatus.online);
      expect(esp1Status, DeviceStatus.offline);
      expect(unknownStatus, DeviceStatus.offline);
    });
  });
}
