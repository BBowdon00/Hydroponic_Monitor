import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';
import 'package:hydroponic_monitor/presentation/providers/config_provider.dart';
import 'package:hydroponic_monitor/core/logger.dart';

class MockConfigRepository extends Mock implements ConfigRepository {}

void main() {
  late MockConfigRepository mockRepository;

  setUpAll(() {
    Logger.init(isTest: true);
    // Register fallback values for mocktail
    registerFallbackValue(_defaultConfig);
  });

  setUp(() {
    mockRepository = MockConfigRepository();

    // Set up default mock behavior
    when(() => mockRepository.loadConfig()).thenAnswer((_) async => _defaultConfig);
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockRepository.clearConfig()).thenAnswer((_) async {});
  });

  group('ConfigNotifier', () {
    test('initializes and loads configuration', () async {
      final container = ProviderContainer(
        overrides: [
          configRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Initially loading
      expect(container.read(configProvider), isA<AsyncLoading<AppConfig>>());

      // Wait for initialization by checking state changes
      await Future.delayed(const Duration(milliseconds: 200));

      final state = container.read(configProvider);

      expect(state, isA<AsyncData<AppConfig>>());
      expect(state.valueOrNull, _defaultConfig);

      verify(() => mockRepository.loadConfig()).called(1);
      
      container.dispose();
    });

    test('updateConfig saves and updates state', () async {
      final container = ProviderContainer(
        overrides: [
          configRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 200));

      final notifier = container.read(configProvider.notifier);

      const newConfig = AppConfig(
        mqtt: MqttConfig(
          host: 'new.mqtt.com',
          port: 1883,
          username: 'newuser',
          password: 'newpass',
        ),
        influx: InfluxConfig(
          url: 'http://new.influx.com:8086',
          token: 'newtoken',
          org: 'neworg',
          bucket: 'newbucket',
        ),
        mjpeg: MjpegConfig(
          url: 'http://new.stream.com:8080/stream',
          autoReconnect: true,
        ),
      );

      await notifier.updateConfig(newConfig);

      final state = container.read(configProvider);

      expect(state.valueOrNull, newConfig);
      verify(() => mockRepository.saveConfig(newConfig)).called(1);
      
      container.dispose();
    });

    test('resetToDefaults clears and reloads config', () async {
      final container = ProviderContainer(
        overrides: [
          configRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 200));

      final notifier = container.read(configProvider.notifier);

      await notifier.resetToDefaults();

      verify(() => mockRepository.clearConfig()).called(1);
      verify(() => mockRepository.loadConfig()).called(2); // Once on init, once on reset
      
      container.dispose();
    });

    test('reload refreshes configuration', () async {
      final container = ProviderContainer(
        overrides: [
          configRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 200));

      final notifier = container.read(configProvider.notifier);

      await notifier.reload();

      verify(() => mockRepository.loadConfig()).called(2); // Once on init, once on reload
      
      container.dispose();
    });
  });
}

const _defaultConfig = AppConfig(
  mqtt: MqttConfig(
    host: 'm0rb1d-server.mynetworksettings.com',
    port: 1883,
    username: '',
    password: '',
  ),
  influx: InfluxConfig(
    url: 'http://m0rb1d-server.mynetworksettings.com:8080/influxdb',
    token: '',
    org: 'hydroponic-monitor',
    bucket: 'sensors',
  ),
  mjpeg: MjpegConfig(
    url: 'http://m0rb1d-server.mynetworksettings.com:8080/stream',
    autoReconnect: true,
  ),
);
