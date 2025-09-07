import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

/// Environment configuration helper.
/// Loads configuration from .env file or environment variables.
class Env {
  static String get mqttHost => dotenv.env['MQTT_HOST'] ?? 'localhost';
  static String get mqttUsername => dotenv.env['MQTT_USERNAME'] ?? '';
  static String get mqttPassword => dotenv.env['MQTT_PASSWORD'] ?? '';
  static int get mqttPort =>
      int.tryParse(dotenv.env['MQTT_PORT'] ?? '1883') ?? 1883;

  // Prefer explicit OS environment variables (set by CI or test runner)
  // so tests can inject tokens/urls without modifying .env file.
  static String get influxUrl =>
      Platform.environment['INFLUX_URL'] ??
      dotenv.env['INFLUX_URL'] ??
      'http://localhost:8086';
  static String get influxToken =>
      Platform.environment['INFLUX_TOKEN'] ?? dotenv.env['INFLUX_TOKEN'] ?? '';
  static String get influxOrg =>
      Platform.environment['INFLUX_ORG'] ??
      dotenv.env['INFLUX_ORG'] ??
      'hydroponic-monitor';
  static String get influxBucket =>
      Platform.environment['INFLUX_BUCKET'] ??
      dotenv.env['INFLUX_BUCKET'] ??
      'sensors';

  static String get mjpegUrl =>
      dotenv.env['MJPEG_URL'] ?? 'http://localhost:8080/stream';

  /// Initialize environment configuration.
  /// Call this in main() before runApp().
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
      print('✅ Environment configuration loaded from .env file');
    } catch (e) {
      // .env file not found or couldn't be loaded - using defaults
      print('⚠️ Warning: .env file not found, using default values');
      print('   Make sure .env is included in pubspec.yaml assets section');
      print('   Error: $e');
    }
  }

  /// Whether the current runtime is a test environment.
  /// Checks .env TEST_ENV and common environment variables used during tests.
  static bool get isTest {
    final envFlag = dotenv.env['TEST_ENV'];
    if (envFlag != null && envFlag.toLowerCase() == 'true') return true;
    // Some test runners set FLUTTER_TEST or DART_TEST environment variables
    final platformFlag =
        Platform.environment['FLUTTER_TEST'] ??
        Platform.environment['DART_TEST'];
    if (platformFlag != null && platformFlag.toLowerCase() == 'true') {
      return true;
    }
    return false;
  }
}
