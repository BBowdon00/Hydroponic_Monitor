import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/entities/sensor_data.dart';
import '../widgets/sensor_chart_card.dart';
import '../providers/chart_providers.dart';

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
              // Increment refresh trigger to invalidate all chart data
              ref.read(chartDataRefreshTriggerProvider.notifier).state++;
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
                    Text('Time Range', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppTheme.spaceSm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ChartRange.values.map((range) {
                          final isSelected = selectedRange == range;
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppTheme.spaceSm,
                            ),
                            child: FilterChip(
                              label: Text(_getRangeLabel(range)),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  ref
                                      .read(chartRangeProvider.notifier)
                                      .setRange(range);
                                }
                              },
                              selectedColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
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

            // Charts area - Grid of sensor chart cards
            Expanded(
              child: _buildChartsGrid(context, selectedRange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsGrid(BuildContext context, ChartRange selectedRange) {
    // Order sensors by importance as specified in TASK011
    const sensorOrder = [
      SensorType.temperature,
      SensorType.humidity,
      SensorType.pH,
      SensorType.electricalConductivity,
      SensorType.waterLevel,
      SensorType.lightIntensity,
      SensorType.airQuality,
      SensorType.powerUsage,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: adjust columns based on screen width
        final crossAxisCount = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 800
                ? 2
                : 1;

        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppTheme.spaceMd,
            mainAxisSpacing: AppTheme.spaceMd,
            childAspectRatio: 1.4,
          ),
          itemCount: sensorOrder.length,
          itemBuilder: (context, index) {
            return SensorChartCard(
              sensorType: sensorOrder[index],
              range: selectedRange,
            );
          },
        );
      },
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
enum ChartRange { hour1, hours24, days7, days30 }

/// Provider for selected chart range.
final chartRangeProvider =
    StateNotifierProvider<ChartRangeNotifier, ChartRange>((ref) {
      return ChartRangeNotifier();
    });

class ChartRangeNotifier extends StateNotifier<ChartRange> {
  ChartRangeNotifier() : super(ChartRange.hours24);

  void setRange(ChartRange range) {
    state = range;
  }
}
