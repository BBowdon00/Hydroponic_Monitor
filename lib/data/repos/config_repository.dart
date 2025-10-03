import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_config.dart';
import '../../core/env.dart';
import '../../core/logger.dart';

/// Repository for persisting and loading application configuration.
/// Uses SharedPreferences for non-secret config and FlutterSecureStorage for secrets.
class ConfigRepository {
  ConfigRepository({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  }) : _secureStorage = secureStorage,
       _prefs = prefs;

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  // Keys for SharedPreferences (non-secret)
  static const _keyMqttHost = 'mqtt_host';
  static const _keyMqttPort = 'mqtt_port';
  static const _keyMqttUsername = 'mqtt_username';
  static const _keyInfluxUrl = 'influx_url';
  static const _keyInfluxOrg = 'influx_org';
  static const _keyInfluxBucket = 'influx_bucket';
  static const _keyMjpegUrl = 'mjpeg_url';
  static const _keyMjpegAutoReconnect = 'mjpeg_auto_reconnect';

  // Keys for FlutterSecureStorage (secrets)
  static const _keyMqttPassword = 'mqtt_password';
  static const _keyInfluxToken = 'influx_token';

  /// Load configuration from storage or return defaults from Env.
  Future<AppConfig> loadConfig() async {
    try {
      Logger.info(
        'Loading configuration from storage',
        tag: 'ConfigRepository',
      );

      // Load MQTT config
      final mqttHost = _prefs.getString(_keyMqttHost) ?? Env.mqttHost;
      final mqttPort = _prefs.getInt(_keyMqttPort) ?? Env.mqttPort;
      final mqttUsername =
          _prefs.getString(_keyMqttUsername) ?? Env.mqttUsername;
      final mqttPassword =
          await _secureStorage.read(key: _keyMqttPassword) ?? Env.mqttPassword;

      // Load InfluxDB config
      final influxUrl = _prefs.getString(_keyInfluxUrl) ?? Env.influxUrl;
      final influxToken =
          await _secureStorage.read(key: _keyInfluxToken) ?? Env.influxToken;
      final influxOrg = _prefs.getString(_keyInfluxOrg) ?? Env.influxOrg;
      final influxBucket =
          _prefs.getString(_keyInfluxBucket) ?? Env.influxBucket;

      // Load MJPEG config
      final mjpegUrl = _prefs.getString(_keyMjpegUrl) ?? Env.mjpegUrl;
      final mjpegAutoReconnect = _prefs.getBool(_keyMjpegAutoReconnect) ?? true;

      final config = AppConfig(
        mqtt: MqttConfig(
          host: mqttHost,
          port: mqttPort,
          username: mqttUsername,
          password: mqttPassword,
        ),
        influx: InfluxConfig(
          url: influxUrl,
          token: influxToken,
          org: influxOrg,
          bucket: influxBucket,
        ),
        mjpeg: MjpegConfig(url: mjpegUrl, autoReconnect: mjpegAutoReconnect),
      );

      Logger.info('Configuration loaded successfully', tag: 'ConfigRepository');
      return config;
    } catch (e) {
      Logger.error(
        'Failed to load configuration: $e',
        tag: 'ConfigRepository',
        error: e,
      );
      // Return defaults from Env on error
      return _defaultConfig();
    }
  }

  /// Save configuration to storage.
  Future<void> saveConfig(AppConfig config) async {
    try {
      Logger.info('Saving configuration to storage', tag: 'ConfigRepository');

      // Save MQTT config
      await _prefs.setString(_keyMqttHost, config.mqtt.host);
      await _prefs.setInt(_keyMqttPort, config.mqtt.port);
      await _prefs.setString(_keyMqttUsername, config.mqtt.username);
      await _secureStorage.write(
        key: _keyMqttPassword,
        value: config.mqtt.password,
      );

      // Save InfluxDB config
      await _prefs.setString(_keyInfluxUrl, config.influx.url);
      await _secureStorage.write(
        key: _keyInfluxToken,
        value: config.influx.token,
      );
      await _prefs.setString(_keyInfluxOrg, config.influx.org);
      await _prefs.setString(_keyInfluxBucket, config.influx.bucket);

      // Save MJPEG config
      await _prefs.setString(_keyMjpegUrl, config.mjpeg.url);
      await _prefs.setBool(_keyMjpegAutoReconnect, config.mjpeg.autoReconnect);

      Logger.info('Configuration saved successfully', tag: 'ConfigRepository');
    } catch (e) {
      Logger.error(
        'Failed to save configuration: $e',
        tag: 'ConfigRepository',
        error: e,
      );
      rethrow;
    }
  }

  /// Clear all configuration from storage.
  Future<void> clearConfig() async {
    try {
      Logger.info(
        'Clearing configuration from storage',
        tag: 'ConfigRepository',
      );

      // Clear SharedPreferences
      await _prefs.remove(_keyMqttHost);
      await _prefs.remove(_keyMqttPort);
      await _prefs.remove(_keyMqttUsername);
      await _prefs.remove(_keyInfluxUrl);
      await _prefs.remove(_keyInfluxOrg);
      await _prefs.remove(_keyInfluxBucket);
      await _prefs.remove(_keyMjpegUrl);
      await _prefs.remove(_keyMjpegAutoReconnect);

      // Clear FlutterSecureStorage
      await _secureStorage.delete(key: _keyMqttPassword);
      await _secureStorage.delete(key: _keyInfluxToken);

      Logger.info(
        'Configuration cleared successfully',
        tag: 'ConfigRepository',
      );
    } catch (e) {
      Logger.error(
        'Failed to clear configuration: $e',
        tag: 'ConfigRepository',
        error: e,
      );
      rethrow;
    }
  }

  /// Get default configuration from Env.
  AppConfig _defaultConfig() {
    return AppConfig(
      mqtt: MqttConfig(
        host: Env.mqttHost,
        port: Env.mqttPort,
        username: Env.mqttUsername,
        password: Env.mqttPassword,
      ),
      influx: InfluxConfig(
        url: Env.influxUrl,
        token: Env.influxToken,
        org: Env.influxOrg,
        bucket: Env.influxBucket,
      ),
      mjpeg: MjpegConfig(url: Env.mjpegUrl, autoReconnect: true),
    );
  }
}
