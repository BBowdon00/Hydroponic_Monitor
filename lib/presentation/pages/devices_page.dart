import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/device_card.dart';
import '../widgets/status_badge.dart';
import '../../core/theme.dart';
import '../providers/device_control_providers.dart';

/// Devices page for controlling hydroponic system devices.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemStatus = ref.watch(systemStatusProvider);
    final pumpState = ref.watch(pumpControlProvider);
    final fan1State = ref.watch(fan1ControlProvider);
    final fan2State = ref.watch(fan2ControlProvider);
    final lightState = ref.watch(lightControlProvider);
    final heaterState = ref.watch(heaterControlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          StatusBadge(label: 'System', status: systemStatus),
          const SizedBox(width: AppTheme.spaceMd),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: ListView(
          children: [
            // Water pump
            DeviceCard(
              title: 'Water Pump',
              description: 'Main nutrient circulation pump',
              icon: Icons.water_drop,
              color: Colors.blue,
              isEnabled: pumpState.isEnabled,
              isPending: pumpState.isPending,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(pumpState.deviceId, enabled);
              },
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // Circulation fans
            DeviceCard(
              title: 'Circulation Fan 1',
              description: 'Air circulation and ventilation',
              icon: Icons.air,
              color: Colors.cyan,
              isEnabled: fan1State.isEnabled,
              isPending: fan1State.isPending,
              intensity: fan1State.intensity ?? 0.6,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(fan1State.deviceId, enabled);
              },
              onIntensityChanged: (intensity) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .setDeviceIntensity(fan1State.deviceId, intensity);
              },
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // Second fan
            DeviceCard(
              title: 'Circulation Fan 2',
              description: 'Secondary air circulation',
              icon: Icons.air,
              color: Colors.teal,
              isEnabled: fan2State.isEnabled,
              isPending: fan2State.isPending,
              intensity: fan2State.intensity ?? 0.6,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(fan2State.deviceId, enabled);
              },
              onIntensityChanged: (intensity) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .setDeviceIntensity(fan2State.deviceId, intensity);
              },
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // LED grow lights
            DeviceCard(
              title: 'LED Grow Lights',
              description: 'Primary plant lighting system',
              icon: Icons.wb_sunny,
              color: Colors.amber,
              isEnabled: lightState.isEnabled,
              isPending: lightState.isPending,
              intensity: lightState.intensity ?? 0.8,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(lightState.deviceId, enabled);
              },
              onIntensityChanged: (intensity) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .setDeviceIntensity(lightState.deviceId, intensity);
              },
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // Heater
            DeviceCard(
              title: 'Water Heater',
              description: 'Maintains optimal water temperature',
              icon: Icons.thermostat,
              color: Colors.orange,
              isEnabled: heaterState.isEnabled,
              isPending: heaterState.isPending,
              onToggle: (enabled) {
                ref
                    .read(deviceControlsProvider.notifier)
                    .toggleDevice(heaterState.deviceId, enabled);
              },
            ),

            const SizedBox(height: AppTheme.spaceLg),

            // Emergency stop button
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  children: [
                    const Icon(Icons.emergency, color: Colors.red, size: 32),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'Emergency Stop',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'Immediately stops all devices',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showEmergencyStopDialog(context, ref);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.stop),
                        label: const Text('EMERGENCY STOP'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyStopDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Stop'),
        content: const Text(
          'This will immediately stop all devices. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(deviceControlsProvider.notifier).emergencyStopAll();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('STOP ALL'),
          ),
        ],
      ),
    );
  }
}
