import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration utility
class Env {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env file is optional in production
    }
  }

  /// MQTT Configuration
  static String get mqttBrokerUrl => 
      const String.fromEnvironment('MQTT_BROKER_URL', 
      defaultValue: dotenv.env['MQTT_BROKER_URL'] ?? 'mqtt://localhost:1883');
  
  static String get mqttUsername => 
      const String.fromEnvironment('MQTT_USERNAME',
      defaultValue: dotenv.env['MQTT_USERNAME'] ?? '');
  
  static String get mqttPassword => 
      const String.fromEnvironment('MQTT_PASSWORD',
      defaultValue: dotenv.env['MQTT_PASSWORD'] ?? '');

  /// InfluxDB Configuration
  static String get influxUrl => 
      const String.fromEnvironment('INFLUX_URL',
      defaultValue: dotenv.env['INFLUX_URL'] ?? 'http://localhost:8086');
  
  static String get influxToken => 
      const String.fromEnvironment('INFLUX_TOKEN',
      defaultValue: dotenv.env['INFLUX_TOKEN'] ?? '');
  
  static String get influxOrg => 
      const String.fromEnvironment('INFLUX_ORG',
      defaultValue: dotenv.env['INFLUX_ORG'] ?? 'hydroponic');
  
  static String get influxBucket => 
      const String.fromEnvironment('INFLUX_BUCKET',
      defaultValue: dotenv.env['INFLUX_BUCKET'] ?? 'sensors');

  /// Video Configuration
  static String get mjpegUrl => 
      const String.fromEnvironment('MJPEG_URL',
      defaultValue: dotenv.env['MJPEG_URL'] ?? 'http://localhost:8080/video');
}