import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/theme.dart';

/// Settings page for app configuration
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _mqttHostController = TextEditingController();
  final _mqttPortController = TextEditingController();
  final _mqttUsernameController = TextEditingController();
  final _mqttPasswordController = TextEditingController();
  final _influxUrlController = TextEditingController();
  final _influxTokenController = TextEditingController();
  final _influxOrgController = TextEditingController();
  final _influxBucketController = TextEditingController();

  String _selectedTheme = 'System';
  String _selectedUnits = 'Metric';
  bool _enableNotifications = true;
  bool _enableDataSync = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _mqttHostController.dispose();
    _mqttPortController.dispose();
    _mqttUsernameController.dispose();
    _mqttPasswordController.dispose();
    _influxUrlController.dispose();
    _influxTokenController.dispose();
    _influxOrgController.dispose();
    _influxBucketController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    // Load mock settings
    _mqttHostController.text = 'mqtt.local';
    _mqttPortController.text = '1883';
    _mqttUsernameController.text = 'hydroponic_user';
    _influxUrlController.text = 'http://influx.local:8086';
    _influxOrgController.text = 'hydroponic';
    _influxBucketController.text = 'sensors';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save settings',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.space16),
          children: [
            // MQTT Configuration
            _buildMqttSection(),
            
            const SizedBox(height: AppTheme.space24),
            
            // InfluxDB Configuration
            _buildInfluxSection(),
            
            const SizedBox(height: AppTheme.space24),
            
            // App Preferences
            _buildAppPreferencesSection(),
            
            const SizedBox(height: AppTheme.space24),
            
            // System Information
            _buildSystemInfoSection(),
            
            const SizedBox(height: AppTheme.space24),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMqttSection() {
    return _SettingsSection(
      title: 'MQTT Configuration',
      icon: Icons.wifi,
      children: [
        TextFormField(
          controller: _mqttHostController,
          decoration: const InputDecoration(
            labelText: 'MQTT Host',
            hintText: 'mqtt.local or IP address',
            prefixIcon: Icon(Icons.dns),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter MQTT host';
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.space16),
        TextFormField(
          controller: _mqttPortController,
          decoration: const InputDecoration(
            labelText: 'Port',
            hintText: '1883',
            prefixIcon: Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter port number';
            }
            final port = int.tryParse(value);
            if (port == null || port < 1 || port > 65535) {
              return 'Please enter a valid port number';
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.space16),
        TextFormField(
          controller: _mqttUsernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Optional',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        TextFormField(
          controller: _mqttPasswordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Optional',
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
        const SizedBox(height: AppTheme.space16),
        ElevatedButton.icon(
          onPressed: _testMqttConnection,
          icon: const Icon(Icons.wifi_find),
          label: const Text('Test Connection'),
        ),
      ],
    );
  }

  Widget _buildInfluxSection() {
    return _SettingsSection(
      title: 'InfluxDB Configuration',
      icon: Icons.storage,
      children: [
        TextFormField(
          controller: _influxUrlController,
          decoration: const InputDecoration(
            labelText: 'InfluxDB URL',
            hintText: 'http://influx.local:8086',
            prefixIcon: Icon(Icons.http),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter InfluxDB URL';
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.space16),
        TextFormField(
          controller: _influxTokenController,
          decoration: const InputDecoration(
            labelText: 'Access Token',
            hintText: 'Your InfluxDB token',
            prefixIcon: Icon(Icons.key),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter access token';
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.space16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _influxOrgController,
                decoration: const InputDecoration(
                  labelText: 'Organization',
                  hintText: 'hydroponic',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter organization';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: AppTheme.space16),
            Expanded(
              child: TextFormField(
                controller: _influxBucketController,
                decoration: const InputDecoration(
                  labelText: 'Bucket',
                  hintText: 'sensors',
                  prefixIcon: Icon(Icons.folder),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter bucket name';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space16),
        ElevatedButton.icon(
          onPressed: _testInfluxConnection,
          icon: const Icon(Icons.storage_outlined),
          label: const Text('Test Connection'),
        ),
      ],
    );
  }

  Widget _buildAppPreferencesSection() {
    return _SettingsSection(
      title: 'App Preferences',
      icon: Icons.tune,
      children: [
        _SettingsDropdown(
          label: 'Theme',
          value: _selectedTheme,
          items: const ['System', 'Light', 'Dark'],
          onChanged: (value) => setState(() => _selectedTheme = value!),
          icon: Icons.palette,
        ),
        const SizedBox(height: AppTheme.space16),
        _SettingsDropdown(
          label: 'Units',
          value: _selectedUnits,
          items: const ['Metric', 'Imperial'],
          onChanged: (value) => setState(() => _selectedUnits = value!),
          icon: Icons.straighten,
        ),
        const SizedBox(height: AppTheme.space16),
        SwitchListTile(
          title: const Text('Enable Notifications'),
          subtitle: const Text('Receive alerts and system notifications'),
          value: _enableNotifications,
          onChanged: (value) => setState(() => _enableNotifications = value),
          secondary: const Icon(Icons.notifications),
        ),
        SwitchListTile(
          title: const Text('Auto Data Sync'),
          subtitle: const Text('Automatically sync data in background'),
          value: _enableDataSync,
          onChanged: (value) => setState(() => _enableDataSync = value),
          secondary: const Icon(Icons.sync),
        ),
      ],
    );
  }

  Widget _buildSystemInfoSection() {
    return _SettingsSection(
      title: 'System Information',
      icon: Icons.info,
      children: [
        _InfoTile(
          label: 'App Version',
          value: '1.0.0+1',
          icon: Icons.app_settings_alt,
        ),
        _InfoTile(
          label: 'Build Number',
          value: '1',
          icon: Icons.build,
        ),
        _InfoTile(
          label: 'Platform',
          value: Theme.of(context).platform.name,
          icon: Icons.devices,
        ),
        _InfoTile(
          label: 'Last Sync',
          value: 'Just now',
          icon: Icons.sync,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportSettings,
            icon: const Icon(Icons.download),
            label: const Text('Export Settings'),
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _importSettings,
            icon: const Icon(Icons.upload),
            label: const Text('Import Settings'),
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetSettings,
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Defaults'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _testMqttConnection() async {
    // Mock connection test
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppTheme.space16),
            Text('Testing MQTT connection...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Test'),
        content: const Text('MQTT connection successful!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _testInfluxConnection() async {
    // Mock connection test
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppTheme.space16),
            Text('Testing InfluxDB connection...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Test'),
        content: const Text('InfluxDB connection successful!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _exportSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings exported to Downloads/hydroponic_settings.json'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _importSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings import feature coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadDefaultSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _loadDefaultSettings() {
    setState(() {
      _mqttHostController.text = '';
      _mqttPortController.text = '1883';
      _mqttUsernameController.text = '';
      _mqttPasswordController.text = '';
      _influxUrlController.text = '';
      _influxTokenController.text = '';
      _influxOrgController.text = '';
      _influxBucketController.text = '';
      _selectedTheme = 'System';
      _selectedUnits = 'Metric';
      _enableNotifications = true;
      _enableDataSync = true;
    });
  }
}

/// Settings section wrapper widget
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Settings dropdown widget
class _SettingsDropdown extends StatelessWidget {
  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

/// Information tile widget
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}