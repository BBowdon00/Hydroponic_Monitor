import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/app_config.dart';

/// Interface for configuration storage operations
abstract class ConfigStorageInterface {
  Future<void> saveNonSecretConfig(Map<String, dynamic> config);
  Future<Map<String, dynamic>?> loadNonSecretConfig();
  Future<void> saveSecret(String key, String value);
  Future<String?> loadSecret(String key);
  Future<void> deleteSecret(String key);
  Future<void> clearAllConfig();
}

/// Platform-specific configuration storage implementation
class ConfigStorage implements ConfigStorageInterface {
  static const String _configKey = 'hydroponic_monitor_config';
  static const String _versionKey = 'config_version';
  static const int _currentVersion = 1;

  // Secret keys for secure storage
  static const String _mqttPasswordKey = 'mqtt_password';
  static const String _influxTokenKey = 'influx_token';

  final FlutterSecureStorage _secureStorage;

  ConfigStorage({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> saveNonSecretConfig(Map<String, dynamic> config) async {
    try {
      final prefs = await _preferences;
      final jsonString = json.encode(config);
      await prefs.setString(_configKey, jsonString);
      await prefs.setInt(_versionKey, _currentVersion);
      Logger.info('Saved non-secret config', tag: 'ConfigStorage');
    } catch (e) {
      Logger.error('Failed to save non-secret config: $e',
          tag: 'ConfigStorage', error: e);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> loadNonSecretConfig() async {
    try {
      final prefs = await _preferences;
      final version = prefs.getInt(_versionKey) ?? 0;
      
      if (version != _currentVersion) {
        Logger.info('Config version mismatch ($version != $_currentVersion), clearing config',
            tag: 'ConfigStorage');
        await clearAllConfig();
        return null;
      }

      final jsonString = prefs.getString(_configKey);
      if (jsonString == null) return null;

      final config = json.decode(jsonString) as Map<String, dynamic>;
      Logger.info('Loaded non-secret config', tag: 'ConfigStorage');
      return config;
    } catch (e) {
      Logger.error('Failed to load non-secret config: $e',
          tag: 'ConfigStorage', error: e);
      return null;
    }
  }

  @override
  Future<void> saveSecret(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      Logger.info('Saved secret for key: $key', tag: 'ConfigStorage');
    } catch (e) {
      Logger.error('Failed to save secret for key $key: $e',
          tag: 'ConfigStorage', error: e);
      rethrow;
    }
  }

  @override
  Future<String?> loadSecret(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value != null) {
        Logger.debug('Loaded secret for key: $key', tag: 'ConfigStorage');
      }
      return value;
    } catch (e) {
      Logger.error('Failed to load secret for key $key: $e',
          tag: 'ConfigStorage', error: e);
      return null;
    }
  }

  @override
  Future<void> deleteSecret(String key) async {
    try {
      await _secureStorage.delete(key: key);
      Logger.info('Deleted secret for key: $key', tag: 'ConfigStorage');
    } catch (e) {
      Logger.error('Failed to delete secret for key $key: $e',
          tag: 'ConfigStorage', error: e);
      rethrow;
    }
  }

  @override
  Future<void> clearAllConfig() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(_configKey);
      await prefs.remove(_versionKey);
      await _secureStorage.delete(key: _mqttPasswordKey);
      await _secureStorage.delete(key: _influxTokenKey);
      Logger.info('Cleared all config', tag: 'ConfigStorage');
    } catch (e) {
      Logger.error('Failed to clear all config: $e',
          tag: 'ConfigStorage', error: e);
      rethrow;
    }
  }
}

/// Repository for managing application configuration
class ConfigRepository {
  final ConfigStorageInterface _storage;
  final StreamController<AppConfig> _configController;
  AppConfig? _currentConfig;

  ConfigRepository({
    ConfigStorageInterface? storage,
  })  : _storage = storage ?? ConfigStorage(),
        _configController = StreamController<AppConfig>.broadcast();

  /// Stream of configuration changes
  Stream<AppConfig> get configStream => _configController.stream;

  /// Get current configuration, loading from storage if needed
  Future<AppConfig> getConfig() async {
    if (_currentConfig == null) {
      _currentConfig = await _loadConfig();
    }
    return _currentConfig!;
  }

