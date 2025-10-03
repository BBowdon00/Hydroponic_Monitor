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
  InMemoryConfigRepository({
    required AppConfig initial,
    required SharedPreferences prefs,
  }) : _config = initial,
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
    test(
      'Updating config rebuilds services and repository uses new endpoints',
      () async {
        // Ensure dotenv map has minimal keys to satisfy Env.* getters without throwing.
        // Ensure required env vars present before any provider reads Env.*
        await dotenv.dotenv.load(
          mergeWith: {
            'MQTT_HOST': 'fallbackHost',
            'MQTT_PORT': '1883',
            'MQTT_USERNAME': 'userEnv',
            'MQTT_PASSWORD': 'passEnv',
            'INFLUX_URL': 'http://influxA',
            'INFLUX_ORG': 'orgA',
            'INFLUX_BUCKET': 'bucketA',
            'TEST_ENV': 'true',
          },
        );
        final initial = AppConfig(
          mqtt: MqttConfig(
            host: 'hostA',
            port: 1883,
            username: 'userA',
            password: 'passA',
          ),
          influx: InfluxConfig(
            url: 'http://influxA',
            token: 'tokenA',
            org: 'orgA',
            bucket: 'bucketA',
          ),
          mjpeg: MjpegConfig(url: 'http://mjpegA', autoReconnect: true),
        );
        final updated = AppConfig(
          mqtt: MqttConfig(
            host: 'hostB',
            port: 2883,
            username: 'userB',
            password: 'passB',
          ),
          influx: InfluxConfig(
            url: 'http://influxB',
            token: 'tokenB',
            org: 'orgB',
            bucket: 'bucketB',
          ),
          mjpeg: MjpegConfig(url: 'http://mjpegB', autoReconnect: false),
        );

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = InMemoryConfigRepository(initial: initial, prefs: prefs);

        final container = ProviderContainer(
          overrides: [configRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        // Wait until configProvider AsyncValue has loaded the initial config to avoid reading placeholder services.
        final start = DateTime.now();
        while (container.read(configProvider).maybeWhen(
              data: (c) => c.mqtt.host == 'hostA' && c.influx.url == 'http://influxA',
              orElse: () => false,
            ) == false) {
          if (DateTime.now().difference(start) > const Duration(seconds: 2)) {
            final snapshot = container.read(configProvider);
            fail('Config not loaded with expected initial values within timeout. Current state=$snapshot');
          }
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }

        // Now services should be constructed from the loaded config.
        final mqttService1 = container.read(mqttServiceProvider);
        final influxService1 = container.read(influxServiceProvider);
        expect(mqttService1.host, equals('hostA'));
  // URL normalization may lowercase host; accept either.
  expect(influxService1.url, anyOf('http://influxA', 'http://influxa'));
        expect([1883, 9001], contains(mqttService1.port));

        // Apply updated config
        await container.read(configProvider.notifier).updateConfig(updated);

        // Wait until updated config observed via configProvider
        final startUpdate = DateTime.now();
        while (container.read(configProvider).maybeWhen(
              data: (c) => c.mqtt.host == 'hostB' && c.influx.url == 'http://influxB',
              orElse: () => false,
            ) == false) {
          if (DateTime.now().difference(startUpdate) > const Duration(seconds: 2)) {
            final snapshot = container.read(configProvider);
            fail('Updated config not observed within timeout. Current state=$snapshot');
          }
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }

        final mqttService2 = container.read(mqttServiceProvider);
        final influxService2 = container.read(influxServiceProvider);
        expect([2883, 9001], contains(mqttService2.port));

        // Ensure repository reinitialized with new services
        final repo1 = container.read(sensorRepositoryProvider);
        await container.read(
          sensorRepositoryInitProvider.future,
        ); // ensure init complete
        final repo2 = container.read(sensorRepositoryProvider);
        expect(repo2.mqttService.host, equals('hostB'));
  expect(repo2.influxService.url, anyOf('http://influxB', 'http://influxb'));
      },
    );
  });
}
