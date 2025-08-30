import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/theme.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';

/// Charts page for viewing historical sensor data
class ChartsPage extends ConsumerStatefulWidget {
  const ChartsPage({super.key});

  @override
  ConsumerState<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends ConsumerState<ChartsPage> {
  String _selectedTimeRange = '24h';
  SensorType? _selectedSensorType;

  final List<String> _timeRanges = ['1h', '6h', '24h', '7d', '30d'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'Export data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Time range selector
          _buildTimeRangeSelector(),
          
          // Sensor type filter
          _buildSensorTypeFilter(),
          
          // Charts area
          Expanded(
            child: _buildChartsArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time Range',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Wrap(
                spacing: AppTheme.space8,
                children: _timeRanges.map((range) {
                  final isSelected = _selectedTimeRange == range;
                  return ChoiceChip(
                    label: Text(range),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTimeRange = range;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorTypeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sensor Filter',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              DropdownButtonFormField<SensorType?>(
                value: _selectedSensorType,
                decoration: const InputDecoration(
                  labelText: 'Select sensor type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<SensorType?>(
                    value: null,
                    child: Text('All Sensors'),
                  ),
                  ...SensorType.values.map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSensorType = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsArea() {
    final sensorsToShow = _selectedSensorType != null
        ? [_selectedSensorType!]
        : SensorType.values;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: ListView.builder(
        itemCount: sensorsToShow.length,
        itemBuilder: (context, index) {
          final sensorType = sensorsToShow[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space16),
            child: _ChartCard(
              sensorType: sensorType,
              timeRange: _selectedTimeRange,
            ),
          );
        },
      ),
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'Choose the format for exporting your sensor data:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showExportSuccess('CSV');
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showExportSuccess('JSON');
            },
            child: const Text('JSON'),
          ),
        ],
      ),
    );
  }

  void _showExportSuccess(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Data exported as $format successfully'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Individual chart card widget
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.sensorType,
    required this.timeRange,
  });

  final SensorType sensorType;
  final String timeRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart header
            Row(
              children: [
                Icon(
                  _getIconForSensorType(sensorType),
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    sensorType.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text(timeRange),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.space16),
            
            // Chart placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(128),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: colorScheme.outline.withAlpha(128),
                ),
              ),
              child: Stack(
                children: [
                  // Grid background
                  _buildChartGrid(colorScheme),
                  
                  // Chart content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withAlpha(128),
                        ),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          'Historical ${sensorType.displayName} Data',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Chart would display here using fl_chart',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withAlpha(178),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppTheme.space12),
            
            // Chart stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Min',
                  value: _getMockValue(sensorType, 'min'),
                  unit: sensorType.defaultUnit,
                ),
                _StatItem(
                  label: 'Max',
                  value: _getMockValue(sensorType, 'max'),
                  unit: sensorType.defaultUnit,
                ),
                _StatItem(
                  label: 'Avg',
                  value: _getMockValue(sensorType, 'avg'),
                  unit: sensorType.defaultUnit,
                ),
                _StatItem(
                  label: 'Current',
                  value: _getMockValue(sensorType, 'current'),
                  unit: sensorType.defaultUnit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartGrid(ColorScheme colorScheme) {
    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _GridPainter(colorScheme.outline.withAlpha(64)),
    );
  }

  IconData _getIconForSensorType(SensorType type) {
    switch (type) {
      case SensorType.temperature:
        return Icons.thermostat;
      case SensorType.humidity:
        return Icons.water_drop;
      case SensorType.waterLevel:
        return Icons.waves;
      case SensorType.ph:
        return Icons.science;
      case SensorType.electricalConductivity:
        return Icons.electrical_services;
      case SensorType.lightIntensity:
        return Icons.wb_sunny;
      case SensorType.pressure:
        return Icons.compress;
    }
  }

  String _getMockValue(SensorType type, String stat) {
    // Mock values for demonstration
    switch (type) {
      case SensorType.temperature:
        switch (stat) {
          case 'min': return '18.2';
          case 'max': return '26.8';
          case 'avg': return '22.5';
          case 'current': return '23.1';
        }
      case SensorType.humidity:
        switch (stat) {
          case 'min': return '52';
          case 'max': return '78';
          case 'avg': return '65';
          case 'current': return '67';
        }
      default:
        return '0.0';
    }
    return '0.0';
  }
}

/// Statistics item widget
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for chart grid
class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    // Draw horizontal lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw vertical lines
    for (int i = 0; i <= 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}