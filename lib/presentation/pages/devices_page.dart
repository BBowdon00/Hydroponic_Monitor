import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/device_card.dart';
import '../widgets/status_badge.dart';
import '../../core/theme.dart';
import '../../domain/entities/device.dart';
import '../providers/device_control_providers.dart';

/// Devices page for controlling hydroponic system devices grouped by node.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemStatus = ref.watch(systemStatusProvider);
    final devicesByNode = ref.watch(devicesByNodeProvider);
    final nodeStatuses = ref.watch(nodeStatusProvider);

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
            // Emergency stop button (always visible at top)
            _buildEmergencyStopSection(context, ref),
            const SizedBox(height: AppTheme.spaceLg),

            // Build sections for each node
            ...devicesByNode.entries.map((entry) {
              final node = entry.key;
              final devices = entry.value;
              final nodeStatus = nodeStatuses[node] ?? DeviceStatus.offline;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNodeSection(context, node, nodeStatus, devices, ref),
                  const SizedBox(height: AppTheme.spaceLg),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeSection(
    BuildContext context,
    String node,
    DeviceStatus nodeStatus,
    List<DeviceControlState> devices,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final nodeDisplayName = _getNodeDisplayName(node);
    
    final controlsEnabled = nodeStatus == DeviceStatus.online;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Node header with status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nodeDisplayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  label: nodeStatus.displayName,
                  status: nodeStatus,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),

            // If node is not online, inform user that controls are disabled
            if (!controlsEnabled) ...[
              Row(
                children: [
                  Icon(
                    nodeStatus == DeviceStatus.error
                        ? Icons.error_outline
                        : Icons.wifi_off,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      'Node is ${nodeStatus.displayName}. Controls are disabled until online.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
            ],
            
            // Device cards for this node
            if (devices.isEmpty)
              Text(
                'No devices found for this node',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...devices.map((device) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildDeviceCard(device, ref, controlsEnabled),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
    DeviceControlState device,
    WidgetRef ref,
    bool controlsEnabled,
  ) {
    final config = _getDeviceDisplayConfig(device.deviceType);
    
    return DeviceCard(
      title: config.title,
      description: config.description,
      icon: config.icon,
      color: config.color,
      isEnabled: device.isEnabled,
      isPending: device.isPending,
      intensity: device.intensity,
      onToggle: controlsEnabled
          ? (enabled) {
              ref
                  .read(deviceControlsProvider.notifier)
                  .toggleDevice(device.deviceId, enabled);
            }
          : null,
      onIntensityChanged: (device.deviceType == DeviceType.fan ||
                  device.deviceType == DeviceType.light) &&
              controlsEnabled
          ? (intensity) {
              ref
                  .read(deviceControlsProvider.notifier)
                  .setDeviceIntensity(device.deviceId, intensity);
            }
          : null,
    );
  }

  Widget _buildEmergencyStopSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          children: [
            const Icon(Icons.emergency, color: Colors.red, size: 32),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Emergency Stop',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Immediately stops all devices',
              style: theme.textTheme.bodyMedium?.copyWith(
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
    );
  }

  String _getNodeDisplayName(String node) {
    switch (node.toLowerCase()) {
      case 'rpi':
        return 'Raspberry Pi (Main Controller)';
      case 'esp1':
        return 'ESP32 Node 1';
      case 'esp2':
        return 'ESP32 Node 2';
      case 'esp32':
        return 'ESP32 Controller';
      default:
        return '${node.toUpperCase()} Node';
    }
  }

  _DeviceDisplayConfig _getDeviceDisplayConfig(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.pump:
        return const _DeviceDisplayConfig(
          title: 'Water Pump',
          description: 'Nutrient circulation pump',
          icon: Icons.water_drop,
          color: Colors.blue,
        );
      case DeviceType.fan:
        return const _DeviceDisplayConfig(
          title: 'Circulation Fan',
          description: 'Air circulation and ventilation',
          icon: Icons.air,
          color: Colors.cyan,
        );
      case DeviceType.light:
        return const _DeviceDisplayConfig(
          title: 'Grow Light',
          description: 'Plant lighting system',
          icon: Icons.wb_sunny,
          color: Colors.amber,
        );
      case DeviceType.heater:
        return const _DeviceDisplayConfig(
          title: 'Water Heater',
          description: 'Temperature control',
          icon: Icons.thermostat,
          color: Colors.orange,
        );
      case DeviceType.sensor:
        return const _DeviceDisplayConfig(
          title: 'Sensor',
          description: 'Environmental monitoring',
          icon: Icons.sensors,
          color: Colors.green,
        );
      case DeviceType.controller:
        return const _DeviceDisplayConfig(
          title: 'Controller',
          description: 'System control unit',
          icon: Icons.developer_board,
          color: Colors.purple,
        );
    }
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

/// Configuration for device display properties.
class _DeviceDisplayConfig {
  const _DeviceDisplayConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}
