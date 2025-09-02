import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../app.dart';
import '../../core/theme.dart';
import '../providers/data_providers.dart';
import '../../core/logger.dart';

/// Settings page for configuring MQTT, InfluxDB, units, and app preferences.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        children: [
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
                secondary: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
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
                value: 'mqtt.example.com',
                onTap: () => _showConfigDialog(
                  context,
                  'MQTT Broker Host',
                  'mqtt.example.com',
                ),
              ),
              _buildConfigTile(
                context,
                icon: Icons.numbers,
                title: 'Port',
                value: '1883',
                onTap: () => _showConfigDialog(context, 'MQTT Port', '1883'),
              ),
              _buildConfigTile(
                context,
                icon: Icons.account_circle,
                title: 'Username',
                value: 'hydro_user',
                onTap: () =>
                    _showConfigDialog(context, 'MQTT Username', 'hydro_user'),
              ),
              _buildConfigTile(
                context,
                icon: Icons.lock,
                title: 'Password',
                value: '••••••••',
                onTap: () => _showConfigDialog(
                  context,
                  'MQTT Password',
                  '',
                  isPassword: true,
                ),
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
                value: 'http://influxdb.local:8086',
                onTap: () => _showConfigDialog(
                  context,
                  'InfluxDB URL',
                  'http://influxdb.local:8086',
                ),
              ),
              _buildConfigTile(
                context,
                icon: Icons.key,
                title: 'Token',
                value: '••••••••••••••••',
                onTap: () => _showConfigDialog(
                  context,
                  'InfluxDB Token',
                  '',
                  isPassword: true,
                ),
              ),
              _buildConfigTile(
                context,
                icon: Icons.business,
                title: 'Organization',
                value: 'hydroponic-monitor',
                onTap: () => _showConfigDialog(
                  context,
                  'Organization',
                  'hydroponic-monitor',
                ),
              ),
              _buildConfigTile(
                context,
                icon: Icons.inventory,
                title: 'Bucket',
                value: 'sensors',
                onTap: () => _showConfigDialog(context, 'Bucket', 'sensors'),
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
                value: 'http://raspberry.local:8080/stream',
                onTap: () => _showConfigDialog(
                  context,
                  'MJPEG Stream URL',
                  'http://raspberry.local:8080/stream',
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over),
                title: const Text('Auto-reconnect'),
                subtitle: const Text('Automatically reconnect to video stream'),
                value: true,
                onChanged: (value) {
                  // Handle auto-reconnect toggle
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

          // Test Connection Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _testMqttConnection(context);
                  },
                  icon: const Icon(Icons.wifi),
                  label: const Text('Test MQTT'),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _testInfluxConnection(context);
                  },
                  icon: const Icon(Icons.storage),
                  label: const Text('Test InfluxDB'),
                ),
              ),
            ],
          ),
        ],
      ),
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
    String title,
    String initialValue, {
    bool isPassword = false,
  }) {
    final controller = TextEditingController(text: initialValue);

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
            onPressed: () {
              // Save configuration
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$title updated')));
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
            children: [
              const RadioListTile<String>(
                title: Text('English (US)'),
                value: 'en_US',
              ),
              const RadioListTile<String>(title: Text('Spanish'), value: 'es'),
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
            children: [
              const RadioListTile<String>(
                title: Text('Metric (°C, cm, L)'),
                value: 'metric',
              ),
              const RadioListTile<String>(
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

  void _testMqttConnection(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Testing MQTT connection...')));

    // Test actual MQTT connection using the service
    final container = ProviderScope.containerOf(context);
    final mqttService = container.read(mqttServiceProvider);

    mqttService.connect().then((result) {
      if (context.mounted) {
        result.when(
          success: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('MQTT connection successful!'),
                backgroundColor: Colors.green,
              ),
            );
            Logger.info('MQTT connection test successful', tag: 'Settings');
          },
          failure: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('MQTT connection failed: ${error.message}'),
                backgroundColor: Colors.red,
              ),
            );
            Logger.error(
              'MQTT connection test failed: ${error.message}',
              tag: 'Settings',
            );
          },
        );
      }
    });
  }

  void _testInfluxConnection(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing InfluxDB connection...')),
    );

    // Test actual InfluxDB connection using the service
    final container = ProviderScope.containerOf(context);
    final influxService = container.read(influxServiceProvider);

    influxService.initialize().then((result) {
      if (context.mounted) {
        result.when(
          success: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('InfluxDB connection successful!'),
                backgroundColor: Colors.green,
              ),
            );
            Logger.info('InfluxDB connection test successful', tag: 'Settings');
          },
          failure: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('InfluxDB connection failed: ${error.message}'),
                backgroundColor: Colors.red,
              ),
            );
            Logger.error(
              'InfluxDB connection test failed: ${error.message}',
              tag: 'Settings',
            );
          },
        );
      }
    });
  }
}
