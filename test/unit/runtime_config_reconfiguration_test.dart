import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/presentation/providers/config_provider.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

/// In-memory configuration repository that bypasses real persistence.
class InMemoryConfigRepository extends ConfigRepository {
  InMemoryConfigRepository({required AppConfig initial, required SharedPreferences prefs})
      : _config = initial,
        super(
          // Provide a benign secure storage instance; methods won't be used because we override.
          secureStorage: const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: false),
          ),
          prefs: prefs,
        );

  AppConfig _config;

  @override
  Future<AppConfig> loadConfig() async => _config;

  @override
  Future<void> saveConfig(AppConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearConfig() async {
    // Reset to defaults would normally clear storage; keep as no-op for test.
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Runtime config reconfiguration', () {
    test('Updating config rebuilds services and repository uses new endpoints', () async {
      // Ensure dotenv map has minimal keys to satisfy Env.* getters without throwing.
      // Ensure required env vars present before any provider reads Env.*
      await dotenv.dotenv.load(mergeWith: {
        'MQTT_HOST': 'fallbackHost',
        'MQTT_PORT': '1883',
        'MQTT_USERNAME': 'userEnv',
        'MQTT_PASSWORD': 'passEnv',
        'INFLUX_URL': 'http://influxA',
        'INFLUX_ORG': 'orgA',
        'INFLUX_BUCKET': 'bucketA',
        'TEST_ENV': 'true',
      });
      final initial = AppConfig(
        mqtt: MqttConfig(host: 'hostA', port: 1883, username: 'userA', password: 'passA'),
        influx: InfluxConfig(url: 'http://influxA', token: 'tokenA', org: 'orgA', bucket: 'bucketA'),
        mjpeg: MjpegConfig(url: 'http://mjpegA', autoReconnect: true),
      );
      final updated = AppConfig(
        mqtt: MqttConfig(host: 'hostB', port: 2883, username: 'userB', password: 'passB'),
        influx: InfluxConfig(url: 'http://influxB', token: 'tokenB', org: 'orgB', bucket: 'bucketB'),
        mjpeg: MjpegConfig(url: 'http://mjpegB', autoReconnect: false),
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = InMemoryConfigRepository(initial: initial, prefs: prefs);

      final container = ProviderContainer(overrides: [
        configRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Wait for initial config load
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // The first synchronous read may return a placeholder (fallbackHost) if config not yet resolved.
      // Poll until provider reflects the initial config host or timeout.
      MqttService mqttService1;
      InfluxDbService influxService1;
      final start = DateTime.now();
      while (true) {
        mqttService1 = container.read(mqttServiceProvider);
        influxService1 = container.read(influxServiceProvider);
        if (mqttService1.host == 'hostA' && influxService1.url == 'http://influxA') {
          break;
        }
        if (DateTime.now().difference(start) > const Duration(seconds: 2)) {
          fail('Config providers did not reflect initial AppConfig within timeout. Got host=${mqttService1.host} influx=${influxService1.url}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect([1883, 9001], contains(mqttService1.port));

      // Apply updated config
  await container.read(configProvider.notifier).updateConfig(updated);

      // Allow provider rebuild microtasks to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Wait until updated config applied
      MqttService mqttService2;
      InfluxDbService influxService2;
      final startUpdate = DateTime.now();
      while (true) {
        mqttService2 = container.read(mqttServiceProvider);
        influxService2 = container.read(influxServiceProvider);
        if (mqttService2.host == 'hostB' && influxService2.url == 'http://influxB') {
          break;
        }
        if (DateTime.now().difference(startUpdate) > const Duration(seconds: 2)) {
          fail('Updated config not observed within timeout. Got host=${mqttService2.host} influx=${influxService2.url}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect([2883, 9001], contains(mqttService2.port));

      // Ensure repository reinitialized with new services
      final repo1 = container.read(sensorRepositoryProvider);
      await container.read(sensorRepositoryInitProvider.future); // ensure init complete
      final repo2 = container.read(sensorRepositoryProvider);
      expect(repo2.mqttService.host, equals('hostB'));
      expect(repo2.influxService.url, equals('http://influxB'));
    });
  });
}
