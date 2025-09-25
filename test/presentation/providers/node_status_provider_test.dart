import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/presentation/providers/device_control_providers.dart';

void main() {
  group('Node Status Provider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('devicesByNodeProvider groups devices correctly by node', () async {
      // Get initial state
      final devicesByNode = container.read(devicesByNodeProvider);

      // Should have default devices grouped by node
      expect(devicesByNode, isA<Map<String, List<DeviceControlState>>>());
      expect(devicesByNode.containsKey('rpi'), isTrue);
      expect(devicesByNode.containsKey('esp32'), isTrue);

      // Check RPI devices
      final rpiDevices = devicesByNode['rpi'] ?? [];
      expect(rpiDevices.any((d) => d.deviceType == DeviceType.pump), isTrue);
      expect(rpiDevices.any((d) => d.deviceType == DeviceType.fan), isTrue);
      expect(rpiDevices.any((d) => d.deviceType == DeviceType.light), isTrue);
      expect(rpiDevices.any((d) => d.deviceType == DeviceType.heater), isTrue);
    });

    test('nodeStatusProvider aggregates device statuses correctly', () async {
      // Get initial node statuses
      final nodeStatuses = container.read(nodeStatusProvider);

      expect(nodeStatuses, isA<Map<String, DeviceStatus>>());
      expect(nodeStatuses.containsKey('rpi'), isTrue);
      expect(nodeStatuses.containsKey('esp32'), isTrue);

      // Initially all devices should be offline
      expect(nodeStatuses['rpi'], DeviceStatus.offline);
      expect(nodeStatuses['esp32'], DeviceStatus.offline);
    });

    test('devicesForNodeProvider returns devices for specific node', () async {
      // Get devices for RPI node
      final rpiDevices = container.read(devicesForNodeProvider('rpi'));

      expect(rpiDevices, isA<List<DeviceControlState>>());
      expect(rpiDevices.isNotEmpty, isTrue);
      expect(rpiDevices.every((d) => d.deviceId.startsWith('rpi_')), isTrue);
    });

    test('nodeStatusForProvider returns status for specific node', () async {
      // Get status for RPI node
      final rpiStatus = container.read(nodeStatusForProvider('rpi'));

      expect(rpiStatus, isA<DeviceStatus>());
      expect(rpiStatus, DeviceStatus.offline); // Initial state
    });

    test(
      'node status aggregation handles mixed device states correctly',
      () async {
        // Simulate updating device states through the controls provider
        final notifier = container.read(deviceControlsProvider.notifier);

        // Create a mock device update to simulate online status
        const mockDevice = Device(
          id: 'rpi_pump_1',
          name: 'Test Pump',
          type: DeviceType.pump,
          status: DeviceStatus.online,
          isEnabled: true,
        );

        // Update the device status directly (simulating MQTT update)
        notifier.state = notifier.state.copyWith(
          devices: {
            ...notifier.state.devices,
            'rpi_pump_1': const DeviceControlState(
              deviceId: 'rpi_pump_1',
              deviceType: DeviceType.pump,
              isEnabled: true,
              status: DeviceStatus.online,
            ),
          },
        );

        // Check that node status is updated
        final nodeStatuses = container.read(nodeStatusProvider);
        expect(nodeStatuses['rpi'], DeviceStatus.online);
      },
    );

    test('node status shows error when any device has error status', () async {
      final notifier = container.read(deviceControlsProvider.notifier);

      // Set one device to error state
      notifier.state = notifier.state.copyWith(
        devices: {
          ...notifier.state.devices,
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: false,
            status: DeviceStatus.error,
          ),
        },
      );

      // Node status should show error
      final nodeStatuses = container.read(nodeStatusProvider);
      expect(nodeStatuses['rpi'], DeviceStatus.error);
    });

    test('node status shows pending when any device is pending', () async {
      final notifier = container.read(deviceControlsProvider.notifier);

      // Set one device to pending state
      notifier.state = notifier.state.copyWith(
        devices: {
          ...notifier.state.devices,
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: false,
            status: DeviceStatus.pending,
            isPending: true,
          ),
        },
      );

      // Node status should show pending
      final nodeStatuses = container.read(nodeStatusProvider);
      expect(nodeStatuses['rpi'], DeviceStatus.pending);
    });

    test('unknown node returns offline status', () async {
      final unknownNodeStatus = container.read(
        nodeStatusForProvider('unknown'),
      );
      expect(unknownNodeStatus, DeviceStatus.offline);

      final unknownDevices = container.read(devicesForNodeProvider('unknown'));
      expect(unknownDevices, isEmpty);
    });
  });
}
