import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/theme.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/presentation/providers/device_providers.dart';
import 'package:hydroponic_monitor/presentation/widgets/device_card.dart';

/// Devices page for controlling hydroponic system devices
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter devices',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Devices'),
              ),
              ...DeviceType.values.map(
                (type) => PopupMenuItem(
                  value: type,
                  child: Text(type.displayName),
                ),
              ),
            ],
            onSelected: (DeviceType? type) {
              // TODO: Implement filtering
            },
          ),
        ],
      ),
      body: devices.isEmpty
          ? _buildEmptyState(context)
          : _buildDeviceList(context, ref, devices),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Check your device connections and configuration.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, WidgetRef ref, List<Device> devices) {
    // Group devices by type for better organization
    final deviceGroups = <DeviceType, List<Device>>{};
    for (final device in devices) {
      deviceGroups.putIfAbsent(device.type, () => []).add(device);
    }

    return CustomScrollView(
      slivers: [
        // Overview stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: _DeviceOverviewCard(devices: devices),
          ),
        ),
        
        // Device groups
        ...deviceGroups.entries.map((entry) =>
          _buildDeviceGroup(context, ref, entry.key, entry.value),
        ),
        
        // Add bottom padding for navigation bar
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTheme.space24),
        ),
      ],
    );
  }

  Widget _buildDeviceGroup(
    BuildContext context,
    WidgetRef ref,
    DeviceType type,
    List<Device> devices,
  ) {
    return SliverMainAxisGroup(
      slivers: [
        // Group header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space16,
              AppTheme.space16,
              AppTheme.space16,
              AppTheme.space8,
            ),
            child: Row(
              children: [
                Icon(
                  _getIconForDeviceType(type),
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  type.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Chip(
                  label: Text('${devices.length}'),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
        
        // Device cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final device = devices[index];
                return DeviceCard(
                  device: device,
                  onToggle: device.isControllable
                      ? () => _toggleDevice(ref, device.id)
                      : null,
                  onIntensityChanged: device.type.hasIntensityControl && device.isControllable
                      ? (intensity) => _updateIntensity(ref, device.id, intensity)
                      : null,
                );
              },
              childCount: devices.length,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForDeviceType(DeviceType type) {
    switch (type) {
      case DeviceType.pump:
        return Icons.water_drop;
      case DeviceType.fan:
        return Icons.air;
      case DeviceType.light:
        return Icons.lightbulb;
      case DeviceType.heater:
        return Icons.heat_pump;
      case DeviceType.valve:
        return Icons.valve;
    }
  }

  Future<void> _toggleDevice(WidgetRef ref, String deviceId) async {
    try {
      await ref.read(deviceProvider.notifier).toggleDevice(deviceId);
      // Success feedback could be added here
    } catch (e) {
      // Error handling could be added here
    }
  }

  Future<void> _updateIntensity(WidgetRef ref, String deviceId, double intensity) async {
    try {
      await ref.read(deviceProvider.notifier).updateIntensity(deviceId, intensity);
    } catch (e) {
      // Error handling could be added here
    }
  }
}

/// Device overview stats card
class _DeviceOverviewCard extends StatelessWidget {
  const _DeviceOverviewCard({required this.devices});
  
  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final onlineCount = devices.where((d) => d.status == DeviceStatus.online).length;
    final activeCount = devices.where((d) => d.isOn).length;
    final errorCount = devices.where((d) => d.status == DeviceStatus.error).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Total',
                    value: '${devices.length}',
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Online',
                    value: '$onlineCount',
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Active',
                    value: '$activeCount',
                    color: colorScheme.secondary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Errors',
                    value: '$errorCount',
                    color: errorCount > 0 ? colorScheme.error : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual stat item
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}