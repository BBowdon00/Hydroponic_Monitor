import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/presentation/providers/config_provider.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';
import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/core/logger.dart';

class MockConfigRepository extends Mock implements ConfigRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Logger.init(isTest: true);

  setUpAll(() async {
    // Ensure dotenv is initialized so Env.* getters used inside providers
    // (which touch dotenv.env) don't throw a NotInitializedError in tests.
    // flutter_dotenv 6.x does not expose a fileContents parameter; load the default .env.
    // We only need the loader to run so that any Env.* lookups do not throw.
    try {
      await dotenv.load(fileName: '.env.test');
    } catch (_) {
      // Fallback to primary .env if test env file not present.
      await dotenv.load(fileName: '.env');
    }
    registerFallbackValue(
      const AppConfig(
        mqtt: MqttConfig(host: 'f', port: 1883, username: '', password: ''),
        influx: InfluxConfig(url: 'http://f', token: '', org: 'o', bucket: 'b'),
        hls: HlsConfig(url: 'http://f/stream', autoReconnect: true),
      ),
    );
  });

  group('Dynamic service providers', () {
    late MockConfigRepository mockRepo;
    late AppConfig initialConfig;
    late AppConfig updatedConfig;

    Future<void> _waitForConfig(ProviderContainer container) async {
      final start = DateTime.now();
      while (true) {
        final value = container.read(configProvider);
        if (value is AsyncData<AppConfig>) break;
        if (DateTime.now().difference(start) > const Duration(seconds: 2)) {
          fail('Timed out waiting for configProvider to initialize');
        }
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    setUp(() {
      mockRepo = MockConfigRepository();
      initialConfig = const AppConfig(
        mqtt: MqttConfig(
          host: 'host1',
          port: 1883,
          username: 'u1',
          password: 'p1',
        ),
        influx: InfluxConfig(
          url: 'http://influx1:8086',
          token: 't1',
          org: 'org1',
          bucket: 'b1',
        ),
        hls: HlsConfig(url: 'http://cam1/stream', autoReconnect: true),
      );
      updatedConfig = const AppConfig(
        mqtt: MqttConfig(
          host: 'host2',
          port: 1884,
          username: 'u2',
          password: 'p2',
        ),
        influx: InfluxConfig(
          url: 'http://influx2:8086',
          token: 't2',
          org: 'org2',
          bucket: 'b2',
        ),
        hls: HlsConfig(url: 'http://cam2/stream', autoReconnect: false),
      );
    });

    test('mqttServiceProvider rebuilds with new config values', () async {
      // Stub BEFORE container creation so provider init sees desired config
      when(() => mockRepo.loadConfig()).thenAnswer((_) async => initialConfig);
      when(() => mockRepo.saveConfig(any())).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [configRepositoryProvider.overrideWithValue(mockRepo)],
      );

      await _waitForConfig(container);

      final mqtt1 = container.read(mqttServiceProvider);
      expect(mqtt1.host, initialConfig.mqtt.host);
      expect(mqtt1.port, initialConfig.mqtt.port);

      // Simulate update
      when(() => mockRepo.saveConfig(any())).thenAnswer((_) async {
        // no-op
      });

      await container.read(configProvider.notifier).updateConfig(updatedConfig);

      // Force provider refresh by reading again (it should have rebuilt due to watch)
      final mqtt2 = container.read(mqttServiceProvider);
      expect(mqtt2.host, updatedConfig.mqtt.host);
      expect(mqtt2.port, updatedConfig.mqtt.port);

      container.dispose();
    });

    test('influxServiceProvider rebuilds with new config values', () async {
      when(() => mockRepo.loadConfig()).thenAnswer((_) async => initialConfig);
      when(() => mockRepo.saveConfig(any())).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [configRepositoryProvider.overrideWithValue(mockRepo)],
      );
      await _waitForConfig(container);

      final influx1 = container.read(influxServiceProvider);
      expect(influx1.url, initialConfig.influx.url);
      expect(influx1.bucket, initialConfig.influx.bucket);

      await container.read(configProvider.notifier).updateConfig(updatedConfig);
      final influx2 = container.read(influxServiceProvider);
      expect(influx2.url, updatedConfig.influx.url);
      expect(influx2.bucket, updatedConfig.influx.bucket);

      container.dispose();
    });
  });
}
