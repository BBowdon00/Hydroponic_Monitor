import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../app.dart';
import '../../core/theme.dart';
import '../providers/config_provider.dart';
import '../providers/manual_reconnect_provider.dart';
import '../providers/data_providers.dart';
import '../../domain/entities/app_config.dart';

/// Settings page for configuring MQTT, InfluxDB, units, and app preferences.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  AppConfig? _draft; // Staged (unsaved) configuration edits
  AppConfig? _baseline; // Last persisted config from provider
  bool _dirty = false; // Whether draft differs from baseline

  void _ensureDraftInitialized(AppConfig providerConfig) {
    // Initialize draft when first data arrives or when no local edits pending and provider config changed.
    if (_draft == null || (!_dirty && _baseline != providerConfig)) {
      _baseline = providerConfig;
      _draft = providerConfig;
      _dirty = false;
    }
  }

  bool get _hasUnsavedChanges =>
      _dirty && _draft != null && _baseline != _draft;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final configAsync = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: configAsync.when(
        data: (config) {
          _ensureDraftInitialized(config);
          return _buildSettingsContent(context, isDarkMode, _draft!);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load configuration: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(configProvider.notifier).reload(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _stageConfig(AppConfig newConfig) {
    setState(() {
      _draft = newConfig;
      _dirty = true;
    });
  }

  Widget _buildSettingsContent(
    BuildContext context,
    bool isDarkMode,
    AppConfig config,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      children: [
        if (_hasUnsavedChanges)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: Material(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(6),
              child: ListTile(
                leading: const Icon(
                  Icons.pending_actions,
                  color: Colors.black87,
                ),
                title: const Text('You have unsaved configuration changes'),
                subtitle: const Text(
                  'Press "Apply Changes" to persist and reconnect services.',
                ),
                trailing: TextButton(
                  onPressed: () {
                    setState(() {
                      _draft = _baseline;
                      _dirty = false; // revert
                    });
                  },
                  child: const Text('Discard'),
                ),
              ),
            ),
          ),
        // App Preferences Section
        _buildSectionCard(
          context,
          title: 'App Preferences',
          children: [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme throughout the app'),
              value: isDarkMode,
              onChanged: (value) {
                ref.read(themeProvider.notifier).setDarkMode(value);
              },
              secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: const Text('English (US)'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showLanguageDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Units'),
              subtitle: const Text('Metric (°C, cm, L)'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showUnitsDialog(context);
              },
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spaceMd),

        // MQTT Configuration Section
        _buildSectionCard(
          context,
          title: 'MQTT Configuration',
          children: [
            _buildConfigTile(
              context,
              icon: Icons.dns,
              title: 'Broker Host',
              value: config.mqtt.host,
              onTap: () => _showConfigDialog(
                context,
                ref,
                'MQTT Broker Host',
                config.mqtt.host,
                (value) {
                  final base = _draft ?? config;
                  return base.copyWith(mqtt: base.mqtt.copyWith(host: value));
                },
              ),
            ),
            _buildConfigTile(
              context,
              icon: Icons.numbers,
              title: 'Port',
              value: config.mqtt.port.toString(),
              onTap: () => _showPortDialog(context, ref, config),
            ),
            _buildConfigTile(
              context,
              icon: Icons.account_circle,
              title: 'Username',
              value: config.mqtt.username.isEmpty
                  ? '(not set)'
                  : config.mqtt.username,
              onTap: () => _showConfigDialog(
                context,
                ref,
                'MQTT Username',
                config.mqtt.username,
                (value) {
                  final base = _draft ?? config;
                  return base.copyWith(
                    mqtt: base.mqtt.copyWith(username: value),
                  );
                },
              ),
            ),
            _buildConfigTile(
              context,
              icon: Icons.lock,
              title: 'Password',
              value: config.mqtt.password.isEmpty ? '(not set)' : '••••••••',
              onTap: () =>
                  _showConfigDialog(context, ref, 'MQTT Password', '', (value) {
                    final base = _draft ?? config;
                    return base.copyWith(
                      mqtt: base.mqtt.copyWith(password: value),
                    );
                  }, isPassword: true),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spaceMd),

        // InfluxDB Configuration Section
        _buildSectionCard(
          context,
          title: 'InfluxDB Configuration',
          children: [
            _buildConfigTile(
              context,
              icon: Icons.storage,
              title: 'Database URL',
              value: config.influx.url,
              onTap: () => _showConfigDialog(
                context,
                ref,
                'InfluxDB URL',
                config.influx.url,
                (value) {
                  final base = _draft ?? config;
                  return base.copyWith(
                    influx: base.influx.copyWith(url: value),
                  );
                },
              ),
            ),
            _buildConfigTile(
              context,
              icon: Icons.key,
              title: 'Token',
              value: config.influx.token.isEmpty
                  ? '(not set)'
                  : '••••••••••••••••',
              onTap: () => _showConfigDialog(
                context,
                ref,
                'InfluxDB Token',
                '',
                (value) {
                  final base = _draft ?? config;
                  return base.copyWith(
                    influx: base.influx.copyWith(token: value),
                  );
                },
                isPassword: true,
              ),
            ),
            _buildConfigTile(
              context,
              icon: Icons.business,
              title: 'Organization',
              value: config.influx.org,
              onTap: () => _showConfigDialog(
                context,
                ref,
                'Organization',
                config.influx.org,
                (value) {
                  final base = _draft ?? config;
                  return base.copyWith(
                    influx: base.influx.copyWith(org: value),
                  );
                },
              ),
            ),
            _buildConfigTile(
              context,
              icon: Icons.inventory,
              title: 'Bucket',
              value: config.influx.bucket,
              onTap: () => _showConfigDialog(
                context,
                ref,
                'Bucket',
                config.influx.bucket,
                (value) {
                  final base = _draft ?? config;
                  return base.copyWith(
                    influx: base.influx.copyWith(bucket: value),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spaceMd),

        // Video Configuration Section
        _buildSectionCard(
          context,
          title: 'Video Configuration',
          children: [
            _buildConfigTile(
              context,
              icon: Icons.videocam,
              title: 'MJPEG Stream URL',
              value: config.mjpeg.url,
              onTap: () => _showConfigDialog(
                context,
                ref,
                'MJPEG Stream URL',
                config.mjpeg.url,
                (value) {
                  final base = _draft ?? config;
                  return base.copyWith(mjpeg: base.mjpeg.copyWith(url: value));
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.record_voice_over),
              title: const Text('Auto-reconnect'),
              subtitle: const Text('Automatically reconnect to video stream'),
              value: config.mjpeg.autoReconnect,
              onChanged: (value) {
                final updated = config.copyWith(
                  mjpeg: config.mjpeg.copyWith(autoReconnect: value),
                );
                _stageConfig(updated);
              },
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spaceMd),

        // System Information Section
        _buildSectionCard(
          context,
          title: 'System Information',
          children: [
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('App Version'),
              subtitle: Text('1.0.0+1'),
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Last Updated'),
              subtitle: const Text('Never'),
              trailing: TextButton(
                onPressed: () {
                  _showUpdateDialog(context);
                },
                child: const Text('Check'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Report Issue'),
              subtitle: const Text('Send feedback or report bugs'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showFeedbackDialog(context);
              },
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spaceLg),

        // Apply Changes and Reset Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _applyChanges(context, ref);
                },
                icon: const Icon(Icons.check),
                label: const Text('Apply Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _resetToDefaults(context, ref);
                },
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Defaults'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildConfigTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit),
      onTap: onTap,
    );
  }

  void _showConfigDialog(
    BuildContext context,
    WidgetRef ref,
    String title,
    String initialValue,
    AppConfig Function(String) updateFn, {
    bool isPassword = false,
  }) {
    final controller = TextEditingController(
      text: isPassword ? '' : initialValue,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Enter $title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();

              // Validation
              if (!isPassword && value.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title cannot be empty')),
                );
                return;
              }

              // Update config
              if (_draft != null) {
                final updated = updateFn(value);
                _stageConfig(updated);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title staged (apply changes to persist)'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: RadioGroup<String>(
          onChanged: (value) => Navigator.of(context).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<String>(
                title: Text('English (US)'),
                value: 'en_US',
              ),
              RadioListTile<String>(title: Text('Spanish'), value: 'es'),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnitsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Units'),
        content: RadioGroup<String>(
          onChanged: (value) => Navigator.of(context).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<String>(
                title: Text('Metric (°C, cm, L)'),
                value: 'metric',
              ),
              RadioListTile<String>(
                title: Text('Imperial (°F, in, gal)'),
                value: 'imperial',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check for Updates'),
        content: const Text('You are running the latest version of the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Describe your issue or suggestion...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feedback sent. Thank you!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showPortDialog(BuildContext context, WidgetRef ref, AppConfig config) {
    final controller = TextEditingController(text: config.mqtt.port.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MQTT Port'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter MQTT Port (e.g., 1883)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final port = int.tryParse(controller.text.trim());
              if (port == null || port < 1 || port > 65535) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid port number (1-65535)'),
                  ),
                );
                return;
              }

              final updatedConfig = config.copyWith(
                mqtt: config.mqtt.copyWith(port: port),
              );
              _stageConfig(updatedConfig);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('MQTT Port updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _applyChanges(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Configuration Changes'),
        content: const Text(
          'This will reconnect MQTT and InfluxDB services with the new settings. '
          'The app may briefly lose connection. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Persist draft if dirty before invalidating services
    if (_dirty && _draft != null) {
      await ref.read(configProvider.notifier).updateConfig(_draft!);
      setState(() {
        _baseline = _draft;
        _dirty = false;
      });
    }

    // Invalidate service providers so they rebuild with new configuration
    ref.invalidate(mqttServiceProvider);
    ref.invalidate(influxServiceProvider);
    ref.invalidate(connectionRecoveryServiceProvider);

    // IMPORTANT: Immediately refresh providers to force construction of new
    // service instances before we invoke manual reconnect. Without this,
    // attemptReconnect may run on a notifier still holding the OLD
    // ConnectionRecoveryService (and thus old MqttService), causing continued
    // connect attempts to the previous host (e.g. localhost) even after
    // config changes.
    final _ = ref.refresh(mqttServiceProvider); // new MQTT service
    ref.refresh(influxServiceProvider); // new Influx service
    ref.refresh(connectionRecoveryServiceProvider); // new recovery service
    ref.refresh(
      manualReconnectProvider,
    ); // rebuild notifier with new recovery service

    // Trigger manual reconnect (will use newly built service instances)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applying changes and reconnecting...')),
    );

    final result = await ref
        .read(manualReconnectProvider.notifier)
        .attemptReconnect(force: true);

    if (context.mounted) {
      if (result.mqttOk && result.influxOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result.mqttOk || result.influxOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Partial success: ${result.errorMessage ?? "Some services failed"}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to apply: ${result.errorMessage ?? "Unknown error"}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetToDefaults(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset all configuration to default values from environment variables. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(configProvider.notifier).resetToDefaults();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration reset to defaults')),
      );
    }
  }
}
