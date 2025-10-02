import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../app.dart';
import '../../core/theme.dart';
import '../providers/config_controller.dart';
import '../providers/connection_recovery_service.dart';
import '../../domain/entities/app_config.dart';

/// Settings page for configuring MQTT, InfluxDB, video, and app preferences.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final configAsync = ref.watch(configControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Explicit Save button to persist current state (even if unchanged) & force reconnect
          IconButton(
            tooltip: 'Save & Reconnect',
            icon: const Icon(Icons.save),
            onPressed: () async {
              final controller = ref.read(configControllerProvider.notifier);
              final current = ref.read(configControllerProvider).value;
              if (current == null) return; // Should not happen when button enabled

              // Persist explicitly (avoids relying solely on debounced per-field saves)
              await controller.updateConfig(current);

              // Invoke recovery service to ensure fresh connections
              final recovery = ref.read(connectionRecoveryServiceProvider);
              await recovery.reconnectAll();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings saved. Reconnecting services...'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ),
          // Reset to defaults button
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                final confirmed = await _showResetDialog(context);
                if (confirmed) {
                  await ref.read(configControllerProvider.notifier).resetToDefaults();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings reset to defaults'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 20),
                    SizedBox(width: 8),
                    Text('Reset to Defaults'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Failed to load settings: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(configControllerProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (config) => _buildSettingsContent(context, ref, isDarkMode, config),
      ),
    );
  }

  Widget _buildSettingsContent(
    BuildContext context,
    WidgetRef ref,
    bool isDarkMode,
    AppConfig config,
  ) {
    return ListView(
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
          ],
        ),

        const SizedBox(height: AppTheme.spaceMd),

        // MQTT Configuration Section
        _buildSectionCard(
          context,
          title: 'MQTT Configuration',
          actions: [
            TextButton.icon(
              onPressed: () => _testMqttConnection(context, ref, config.mqtt),
              icon: const Icon(Icons.wifi_tethering, size: 18),
              label: const Text('Test'),
            ),
          ],
          children: [
            _buildConfigTile(
              context,
              icon: Icons.dns,
              title: 'Broker Host',
              value: config.mqtt.host,
              onTap: () => _showMqttHostDialog(context, ref, config.mqtt.host),
            ),
            _buildConfigTile(
              context,
              icon: Icons.numbers,
              title: 'Port',
              value: config.mqtt.port.toString(),
              onTap: () => _showMqttPortDialog(context, ref, config.mqtt.port),
            ),
            _buildConfigTile(
              context,
              icon: Icons.account_circle,
              title: 'Username',
              value: config.mqtt.username.isEmpty ? 'Not set' : config.mqtt.username,
              onTap: () => _showMqttUsernameDialog(context, ref, config.mqtt.username),
            ),
            _buildConfigTile(
              context,
              icon: Icons.lock,
              title: 'Password',
              value: config.mqtt.password.isEmpty ? 'Not set' : '••••••••',
              onTap: () => _showMqttPasswordDialog(context, ref),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.spaceMd),

        // InfluxDB Configuration Section
        _buildSectionCard(
          context,
          title: 'InfluxDB Configuration',
          actions: [
            TextButton.icon(
              onPressed: () => _testInfluxConnection(context, ref, config.influx),
              icon: const Icon(Icons.storage, size: 18),
              label: const Text('Test'),
            ),
          ],
          children: [
            _buildConfigTile(
              context,
              icon: Icons.link,
              title: 'URL',
              value: config.influx.url,
              onTap: () => _showInfluxUrlDialog(context, ref, config.influx.url),
            ),
            _buildConfigTile(
              context,
              icon: Icons.lock,
              title: 'Token',
              value: config.influx.token.isEmpty ? 'Not set' : '••••••••',
              onTap: () => _showInfluxTokenDialog(context, ref),
            ),
            _buildConfigTile(
              context,
              icon: Icons.business,
              title: 'Organization',
              value: config.influx.organization,
              onTap: () => _showInfluxOrgDialog(context, ref, config.influx.organization),
            ),
            _buildConfigTile(
              context,
              icon: Icons.folder,
              title: 'Bucket',
              value: config.influx.bucket,
              onTap: () => _showInfluxBucketDialog(context, ref, config.influx.bucket),
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
              value: config.video.mjpegUrl,
              onTap: () => _showVideoUrlDialog(context, ref, config.video.mjpegUrl),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.autorenew),
              title: const Text('Auto-reconnect'),
              subtitle: const Text('Automatically reconnect to video stream'),
              value: config.video.autoReconnect,
              onChanged: (value) {
                final newConfig = config.video.copyWith(autoReconnect: value);
                ref.read(configControllerProvider.notifier).updateVideoConfig(newConfig);
              },
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
    List<Widget>? actions,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (actions != null) ...actions,
              ],
            ),
          ),
          const Divider(height: 1),
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
      subtitle: Text(
        value,
        style: TextStyle(
          color: value.startsWith('Not set') 
              ? Theme.of(context).colorScheme.outline 
              : null,
        ),
      ),
      trailing: const Icon(Icons.edit, size: 20),
      onTap: onTap,
    );
  }

  // MQTT Configuration Dialogs
  Future<void> _showMqttHostDialog(BuildContext context, WidgetRef ref, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await _showInputDialog(
      context,
      title: 'MQTT Broker Host',
      controller: controller,
      hintText: 'mqtt.example.com',
    );
    
    if (result != null && result.isNotEmpty) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newMqttConfig = currentConfig.mqtt.copyWith(host: result);
      await configController.updateMqttConfig(newMqttConfig);
    }
  }

  Future<void> _showMqttPortDialog(BuildContext context, WidgetRef ref, int currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());
    final result = await _showInputDialog(
      context,
      title: 'MQTT Port',
      controller: controller,
      hintText: '1883',
      inputType: TextInputType.number,
    );
    
    if (result != null && result.isNotEmpty) {
      final port = int.tryParse(result);
      if (port != null && port > 0 && port <= 65535) {
        final configController = ref.read(configControllerProvider.notifier);
        final currentConfig = ref.read(configControllerProvider).value!;
        final newMqttConfig = currentConfig.mqtt.copyWith(port: port);
        await configController.updateMqttConfig(newMqttConfig);
      } else {
        _showErrorSnackBar(context, 'Invalid port number. Must be between 1 and 65535.');
      }
    }
  }

  Future<void> _showMqttUsernameDialog(BuildContext context, WidgetRef ref, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await _showInputDialog(
      context,
      title: 'MQTT Username',
      controller: controller,
      hintText: 'Enter username (optional)',
    );
    
    if (result != null) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newMqttConfig = currentConfig.mqtt.copyWith(username: result);
      await configController.updateMqttConfig(newMqttConfig);
    }
  }

  Future<void> _showMqttPasswordDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await _showInputDialog(
      context,
      title: 'MQTT Password',
      controller: controller,
      hintText: 'Enter password (optional)',
      obscureText: true,
    );
    
    if (result != null) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newMqttConfig = currentConfig.mqtt.copyWith(password: result);
      await configController.updateMqttConfig(newMqttConfig);
    }
  }

  // InfluxDB Configuration Dialogs
  Future<void> _showInfluxUrlDialog(BuildContext context, WidgetRef ref, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await _showInputDialog(
      context,
      title: 'InfluxDB URL',
      controller: controller,
      hintText: 'http://influxdb:8086',
    );
    
    if (result != null && result.isNotEmpty) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newInfluxConfig = currentConfig.influx.copyWith(url: result);
      await configController.updateInfluxConfig(newInfluxConfig);
    }
  }

  Future<void> _showInfluxTokenDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await _showInputDialog(
      context,
      title: 'InfluxDB Token',
      controller: controller,
      hintText: 'Enter token',
      obscureText: true,
    );
    
    if (result != null) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newInfluxConfig = currentConfig.influx.copyWith(token: result);
      await configController.updateInfluxConfig(newInfluxConfig);
    }
  }

  Future<void> _showInfluxOrgDialog(BuildContext context, WidgetRef ref, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await _showInputDialog(
      context,
      title: 'InfluxDB Organization',
      controller: controller,
      hintText: 'hydroponic-monitor',
    );
    
    if (result != null && result.isNotEmpty) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newInfluxConfig = currentConfig.influx.copyWith(organization: result);
      await configController.updateInfluxConfig(newInfluxConfig);
    }
  }

  Future<void> _showInfluxBucketDialog(BuildContext context, WidgetRef ref, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await _showInputDialog(
      context,
      title: 'InfluxDB Bucket',
      controller: controller,
      hintText: 'sensors',
    );
    
    if (result != null && result.isNotEmpty) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newInfluxConfig = currentConfig.influx.copyWith(bucket: result);
      await configController.updateInfluxConfig(newInfluxConfig);
    }
  }

  // Video Configuration Dialog
  Future<void> _showVideoUrlDialog(BuildContext context, WidgetRef ref, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await _showInputDialog(
      context,
      title: 'MJPEG Stream URL',
      controller: controller,
      hintText: 'http://camera:8080/stream',
    );
    
    if (result != null && result.isNotEmpty) {
      final configController = ref.read(configControllerProvider.notifier);
      final currentConfig = ref.read(configControllerProvider).value!;
      final newVideoConfig = currentConfig.video.copyWith(mjpegUrl: result);
      await configController.updateVideoConfig(newVideoConfig);
    }
  }

  // Generic Input Dialog
  Future<String?> _showInputDialog(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? inputType,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          obscureText: obscureText,
          keyboardType: inputType,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Connection Testing
  Future<void> _testMqttConnection(BuildContext context, WidgetRef ref, MqttConfig config) async {
    final controller = ref.read(configControllerProvider.notifier);
    _showLoadingSnackBar(context, 'Testing MQTT connection...');

    final result = await controller.testMqttConnection(config);
    _hideSnackBar(context);

    result.when(
      success: (_) => _showSuccessSnackBar(context, 'MQTT connection successful!'),
      failure: (error) => _showErrorSnackBar(context, 'MQTT connection failed: ${error.message}'),
    );
  }

  Future<void> _testInfluxConnection(BuildContext context, WidgetRef ref, InfluxConfig config) async {
    final controller = ref.read(configControllerProvider.notifier);
    _showLoadingSnackBar(context, 'Testing InfluxDB connection...');

    final result = await controller.testInfluxConnection(config);
    _hideSnackBar(context);

    result.when(
      success: (_) => _showSuccessSnackBar(context, 'InfluxDB connection successful!'),
      failure: (error) => _showErrorSnackBar(context, 'InfluxDB connection failed: ${error.message}'),
    );
  }

  // Utility methods
  Future<bool> _showResetDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to their default values. This action cannot be undone.\n\nAre you sure?',
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
    return result ?? false;
  }

  void _showLoadingSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        duration: const Duration(minutes: 1), // Long duration for loading
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _hideSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}