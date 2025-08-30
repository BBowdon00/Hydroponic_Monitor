import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme.dart';

/// Charts page for viewing historical sensor data and trends.
class ChartsPage extends ConsumerWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(chartRangeProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh charts
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          children: [
            // Time range selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Range',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ChartRange.values.map((range) {
                          final isSelected = selectedRange == range;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppTheme.spaceSm),
                            child: FilterChip(
                              label: Text(_getRangeLabel(range)),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  ref.read(chartRangeProvider.notifier).setRange(range);
                                }
                              },
                              selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                              checkmarkColor: theme.colorScheme.primary,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // Charts area
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: _buildChartsPlaceholder(context),
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // Chart legend and statistics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistics',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    _buildStatisticsGrid(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'No Data Yet',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Charts will appear here once sensor data is collected',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          // Placeholder chart area
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    'Chart Area',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(BuildContext context) {
    final theme = Theme.of(context);
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppTheme.spaceMd,
      mainAxisSpacing: AppTheme.spaceMd,
      childAspectRatio: 2.5,
      children: [
        _buildStatCard(
          context,
          title: 'Avg Temperature',
          value: '24.2°C',
          trend: '+0.5°C',
          trendPositive: true,
        ),
        _buildStatCard(
          context,
          title: 'Avg Humidity',
          value: '68%',
          trend: '-2%',
          trendPositive: false,
        ),
        _buildStatCard(
          context,
          title: 'Water Usage',
          value: '15.2L',
          trend: '+1.2L',
          trendPositive: null,
        ),
        _buildStatCard(
          context,
          title: 'pH Stability',
          value: '±0.1',
          trend: 'Good',
          trendPositive: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String trend,
    bool? trendPositive,
  }) {
    final theme = Theme.of(context);
    
    Color? trendColor;
    if (trendPositive != null) {
      trendColor = trendPositive ? Colors.green : Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            trend,
            style: theme.textTheme.bodySmall?.copyWith(
              color: trendColor ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getRangeLabel(ChartRange range) {
    switch (range) {
      case ChartRange.hour1:
        return '1h';
      case ChartRange.hours24:
        return '24h';
      case ChartRange.days7:
        return '7d';
      case ChartRange.days30:
        return '30d';
    }
  }
}

/// Chart time range options.
enum ChartRange {
  hour1,
  hours24,
  days7,
  days30,
}

/// Provider for selected chart range.
final chartRangeProvider = StateNotifierProvider<ChartRangeNotifier, ChartRange>((ref) {
  return ChartRangeNotifier();
});

class ChartRangeNotifier extends StateNotifier<ChartRange> {
  ChartRangeNotifier() : super(ChartRange.hours24);

  void setRange(ChartRange range) {
    state = range;
  }
}