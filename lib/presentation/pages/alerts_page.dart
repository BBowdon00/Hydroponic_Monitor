import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/theme.dart';

/// Alerts page for managing system alerts and rules
class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Rules', icon: Icon(Icons.rule)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert),
            onPressed: _showCreateRuleDialog,
            tooltip: 'Add alert rule',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRulesTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.space16),
      children: [
        // Alert rules overview
        _buildRulesOverview(),
        
        const SizedBox(height: AppTheme.space16),
        
        // Rules list
        ..._mockAlertRules.map((rule) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space8),
          child: _AlertRuleCard(
            rule: rule,
            onToggle: () => _toggleRule(rule.id),
            onEdit: () => _editRule(rule),
            onDelete: () => _deleteRule(rule.id),
          ),
        )),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.space16),
      children: [
        // Recent alerts overview
        _buildHistoryOverview(),
        
        const SizedBox(height: AppTheme.space16),
        
        // Alert history list
        ..._mockAlertHistory.map((alert) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.space8),
          child: _AlertHistoryCard(alert: alert),
        )),
      ],
    );
  }

  Widget _buildRulesOverview() {
    final activeRules = _mockAlertRules.where((r) => r.isEnabled).length;
    final totalRules = _mockAlertRules.length;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rule,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Alert Rules',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Total Rules',
                    value: '$totalRules',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: _StatChip(
                    label: 'Active',
                    value: '$activeRules',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: _StatChip(
                    label: 'Disabled',
                    value: '${totalRules - activeRules}',
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryOverview() {
    final recentAlerts = _mockAlertHistory.where((a) => 
        DateTime.now().difference(a.timestamp).inHours < 24).length;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Alert History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Last 24h',
                    value: '$recentAlerts',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: _StatChip(
                    label: 'This Week',
                    value: '${_mockAlertHistory.length}',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: _StatChip(
                    label: 'Critical',
                    value: '${_mockAlertHistory.where((a) => a.severity == AlertSeverity.critical).length}',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRule(String ruleId) {
    // Mock toggle functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alert rule $ruleId toggled'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editRule(_AlertRule rule) {
    _showCreateRuleDialog(editingRule: rule);
  }

  void _deleteRule(String ruleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alert Rule'),
        content: const Text('Are you sure you want to delete this alert rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alert rule deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateRuleDialog({_AlertRule? editingRule}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editingRule != null ? 'Edit Alert Rule' : 'Create Alert Rule'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Rule Name',
                    hintText: 'e.g., High Temperature Alert',
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Sensor Type'),
                  items: const [
                    DropdownMenuItem(value: 'temperature', child: Text('Temperature')),
                    DropdownMenuItem(value: 'humidity', child: Text('Humidity')),
                    DropdownMenuItem(value: 'ph', child: Text('pH Level')),
                  ],
                  onChanged: (value) {},
                ),
                const SizedBox(height: AppTheme.space16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: const [
                    DropdownMenuItem(value: 'greater', child: Text('Greater than')),
                    DropdownMenuItem(value: 'less', child: Text('Less than')),
                    DropdownMenuItem(value: 'equal', child: Text('Equal to')),
                  ],
                  onChanged: (value) {},
                ),
                const SizedBox(height: AppTheme.space16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Threshold Value',
                    hintText: 'e.g., 25.0',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(editingRule != null 
                      ? 'Alert rule updated' 
                      : 'Alert rule created'),
                ),
              );
            },
            child: Text(editingRule != null ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }
}

/// Alert rule card widget
class _AlertRuleCard extends StatelessWidget {
  const _AlertRuleCard({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final _AlertRule rule;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            Row(
              children: [
                Icon(
                  _getSeverityIcon(rule.severity),
                  color: _getSeverityColor(rule.severity, colorScheme),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    rule.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: rule.isEnabled,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              rule.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                Chip(
                  label: Text(rule.severity.name.toUpperCase()),
                  backgroundColor: _getSeverityColor(rule.severity, colorScheme).withAlpha(51),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  tooltip: 'Edit rule',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete rule',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Icons.info;
      case AlertSeverity.medium:
        return Icons.warning;
      case AlertSeverity.high:
        return Icons.error;
      case AlertSeverity.critical:
        return Icons.dangerous;
    }
  }

  Color _getSeverityColor(AlertSeverity severity, ColorScheme colorScheme) {
    switch (severity) {
      case AlertSeverity.low:
        return colorScheme.primary;
      case AlertSeverity.medium:
        return Colors.orange;
      case AlertSeverity.high:
        return colorScheme.error;
      case AlertSeverity.critical:
        return Colors.red;
    }
  }
}

/// Alert history card widget
class _AlertHistoryCard extends StatelessWidget {
  const _AlertHistoryCard({required this.alert});

  final _AlertEvent alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSeverityColor(alert.severity, colorScheme).withAlpha(51),
          child: Icon(
            _getSeverityIcon(alert.severity),
            color: _getSeverityColor(alert.severity, colorScheme),
            size: 20,
          ),
        ),
        title: Text(alert.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message),
            const SizedBox(height: AppTheme.space4),
            Text(
              _formatTimestamp(alert.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _getSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Icons.info;
      case AlertSeverity.medium:
        return Icons.warning;
      case AlertSeverity.high:
        return Icons.error;
      case AlertSeverity.critical:
        return Icons.dangerous;
    }
  }

  Color _getSeverityColor(AlertSeverity severity, ColorScheme colorScheme) {
    switch (severity) {
      case AlertSeverity.low:
        return colorScheme.primary;
      case AlertSeverity.medium:
        return Colors.orange;
      case AlertSeverity.high:
        return colorScheme.error;
      case AlertSeverity.critical:
        return Colors.red;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Statistics chip widget
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Mock data classes and enums
enum AlertSeverity { low, medium, high, critical }

class _AlertRule {
  const _AlertRule({
    required this.id,
    required this.name,
    required this.description,
    required this.severity,
    required this.isEnabled,
  });

  final String id;
  final String name;
  final String description;
  final AlertSeverity severity;
  final bool isEnabled;
}

class _AlertEvent {
  const _AlertEvent({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
}

// Mock data
final _mockAlertRules = [
  _AlertRule(
    id: '1',
    name: 'High Temperature Alert',
    description: 'Trigger when temperature exceeds 30°C',
    severity: AlertSeverity.high,
    isEnabled: true,
  ),
  _AlertRule(
    id: '2',
    name: 'Low Water Level',
    description: 'Alert when water level drops below 20cm',
    severity: AlertSeverity.critical,
    isEnabled: true,
  ),
  _AlertRule(
    id: '3',
    name: 'pH Out of Range',
    description: 'Monitor pH levels outside 5.5-7.0 range',
    severity: AlertSeverity.medium,
    isEnabled: false,
  ),
];

final _mockAlertHistory = [
  _AlertEvent(
    id: '1',
    title: 'High Temperature Detected',
    message: 'Temperature reached 32.1°C in Greenhouse A',
    severity: AlertSeverity.high,
    timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  _AlertEvent(
    id: '2',
    title: 'Pump Offline',
    message: 'Water pump has been offline for 5 minutes',
    severity: AlertSeverity.critical,
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  _AlertEvent(
    id: '3',
    title: 'Low Humidity Warning',
    message: 'Humidity level dropped to 45%',
    severity: AlertSeverity.medium,
    timestamp: DateTime.now().subtract(const Duration(hours: 6)),
  ),
];