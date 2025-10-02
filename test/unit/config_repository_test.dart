import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/domain/entities/app_config.dart';
import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/core/env.dart';

// Mock storage for testing
class MockConfigStorage extends Mock implements ConfigStorageInterface {}

void main() {
  setUpAll(() async {
    // Initialize environment for tests
    await Env.init();
  });
  group('ConfigRepository', () {
    late ConfigRepository repository;
    late MockConfigStorage mockStorage;

    setUp(() {
      mockStorage = MockConfigStorage();
      repository = ConfigRepository(storage: mockStorage);
    });

    tearDown(() {
      repository.dispose();
    });

    group('getConfig', () {
      test('returns environment defaults when no stored config', () async {
        // Arrange
        when(() => mockStorage.loadNonSecretConfig()).thenAnswer((_) async => null);
        when(() => mockStorage.loadSecret(any())).thenAnswer((_) async => null);

        // Act
        final config = await repository.getConfig();

        // Assert
        expect(config, equals(AppConfig.fromEnv()));
        verify(() => mockStorage.loadNonSecretConfig()).called(1);
        verify(() => mockStorage.loadSecret('mqtt_password')).called(1);
        verify(() => mockStorage.loadSecret('influx_token')).called(1);
      });

      test('returns stored config when available', () async {
        // Arrange
        const storedConfig = {
          'mqtt_host': 'test-mqtt-host',
          'mqtt_port': 1884,
          'mqtt_username': 'test-user',
          'influx_url': 'http://test-influx:8087',
          'influx_organization': 'test-org',
          'influx_bucket': 'test-bucket',
          'video_mjpeg_url': 'http://test-video:8081/stream',
          'video_auto_reconnect': false,
        };
        const mqttPassword = 'test-password';
        const influxToken = 'test-token';

        when(() => mockStorage.loadNonSecretConfig())
            .thenAnswer((_) async => storedConfig);
        when(() => mockStorage.loadSecret('mqtt_password'))
            .thenAnswer((_) async => mqttPassword);
        when(() => mockStorage.loadSecret('influx_token'))
            .thenAnswer((_) async => influxToken);

        // Act
        final config = await repository.getConfig();

        // Assert
        expect(config.mqtt.host, equals('test-mqtt-host'));
        expect(config.mqtt.port, equals(1884));
        expect(config.mqtt.username, equals('test-user'));
        expect(config.mqtt.password, equals('test-password'));
        expect(config.influx.url, equals('http://test-influx:8087'));
        expect(config.influx.token, equals('test-token'));
        expect(config.influx.organization, equals('test-org'));
        expect(config.influx.bucket, equals('test-bucket'));
        expect(config.video.mjpegUrl, equals('http://test-video:8081/stream'));
        expect(config.video.autoReconnect, equals(false));
      });

      test('falls back to environment defaults for missing values', () async {
        // Arrange
        const partialConfig = {
          'mqtt_host': 'test-mqtt-host',
          // Missing other values
        };
        when(() => mockStorage.loadNonSecretConfig())
            .thenAnswer((_) async => partialConfig);
        when(() => mockStorage.loadSecret(any())).thenAnswer((_) async => null);

        // Act
        final config = await repository.getConfig();
        final envDefaults = AppConfig.fromEnv();

        // Assert
        expect(config.mqtt.host, equals('test-mqtt-host')); // From stored
        expect(config.mqtt.port, equals(envDefaults.mqtt.port)); // From env
        expect(config.mqtt.username, equals(envDefaults.mqtt.username)); // From env
        expect(config.influx.url, equals(envDefaults.influx.url)); // From env
      });

      test('handles storage errors gracefully', () async {
        // Arrange
        when(() => mockStorage.loadNonSecretConfig())
            .thenThrow(Exception('Storage error'));

        // Act
        final config = await repository.getConfig();

        // Assert - Should return env defaults
        expect(config, equals(AppConfig.fromEnv()));
      });
    });

    group('updateConfig', () {
      test('saves config and broadcasts changes', () async {
        // Arrange
        final testConfig = AppConfig(
          mqtt: const MqttConfig(
            host: 'new-host',
            port: 1885,
            username: 'new-user',
            password: 'new-password',
          ),
          influx: const InfluxConfig(
            url: 'http://new-influx:8088',
            token: 'new-token',
            organization: 'new-org',
            bucket: 'new-bucket',
          ),
          video: const VideoConfig(
            mjpegUrl: 'http://new-video:8082/stream',
            autoReconnect: true,
          ),
        );

        when(() => mockStorage.saveNonSecretConfig(any())).thenAnswer((_) async {});
        when(() => mockStorage.saveSecret(any(), any())).thenAnswer((_) async {});

        // Act
        await repository.updateConfig(testConfig);

        // Assert
        verify(() => mockStorage.saveNonSecretConfig(any())).called(1);
        verify(() => mockStorage.saveSecret('mqtt_password', 'new-password')).called(1);
        verify(() => mockStorage.saveSecret('influx_token', 'new-token')).called(1);
        
        // Verify config was cached
        final cachedConfig = await repository.getConfig();
        expect(cachedConfig, equals(testConfig));
      });

      test('deletes secrets when empty', () async {
        // Arrange
        final testConfig = AppConfig(
          mqtt: const MqttConfig(
            host: 'new-host',
            port: 1885,
            username: 'new-user',
            password: '', // Empty password
          ),
          influx: const InfluxConfig(
            url: 'http://new-influx:8088',
            token: '', // Empty token
            organization: 'new-org',
            bucket: 'new-bucket',
          ),
          video: const VideoConfig(
            mjpegUrl: 'http://new-video:8082/stream',
            autoReconnect: true,
          ),
        );

        when(() => mockStorage.saveNonSecretConfig(any())).thenAnswer((_) async {});
        when(() => mockStorage.deleteSecret(any())).thenAnswer((_) async {});

        // Act
        await repository.updateConfig(testConfig);

        // Assert
        verify(() => mockStorage.deleteSecret('mqtt_password')).called(1);
        verify(() => mockStorage.deleteSecret('influx_token')).called(1);
        verifyNever(() => mockStorage.saveSecret('mqtt_password', any()));
        verifyNever(() => mockStorage.saveSecret('influx_token', any()));
      });
    });

    group('resetToDefaults', () {
      test('clears storage and broadcasts default config', () async {
        // Arrange
        when(() => mockStorage.clearAllConfig()).thenAnswer((_) async {});

        // Act
        await repository.resetToDefaults();

        // Assert
        verify(() => mockStorage.clearAllConfig()).called(1);
        
        // Verify default config is cached
        final cachedConfig = await repository.getConfig();
        expect(cachedConfig, equals(AppConfig.fromEnv()));
      });
    });
  });

  group('AppConfig', () {
    test('creates from environment', () {
      final config = AppConfig.fromEnv();
      
      expect(config.mqtt, isA<MqttConfig>());
      expect(config.influx, isA<InfluxConfig>());
      expect(config.video, isA<VideoConfig>());
    });

    test('copyWith works correctly', () {
      final original = AppConfig.fromEnv();
      const newMqtt = MqttConfig(
        host: 'new-host',
        port: 1885,
        username: 'new-user',
        password: 'new-password',
      );

      final updated = original.copyWith(mqtt: newMqtt);

      expect(updated.mqtt, equals(newMqtt));
      expect(updated.influx, equals(original.influx)); // Unchanged
      expect(updated.video, equals(original.video)); // Unchanged
    });

    test('equality works correctly', () {
      final config1 = AppConfig.fromEnv();
      final config2 = AppConfig.fromEnv();
      final config3 = config1.copyWith(
        mqtt: const MqttConfig(
          host: 'different',
          port: 1885,
          username: 'user',
          password: 'pass',
        ),
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });

  group('MqttConfig', () {
    test('creates from environment', () {
      final config = MqttConfig.fromEnv();
      
      expect(config.host, isA<String>());
      expect(config.port, isA<int>());
      expect(config.username, isA<String>());
      expect(config.password, isA<String>());
    });

    test('copyWith works correctly', () {
      const original = MqttConfig(
        host: 'original-host',
        port: 1883,
        username: 'original-user',
        password: 'original-pass',
      );

      final updated = original.copyWith(host: 'new-host', port: 1884);

      expect(updated.host, equals('new-host'));
      expect(updated.port, equals(1884));
      expect(updated.username, equals('original-user')); // Unchanged
      expect(updated.password, equals('original-pass')); // Unchanged
    });
  });

  group('InfluxConfig', () {
    test('creates from environment', () {
      final config = InfluxConfig.fromEnv();
      
      expect(config.url, isA<String>());
      expect(config.token, isA<String>());
      expect(config.organization, isA<String>());
      expect(config.bucket, isA<String>());
    });

    test('copyWith works correctly', () {
      const original = InfluxConfig(
        url: 'http://original:8086',
        token: 'original-token',
        organization: 'original-org',
        bucket: 'original-bucket',
      );

      final updated = original.copyWith(url: 'http://new:8087');

      expect(updated.url, equals('http://new:8087'));
      expect(updated.token, equals('original-token')); // Unchanged
      expect(updated.organization, equals('original-org')); // Unchanged
      expect(updated.bucket, equals('original-bucket')); // Unchanged
    });
  });

  group('VideoConfig', () {
    test('creates from environment', () {
      final config = VideoConfig.fromEnv();
      
      expect(config.mjpegUrl, isA<String>());
      expect(config.autoReconnect, isA<bool>());
    });

    test('copyWith works correctly', () {
      const original = VideoConfig(
        mjpegUrl: 'http://original:8080/stream',
        autoReconnect: true,
      );

      final updated = original.copyWith(mjpegUrl: 'http://new:8081/stream');

      expect(updated.mjpegUrl, equals('http://new:8081/stream'));
      expect(updated.autoReconnect, equals(true)); // Unchanged
    });

    test('defaults to autoReconnect true', () {
      const config = VideoConfig(mjpegUrl: 'http://test:8080/stream');
      expect(config.autoReconnect, equals(true));
    });
  });
}