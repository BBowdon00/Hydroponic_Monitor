import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/entities/sensor_data.dart';
import '../providers/sensor_providers.dart';
import '../widgets/sensor_chart_card.dart';

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
              ref.read(chartRefreshProvider.notifier).state++;
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

            // Charts area
            Expanded(child: _buildChartsGrid(context, selectedRange)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsGrid(BuildContext context, ChartRange selectedRange) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: more columns on wider screens
        final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppTheme.spaceMd,
            mainAxisSpacing: AppTheme.spaceMd,
            childAspectRatio: 1.2,
          ),
          itemCount: SensorType.values.length,
          itemBuilder: (context, index) {
            final sensorType = SensorType.values[index];
            return SensorChartCard(
              sensorType: sensorType,
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
    }
  }
}

/// Chart time range options.
enum ChartRange { hour1, hours24, days7 }

extension ChartRangeExtension on ChartRange {
  Duration get duration {
    switch (this) {
      case ChartRange.hour1:
        return const Duration(hours: 1);
      case ChartRange.hours24:
        return const Duration(hours: 24);
      case ChartRange.days7:
        return const Duration(days: 7);
    }
  }

  String get aggregationWindow {
    switch (this) {
      case ChartRange.hour1:
        return '2m'; // 2-minute aggregation for 1 hour (30 points)
      case ChartRange.hours24:
        return '30m'; // 30-minute aggregation for 24 hours (48 points)
      case ChartRange.days7:
        return '4h'; // 4-hour aggregation for 7 days (42 points)
    }
  }

  int get expectedPoints {
    switch (this) {
      case ChartRange.hour1:
        return 30;
      case ChartRange.hours24:
        return 48;
      case ChartRange.days7:
        return 42;
    }
  }
}

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
