import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:io' show Platform;

/// Environment configuration helper.
/// Loads configuration from .env file or environment variables.
class Env {
  /// Application environment: 'prod' for production, anything else for test.
  /// Determined from compile-time --dart-define=APP_ENV=prod flag.
  static String get appEnv =>
      const String.fromEnvironment('APP_ENV', defaultValue: 'test');

  /// Whether running in production mode (explicitly set via APP_ENV=prod).
  static bool get isProd => appEnv.toLowerCase() == 'prod';

  static String get mqttHost =>
      dotenv.env['MQTT_HOST'] ?? 'm0rb1d-server.mynetworksettings.com';
  static String get mqttUsername => dotenv.env['MQTT_USERNAME'] ?? '';
  static String get mqttPassword => dotenv.env['MQTT_PASSWORD'] ?? '';
  static int get mqttPort =>
      int.tryParse(dotenv.env['MQTT_PORT'] ?? '1883') ?? 1883;

  /// WebSocket MQTT port (used for browser / web builds). Falls back to 9001 if
  /// not specified. If not running on web, prefer the standard TCP port.
  static int get mqttWsPort =>
    int.tryParse(dotenv.env['MQTT_WS_PORT'] ?? '9001') ?? 9001;

  /// Effective port to use for MQTT connections based on platform.
  /// - Web (kIsWeb): use MQTT_WS_PORT (default 9001)
  /// - Other platforms: use MQTT_PORT (default 1883)
  static int get effectiveMqttPort => kIsWeb ? mqttWsPort : mqttPort;

  // Prefer explicit OS environment variables (set by CI or test runner)
  // so tests can inject tokens/urls without modifying .env file.
  // Note: Platform.environment is not available on web, so use dotenv only
  static String get influxUrl => kIsWeb
      ? dotenv.env['INFLUX_URL'] ??
            // Web default restored to legacy /influxdb prefix for stable CORS behavior.
            'http://m0rb1d-server.mynetworksettings.com:8080/influxdb'
      : Platform.environment['INFLUX_URL'] ??
            dotenv.env['INFLUX_URL'] ??
            _defaultInfluxUrl;

  // Provide a smarter default that respects TEST_ENV so integration tests
  // (which spin up a local InfluxDB on 8086) don't accidentally point at
  // the production reverse proxy if .env.test wasn't loaded yet.
  static String get _defaultInfluxUrl {
    final testFlag = dotenv.env['TEST_ENV']?.toLowerCase();
    if (testFlag == 'true') {
      return 'http://localhost:8086';
    }
    return 'http://m0rb1d-server.mynetworksettings.com:8080';
  }

  static String get influxToken => kIsWeb
      ? dotenv.env['INFLUX_TOKEN'] ?? ''
      : Platform.environment['INFLUX_TOKEN'] ??
            dotenv.env['INFLUX_TOKEN'] ??
            '';

  static String get influxOrg => kIsWeb
      ? dotenv.env['INFLUX_ORG'] ?? 'hydroponic-monitor'
      : Platform.environment['INFLUX_ORG'] ??
            dotenv.env['INFLUX_ORG'] ??
            'hydroponic-monitor';

  /// Bucket selection logic:
  /// - In test contexts (Env.isTest true) we default to 'test-bucket' to match
  ///   integration docker-compose initialization if no explicit env provided.
  /// - Otherwise default to 'grow_data' (primary long-retention production bucket)
  ///   instead of the prior generic 'sensors' fallback to reduce misconfiguration.
  /// An explicit INFLUX_BUCKET (platform env or .env) always overrides.
  static String get influxBucket {
    final provided = kIsWeb
        ? dotenv.env['INFLUX_BUCKET']
        : Platform.environment['INFLUX_BUCKET'] ?? dotenv.env['INFLUX_BUCKET'];
    if (isTest) {
      return provided ?? 'test-bucket';
    }
    return provided ?? 'grow_data';
  }

  static String get mjpegUrl =>
      dotenv.env['MJPEG_URL'] ?? 'http://raspberrypi:8000/stream.mjpg';

  /// Feature flag: enable real MJPEG streaming implementation.
  /// Controlled via REAL_MJPEG environment variable ("true" to enable).
  /// Defaults to false to preserve existing simulated behavior until
  /// the real implementation is fully vetted.
  static bool get enableRealMjpeg {
    String? raw;
    try {
      raw = dotenv.env['REAL_MJPEG'];
    } catch (_) {
      // Dotenv not initialized (tests) -> default false
      raw = null;
    }
    raw = raw ?? (kIsWeb ? null : (Platform.environment['REAL_MJPEG']));
    if (raw == null) return false;
    switch (raw.toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      default:
        return false;
    }
  }

  /// Initialize environment configuration.
  /// Call this in main() before runApp().
  /// Loads .env.test by default, .env when APP_ENV=prod is set.
  static Future<void> init() async {
    try {
      final envFile = isProd ? '.env' : '.env.test';
      try {
        await dotenv.load(fileName: envFile);
        print('✅ Environment configuration loaded from $envFile file');
      } catch (_) {
        // If preferred file missing, try fallback
        final fallback = isProd ? '.env.test' : '.env';
        try {
          await dotenv.load(fileName: fallback);
          print(
            '⚠️  Warning: $envFile not found, loaded $fallback instead',
          );
        } catch (e) {
          print('⚠️ Warning: No .env file found, using default values');
          print('   Make sure .env is included in pubspec.yaml assets section');
          print('   Error: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error loading environment: $e');
    }
  }

  /// Debug-only assertion helper to log missing required configuration keys.
  /// Non-fatal - logs warnings but allows app to continue with defaults.
  static void assertConfigured() {
    if (!kDebugMode) return;

    final warnings = <String>[];

    // Check critical keys
    if (mqttHost.isEmpty) warnings.add('MQTT_HOST not configured');
    if (influxUrl.isEmpty) warnings.add('INFLUX_URL not configured');
    if (influxToken.isEmpty) warnings.add('INFLUX_TOKEN not configured');
    if (influxOrg.isEmpty) warnings.add('INFLUX_ORG not configured');
    if (influxBucket.isEmpty) warnings.add('INFLUX_BUCKET not configured');

    if (warnings.isNotEmpty) {
      print('⚠️  Configuration warnings (using defaults):');
      for (final warning in warnings) {
        print('   - $warning');
      }
    } else {
      print('✅ All required environment keys configured');
    }
  }

  /// Whether the current runtime is a test environment.
  /// Checks .env TEST_ENV flag and APP_ENV compile-time setting.
  static bool get isTest {
    // If APP_ENV is explicitly prod, we're not in test
    if (isProd) return false;

    final envFlag = dotenv.env['TEST_ENV'];
    if (envFlag != null && envFlag.toLowerCase() == 'true') return true;

    // Some test runners set FLUTTER_TEST or DART_TEST environment variables
    // Note: Platform.environment is not available on web, so skip this check on web
    if (!kIsWeb) {
      final platformFlag =
          Platform.environment['FLUTTER_TEST'] ??
          Platform.environment['DART_TEST'];
      if (platformFlag != null && platformFlag.toLowerCase() == 'true') {
        return true;
      }
    }
    return false;
  }
}