  /// Update configuration and persist to storage
  Future<void> updateConfig(AppConfig config) async {
    await _saveConfig(config);
    _currentConfig = config;
    _configController.add(config);
    Logger.info('Configuration updated and broadcast', tag: 'ConfigRepository');
  }

  /// Reset configuration to environment defaults
  Future<void> resetToDefaults() async {
    final defaultConfig = AppConfig.fromEnv();
    await _storage.clearAllConfig();
    _currentConfig = defaultConfig;
    _configController.add(defaultConfig);
    Logger.info('Configuration reset to defaults', tag: 'ConfigRepository');
  }

  /// Dispose resources
  void dispose() {
    _configController.close();
  }

  /// Load configuration from storage or return defaults
  Future<AppConfig> _loadConfig() async {
    try {
      Logger.info('Loading configuration from storage', tag: 'ConfigRepository');
      
      // Load non-secret configuration
      final nonSecretConfig = await _storage.loadNonSecretConfig();
      
      // Load secrets
      final mqttPassword = await _storage.loadSecret(ConfigStorage._mqttPasswordKey);
      final influxToken = await _storage.loadSecret(ConfigStorage._influxTokenKey);

      // If no stored config, return defaults
      if (nonSecretConfig == null) {
        Logger.info('No stored config found, using environment defaults', 
            tag: 'ConfigRepository');
        final defaultConfig = AppConfig.fromEnv();
        _configController.add(defaultConfig);
        return defaultConfig;
      }

      // Build config from stored values with fallbacks to env defaults
      final env = AppConfig.fromEnv();
      final config = AppConfig(
        mqtt: MqttConfig(
          host: nonSecretConfig['mqtt_host'] as String? ?? env.mqtt.host,
          port: nonSecretConfig['mqtt_port'] as int? ?? env.mqtt.port,
          username: nonSecretConfig['mqtt_username'] as String? ?? env.mqtt.username,
          password: mqttPassword ?? env.mqtt.password,
        ),
        influx: InfluxConfig(
          url: nonSecretConfig['influx_url'] as String? ?? env.influx.url,
          token: influxToken ?? env.influx.token,
          organization: nonSecretConfig['influx_organization'] as String? ?? env.influx.organization,
          bucket: nonSecretConfig['influx_bucket'] as String? ?? env.influx.bucket,
        ),
        video: VideoConfig(
          mjpegUrl: nonSecretConfig['video_mjpeg_url'] as String? ?? env.video.mjpegUrl,
          autoReconnect: nonSecretConfig['video_auto_reconnect'] as bool? ?? env.video.autoReconnect,
        ),
      );

      Logger.info('Configuration loaded from storage', tag: 'ConfigRepository');
      _configController.add(config);
      return config;
    } catch (e) {
      Logger.error('Failed to load configuration, using defaults: $e',
          tag: 'ConfigRepository', error: e);
      final defaultConfig = AppConfig.fromEnv();
      _configController.add(defaultConfig);
      return defaultConfig;
    }
  }

  /// Save configuration to storage
  Future<void> _saveConfig(AppConfig config) async {
    try {
      Logger.info('Saving configuration to storage', tag: 'ConfigRepository');

      // Prepare non-secret configuration
      final nonSecretConfig = <String, dynamic>{
        'mqtt_host': config.mqtt.host,
        'mqtt_port': config.mqtt.port,
        'mqtt_username': config.mqtt.username,
        'influx_url': config.influx.url,
        'influx_organization': config.influx.organization,
        'influx_bucket': config.influx.bucket,
        'video_mjpeg_url': config.video.mjpegUrl,
        'video_auto_reconnect': config.video.autoReconnect,
      };

      // Save non-secret config
      await _storage.saveNonSecretConfig(nonSecretConfig);

      // Save secrets
      if (config.mqtt.password.isNotEmpty) {
        await _storage.saveSecret(ConfigStorage._mqttPasswordKey, config.mqtt.password);
      } else {
        await _storage.deleteSecret(ConfigStorage._mqttPasswordKey);
      }

      if (config.influx.token.isNotEmpty) {
        await _storage.saveSecret(ConfigStorage._influxTokenKey, config.influx.token);
      } else {
        await _storage.deleteSecret(ConfigStorage._influxTokenKey);
      }

      Logger.info('Configuration saved successfully', tag: 'ConfigRepository');
    } catch (e) {
      Logger.error('Failed to save configuration: $e',
          tag: 'ConfigRepository', error: e);
      rethrow;
    }
  }
}