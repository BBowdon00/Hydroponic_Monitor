import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/device_card.dart';
import '../widgets/status_badge.dart';
import '../../core/theme.dart';

/// Devices page for controlling hydroponic system devices.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceStates = ref.watch(deviceStatesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          StatusBadge(
            label: 'System',
            status: deviceStates.systemStatus,
          ),
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
              isEnabled: deviceStates.pumpEnabled,
              isPending: deviceStates.pumpPending,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).togglePump(enabled);
              },
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // Circulation fans
            DeviceCard(
              title: 'Circulation Fans',
              description: 'Air circulation and ventilation',
              icon: Icons.air,
              color: Colors.cyan,
              isEnabled: deviceStates.fansEnabled,
              isPending: deviceStates.fansPending,
              intensity: deviceStates.fanIntensity,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).toggleFans(enabled);
              },
              onIntensityChanged: (intensity) {
                ref.read(deviceStatesProvider.notifier).setFanIntensity(intensity);
              },
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // LED grow lights
            DeviceCard(
              title: 'LED Grow Lights',
              description: 'Primary plant lighting system',
              icon: Icons.wb_sunny,
              color: Colors.amber,
              isEnabled: deviceStates.lightsEnabled,
              isPending: deviceStates.lightsPending,
              intensity: deviceStates.lightIntensity,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).toggleLights(enabled);
              },
              onIntensityChanged: (intensity) {
                ref.read(deviceStatesProvider.notifier).setLightIntensity(intensity);
              },
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // Heater
            DeviceCard(
              title: 'Water Heater',
              description: 'Maintains optimal water temperature',
              icon: Icons.thermostat,
              color: Colors.orange,
              isEnabled: deviceStates.heaterEnabled,
              isPending: deviceStates.heaterPending,
              onToggle: (enabled) {
                ref.read(deviceStatesProvider.notifier).toggleHeater(enabled);
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
                    Icon(
                      Icons.emergency,
                      color: Colors.red,
                      size: 32,
                    ),
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
              ref.read(deviceStatesProvider.notifier).emergencyStop();
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

/// Device states model.
class DeviceStates {
  const DeviceStates({
    required this.pumpEnabled,
    required this.pumpPending,
    required this.fansEnabled,
    required this.fansPending,
    required this.fanIntensity,
    required this.lightsEnabled,
    required this.lightsPending,
    required this.lightIntensity,
    required this.heaterEnabled,
    required this.heaterPending,
    required this.systemStatus,
  });

  final bool pumpEnabled;
  final bool pumpPending;
  final bool fansEnabled;
  final bool fansPending;
  final double fanIntensity;
  final bool lightsEnabled;
  final bool lightsPending;
  final double lightIntensity;
  final bool heaterEnabled;
  final bool heaterPending;
  final DeviceStatus systemStatus;

  DeviceStates copyWith({
    bool? pumpEnabled,
    bool? pumpPending,
    bool? fansEnabled,
    bool? fansPending,
    double? fanIntensity,
    bool? lightsEnabled,
    bool? lightsPending,
    double? lightIntensity,
    bool? heaterEnabled,
    bool? heaterPending,
    DeviceStatus? systemStatus,
  }) {
    return DeviceStates(
      pumpEnabled: pumpEnabled ?? this.pumpEnabled,
      pumpPending: pumpPending ?? this.pumpPending,
      fansEnabled: fansEnabled ?? this.fansEnabled,
      fansPending: fansPending ?? this.fansPending,
      fanIntensity: fanIntensity ?? this.fanIntensity,
      lightsEnabled: lightsEnabled ?? this.lightsEnabled,
      lightsPending: lightsPending ?? this.lightsPending,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      heaterEnabled: heaterEnabled ?? this.heaterEnabled,
      heaterPending: heaterPending ?? this.heaterPending,
      systemStatus: systemStatus ?? this.systemStatus,
    );
  }
}

/// Provider for device states with optimistic updates.
final deviceStatesProvider = StateNotifierProvider<DeviceStatesNotifier, DeviceStates>((ref) {
  return DeviceStatesNotifier();
});

class DeviceStatesNotifier extends StateNotifier<DeviceStates> {
  DeviceStatesNotifier()
      : super(const DeviceStates(
          pumpEnabled: false,
          pumpPending: false,
          fansEnabled: true,
          fansPending: false,
          fanIntensity: 0.6,
          lightsEnabled: true,
          lightsPending: false,
          lightIntensity: 0.8,
          heaterEnabled: false,
          heaterPending: false,
          systemStatus: DeviceStatus.online,
        ));

  void togglePump(bool enabled) {
    state = state.copyWith(pumpEnabled: enabled, pumpPending: true);
    // Simulate network request
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = state.copyWith(pumpPending: false);
      }
    });
  }

  void toggleFans(bool enabled) {
    state = state.copyWith(fansEnabled: enabled, fansPending: true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        state = state.copyWith(fansPending: false);
      }
    });
  }

  void setFanIntensity(double intensity) {
    state = state.copyWith(fanIntensity: intensity);
  }

  void toggleLights(bool enabled) {
    state = state.copyWith(lightsEnabled: enabled, lightsPending: true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        state = state.copyWith(lightsPending: false);
      }
    });
  }

  void setLightIntensity(double intensity) {
    state = state.copyWith(lightIntensity: intensity);
  }

  void toggleHeater(bool enabled) {
    state = state.copyWith(heaterEnabled: enabled, heaterPending: true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        state = state.copyWith(heaterPending: false);
      }
    });
  }

  void emergencyStop() {
    state = state.copyWith(
      pumpEnabled: false,
      fansEnabled: false,
      lightsEnabled: false,
      heaterEnabled: false,
      systemStatus: DeviceStatus.stopped,
    );
    
    // Reset status after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        state = state.copyWith(systemStatus: DeviceStatus.online);
      }
    });
  }
}