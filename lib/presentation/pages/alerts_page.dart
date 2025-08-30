import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/status_badge.dart';
import '../../core/theme.dart';

/// Alerts page for managing alert rules and viewing incident history.
class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertRules = ref.watch(alertRulesProvider);
    final incidents = ref.watch(incidentsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alerts & Notifications'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Rules', icon: Icon(Icons.rule)),
              Tab(text: 'History', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRulesTab(context, ref, alertRules),
            _buildHistoryTab(context, ref, incidents),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesTab(
    BuildContext context,
    WidgetRef ref,
    List<AlertRule> rules,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        children: [
          // Add new rule button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showAddRuleDialog(context, ref);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New Rule'),
            ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Rules list
          Expanded(
            child: ListView.builder(
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                  child: ListTile(
                    leading: Icon(
                      _getAlertIcon(rule.type),
                      color: _getAlertColor(rule.severity),
                    ),
                    title: Text(rule.name),
                    subtitle: Text(rule.condition),
                    trailing: SizedBox(
                      width: 120, // Fixed width to prevent overflow
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: StatusBadge(
                              label: rule.severity.name.toUpperCase(),
                              status: rule.isEnabled
                                  ? DeviceStatus.online
                                  : DeviceStatus.offline,
                              showIcon: false,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          Switch(
                            value: rule.isEnabled,
                            onChanged: (enabled) {
                              ref
                                  .read(alertRulesProvider.notifier)
                                  .toggleRule(rule.id, enabled);
                            },
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      _showRuleDetails(context, ref, rule);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    WidgetRef ref,
    List<AlertIncident> incidents,
  ) {
    if (incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text('No Incidents', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'All systems are running normally',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: ListView.builder(
        itemCount: incidents.length,
        itemBuilder: (context, index) {
          final incident = incidents[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: ListTile(
              leading: Icon(
                _getAlertIcon(incident.type),
                color: _getAlertColor(incident.severity),
              ),
              title: Text(incident.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(incident.description),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    _formatDateTime(incident.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              trailing: StatusBadge(
                label: incident.status.name.toUpperCase(),
                status: incident.status == IncidentStatus.resolved
                    ? DeviceStatus.online
                    : DeviceStatus.error,
                showIcon: false,
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Alert Rule'),
        content: const Text(
          'Alert rule configuration will be implemented here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add mock rule for demo
              ref
                  .read(alertRulesProvider.notifier)
                  .addRule(
                    AlertRule(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: 'New Alert Rule',
                      condition: 'Temperature > 30°C',
                      type: AlertType.temperature,
                      severity: AlertSeverity.warning,
                      isEnabled: true,
                    ),
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRuleDetails(BuildContext context, WidgetRef ref, AlertRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rule.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Condition: ${rule.condition}'),
            const SizedBox(height: AppTheme.spaceSm),
            Text('Type: ${rule.type.name}'),
            const SizedBox(height: AppTheme.spaceSm),
            Text('Severity: ${rule.severity.name}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(alertRulesProvider.notifier).deleteRule(rule.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.temperature:
        return Icons.thermostat;
      case AlertType.humidity:
        return Icons.opacity;
      case AlertType.waterLevel:
        return Icons.water_drop;
      case AlertType.pH:
        return Icons.science;
      case AlertType.system:
        return Icons.settings;
    }
  }

  Color _getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return Colors.blue;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.critical:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Alert rule model.
class AlertRule {
  const AlertRule({
    required this.id,
    required this.name,
    required this.condition,
    required this.type,
    required this.severity,
    required this.isEnabled,
  });

  final String id;
  final String name;
  final String condition;
  final AlertType type;
  final AlertSeverity severity;
  final bool isEnabled;

  AlertRule copyWith({
    String? id,
    String? name,
    String? condition,
    AlertType? type,
    AlertSeverity? severity,
    bool? isEnabled,
  }) {
    return AlertRule(
      id: id ?? this.id,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Alert incident model.
class AlertIncident {
  const AlertIncident({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.severity,
    required this.status,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String description;
  final AlertType type;
  final AlertSeverity severity;
  final IncidentStatus status;
  final DateTime timestamp;
}

enum AlertType { temperature, humidity, waterLevel, pH, system }

enum AlertSeverity { info, warning, critical }

enum IncidentStatus { active, resolved }

/// Provider for alert rules.
final alertRulesProvider =
    StateNotifierProvider<AlertRulesNotifier, List<AlertRule>>((ref) {
      return AlertRulesNotifier();
    });

class AlertRulesNotifier extends StateNotifier<List<AlertRule>> {
  AlertRulesNotifier() : super(_getInitialRules());

  static List<AlertRule> _getInitialRules() {
    return [
      const AlertRule(
        id: '1',
        name: 'High Temperature',
        condition: 'Temperature > 28°C',
        type: AlertType.temperature,
        severity: AlertSeverity.warning,
        isEnabled: true,
      ),
      const AlertRule(
        id: '2',
        name: 'Low Water Level',
        condition: 'Water Level < 10cm',
        type: AlertType.waterLevel,
        severity: AlertSeverity.critical,
        isEnabled: true,
      ),
      const AlertRule(
        id: '3',
        name: 'pH Out of Range',
        condition: 'pH < 5.5 or pH > 7.5',
        type: AlertType.pH,
        severity: AlertSeverity.warning,
        isEnabled: false,
      ),
    ];
  }

  void toggleRule(String id, bool enabled) {
    state = state.map((rule) {
      if (rule.id == id) {
        return rule.copyWith(isEnabled: enabled);
      }
      return rule;
    }).toList();
  }

  void addRule(AlertRule rule) {
    state = [...state, rule];
  }

  void deleteRule(String id) {
    state = state.where((rule) => rule.id != id).toList();
  }
}

/// Provider for alert incidents.
final incidentsProvider =
    StateNotifierProvider<IncidentsNotifier, List<AlertIncident>>((ref) {
      return IncidentsNotifier();
    });

class IncidentsNotifier extends StateNotifier<List<AlertIncident>> {
  IncidentsNotifier() : super([]);
}
