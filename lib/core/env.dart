import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration helper.
/// Loads configuration from .env file or environment variables.
class Env {
  static String get mqttHost => dotenv.env['MQTT_HOST'] ?? 'localhost';
  static String get mqttUsername => dotenv.env['MQTT_USERNAME'] ?? '';
  static String get mqttPassword => dotenv.env['MQTT_PASSWORD'] ?? '';
  static int get mqttPort => int.tryParse(dotenv.env['MQTT_PORT'] ?? '1883') ?? 1883;

  static String get influxUrl => dotenv.env['INFLUX_URL'] ?? 'http://localhost:8086';
  static String get influxToken => dotenv.env['INFLUX_TOKEN'] ?? '';
  static String get influxOrg => dotenv.env['INFLUX_ORG'] ?? 'hydroponic-monitor';
  static String get influxBucket => dotenv.env['INFLUX_BUCKET'] ?? 'sensors';

  static String get mjpegUrl => dotenv.env['MJPEG_URL'] ?? 'http://localhost:8080/stream';

  /// Initialize environment configuration.
  /// Call this in main() before runApp().
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env file not found or couldn't be loaded - using defaults
      print('Warning: .env file not found, using default values');
    }
  }
}