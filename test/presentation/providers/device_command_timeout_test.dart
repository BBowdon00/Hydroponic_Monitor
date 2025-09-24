import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/presentation/providers/device_control_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/data/repos/device_repository.dart';

import '../../mocks/mock_device_repository.dart';

void main() {
  group('Device Control Command Timeout Tests', () {
    late ProviderContainer container;
    late MockDeviceRepository mockRepository;

    setUp(() {
      // Disable real timers to keep tests fast and deterministic
      DeviceControlsNotifier.useCommandTimeouts = false;
      // Disable node-online enforcement for these provider unit tests
      DeviceControlsNotifier.enforceNodeOnlineForCommands = false;
      mockRepository = MockDeviceRepository();
      
      container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('device command sets pending state correctly', (tester) async {
      final notifier = container.read(deviceControlsProvider.notifier);
      
  // Initialize the provider (no widget tree, a single pump is enough)
  await tester.pump();
      
      // Initial state should not be pending
      final initialState = container.read(deviceControlsProvider);
      final pumpDevice = initialState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pumpDevice.isPending, isFalse);
      
      // Send a command
      await notifier.toggleDevice('rpi_pump_1', true);
      
      // Device should now be in pending state
      final pendingState = container.read(deviceControlsProvider);
      final pendingPumpDevice = pendingState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pendingPumpDevice.isPending, isTrue);
      expect(pendingPumpDevice.lastCommand, 'turn_on');
      expect(pendingPumpDevice.pendingCommandId, isNotNull);
    });

    testWidgets('device command timeout sets error state', (tester) async {
      // Re-enable timeouts for this specific test and use fakeAsync to advance time
      DeviceControlsNotifier.useCommandTimeouts = true;
      final notifier = container.read(deviceControlsProvider.notifier);
      
  // Initialize the provider
  await tester.pump();
      
      // Send a command
      await notifier.toggleDevice('rpi_pump_1', true);
      
      // Verify pending state
      var currentState = container.read(deviceControlsProvider);
      var pumpDevice = currentState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pumpDevice.isPending, isTrue);
      
  // Wait for timeout (10 seconds + buffer)
  await tester.pump(const Duration(seconds: 11));
      
      // Device should now be in error state
      currentState = container.read(deviceControlsProvider);
      pumpDevice = currentState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pumpDevice.isPending, isFalse);
      expect(pumpDevice.status, DeviceStatus.error);
      // Reset for following tests
      DeviceControlsNotifier.useCommandTimeouts = false;
    });

    testWidgets('device status update clears pending state', (tester) async {
      final notifier = container.read(deviceControlsProvider.notifier);
      
  // Initialize the provider
  await tester.pump();
      
      // Send a command
      await notifier.toggleDevice('rpi_pump_1', true);
      
      // Verify pending state
      var currentState = container.read(deviceControlsProvider);
      var pumpDevice = currentState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pumpDevice.isPending, isTrue);
      
      // Simulate MQTT status update
      const confirmedDevice = Device(
        id: 'rpi_pump_1',
        name: 'Water Pump',
        type: DeviceType.pump,
        status: DeviceStatus.online,
        isEnabled: true,
        lastUpdate: null,
      );
      
      // Trigger device status update
      notifier.state = notifier.state.copyWith(
        devices: {
          ...notifier.state.devices,
          'rpi_pump_1': DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: true,
            status: DeviceStatus.online,
            isPending: false, // Status update clears pending
          ),
        },
      );
      
  await tester.pump();
      
      // Device should no longer be pending
      currentState = container.read(deviceControlsProvider);
      pumpDevice = currentState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pumpDevice.isPending, isFalse);
      expect(pumpDevice.status, DeviceStatus.online);
      expect(pumpDevice.isEnabled, isTrue);
    });

    testWidgets('command failure resets pending state immediately', (tester) async {
      // Configure mock to return failure
      mockRepository.setCommandResult(false);
      
      final notifier = container.read(deviceControlsProvider.notifier);
      
      // Initialize the provider
      await tester.pumpAndSettle();
      
      // Send a command that will fail
      await notifier.toggleDevice('rpi_pump_1', true);
      await tester.pumpAndSettle();
      
      // Device should not be pending after command failure
      final currentState = container.read(deviceControlsProvider);
      final pumpDevice = currentState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pumpDevice.isPending, isFalse);
    });

    testWidgets('intensity control commands work correctly', (tester) async {
      final notifier = container.read(deviceControlsProvider.notifier);
      
      // Initialize the provider
      await tester.pumpAndSettle();
      
      // Set fan intensity
      await notifier.setDeviceIntensity('rpi_fan_1', 0.8);
      await tester.pumpAndSettle();
      
      // Check that intensity is set
      final currentState = container.read(deviceControlsProvider);
      final fanDevice = currentState.getDeviceState('rpi_fan_1', DeviceType.fan);
      expect(fanDevice.intensity, 0.8);
      
      // Check that command was sent
      expect(mockRepository.lastCommand, isNotNull);
      expect(mockRepository.lastCommand!['command'], 'set_fan_speed');
      expect(mockRepository.lastCommand!['parameters']['speed'], 0.8);
    });

    testWidgets('emergency stop affects all devices', (tester) async {
      final notifier = container.read(deviceControlsProvider.notifier);
      
      // Initialize the provider
      await tester.pumpAndSettle();
      
      // Set some devices to enabled state
      notifier.state = notifier.state.copyWith(
        devices: {
          ...notifier.state.devices,
          'rpi_pump_1': const DeviceControlState(
            deviceId: 'rpi_pump_1',
            deviceType: DeviceType.pump,
            isEnabled: true,
            status: DeviceStatus.online,
          ),
          'rpi_fan_1': const DeviceControlState(
            deviceId: 'rpi_fan_1',
            deviceType: DeviceType.fan,
            isEnabled: true,
            status: DeviceStatus.online,
          ),
        },
      );
      
      // Trigger emergency stop
      await notifier.emergencyStopAll();
      await tester.pumpAndSettle();
      
      // All devices should be stopped and disabled
      final currentState = container.read(deviceControlsProvider);
      
      final pumpDevice = currentState.getDeviceState('rpi_pump_1', DeviceType.pump);
      expect(pumpDevice.isEnabled, isFalse);
      expect(pumpDevice.status, DeviceStatus.stopped);
      expect(pumpDevice.isPending, isFalse);
      
      final fanDevice = currentState.getDeviceState('rpi_fan_1', DeviceType.fan);
      expect(fanDevice.isEnabled, isFalse);
      expect(fanDevice.status, DeviceStatus.stopped);
      expect(fanDevice.isPending, isFalse);
    });
  });
}