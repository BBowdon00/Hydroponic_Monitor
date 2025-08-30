import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/theme.dart';
import 'package:hydroponic_monitor/presentation/providers/sensor_providers.dart';
import 'package:hydroponic_monitor/presentation/widgets/sensor_tile.dart';

/// Dashboard page showing real-time sensor data
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorDataAsync = ref.watch(sensorDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(sensorDataProvider),
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(sensorDataProvider),
        child: sensorDataAsync.when(
          data: (sensors) => _buildDashboard(context, ref, sensors),
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => _buildErrorView(context, error),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, List sensors) {
    return CustomScrollView(
      slivers: [
        // System status header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: _SystemStatusCard(sensorsOnline: sensors.where((s) => s.isOnline).length),
          ),
        ),
        
        // Sensor grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              childAspectRatio: 1.2,
              crossAxisSpacing: AppTheme.space8,
              mainAxisSpacing: AppTheme.space8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final sensor = sensors[index];
                final sparklineData = ref.watch(sensorHistoryProvider(sensor.type));
                
                return SensorTile(
                  sensorReading: sensor,
                  showSparkline: true,
                  sparklineData: sparklineData,
                  onTap: () => _showSensorDetails(context, sensor),
                );
              },
              childCount: sensors.length,
            ),
          ),
        ),
        
        // Quick actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: _QuickActionsCard(),
          ),
        ),
        
        // Add some bottom padding for the navigation bar
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTheme.space24),
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'Failed to load sensor data',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              error.toString(),
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

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }

  void _showSensorDetails(BuildContext context, sensor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                '${sensor.type.displayName} Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppTheme.space16),
              SensorTile(
                sensorReading: sensor,
                showSparkline: true,
                sparklineData: const [1, 2, 3, 4, 5],
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                'Historical Data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.space8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Center(
                  child: Text('Chart placeholder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// System status overview card
class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard({required this.sensorsOnline});
  
  final int sensorsOnline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                Icons.eco,
                color: colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(width: AppTheme.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    '$sensorsOnline sensors online',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sensorsOnline > 4 ? colorScheme.primary : colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick actions card
class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            Wrap(
              spacing: AppTheme.space8,
              runSpacing: AppTheme.space8,
              children: [
                _QuickActionChip(
                  label: 'Water System',
                  icon: Icons.water_drop,
                  onTap: () {},
                ),
                _QuickActionChip(
                  label: 'Lighting',
                  icon: Icons.lightbulb,
                  onTap: () {},
                ),
                _QuickActionChip(
                  label: 'Ventilation',
                  icon: Icons.air,
                  onTap: () {},
                ),
                _QuickActionChip(
                  label: 'Alerts',
                  icon: Icons.notifications,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action chip widget
class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon),
      label: Text(label),
      onPressed: onTap,
    );
  }
}