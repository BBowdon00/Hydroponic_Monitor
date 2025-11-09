import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late SharedPreferences prefs;
  late ConfigRepository repository;

  setUpAll(() async {
    // Initialize dotenv with test values
    await dotenv.load(fileName: '.env.test');
  });

  setUp(() async {
    // Initialize SharedPreferences with in-memory implementation
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    mockSecureStorage = MockFlutterSecureStorage();
    repository = ConfigRepository(
      secureStorage: mockSecureStorage,
      prefs: prefs,
    );

    // Set up default mock behavior
    when(
      () => mockSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockSecureStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async => {});
  });

  group('ConfigRepository', () {
    test('loadConfig returns default values when no config is saved', () async {
      final config = await repository.loadConfig();

      expect(config, isA<AppConfig>());
      expect(config.mqtt, isA<MqttConfig>());
      expect(config.influx, isA<InfluxConfig>());
      expect(config.hls, isA<HlsConfig>());
    });

    test(
      'saveConfig persists non-secret values to SharedPreferences',
      () async {
        const config = AppConfig(
          mqtt: MqttConfig(
            host: 'test.mqtt.com',
            port: 1883,
            username: 'testuser',
            password: 'testpass',
          ),
          influx: InfluxConfig(
            url: 'http://test.influx.com:8086',
            token: 'testtoken',
            org: 'testorg',
            bucket: 'testbucket',
          ),
          hls: HlsConfig(
            url: 'http://test.stream.com:8080/stream',
            autoReconnect: false,
          ),
        );

        await repository.saveConfig(config);

        // Verify non-secret values are saved to SharedPreferences
        expect(prefs.getString('mqtt_host'), 'test.mqtt.com');
        expect(prefs.getInt('mqtt_port'), 1883);
        expect(prefs.getString('mqtt_username'), 'testuser');
        expect(prefs.getString('influx_url'), 'http://test.influx.com:8086');
        expect(prefs.getString('influx_org'), 'testorg');
        expect(prefs.getString('influx_bucket'), 'testbucket');
        expect(
          prefs.getString('hls_url'),
          'http://test.stream.com:8080/stream',
        );
        expect(prefs.getBool('hls_auto_reconnect'), false);

        // Verify secrets are saved to secure storage
        verify(
          () =>
              mockSecureStorage.write(key: 'mqtt_password', value: 'testpass'),
        ).called(1);
        verify(
          () =>
              mockSecureStorage.write(key: 'influx_token', value: 'testtoken'),
        ).called(1);
      },
    );

    test('loadConfig retrieves saved configuration', () async {
      // Set up mock secure storage to return secrets
      when(
        () => mockSecureStorage.read(key: 'mqtt_password'),
      ).thenAnswer((_) async => 'saved_password');
      when(
        () => mockSecureStorage.read(key: 'influx_token'),
      ).thenAnswer((_) async => 'saved_token');

      // Save a configuration
      await prefs.setString('mqtt_host', 'saved.mqtt.com');
      await prefs.setInt('mqtt_port', 8883);
      await prefs.setString('mqtt_username', 'saveduser');
      await prefs.setString('influx_url', 'http://saved.influx.com:8086');
      await prefs.setString('influx_org', 'savedorg');
      await prefs.setString('influx_bucket', 'savedbucket');
      await prefs.setString('hls_url', 'http://saved.stream.com:8080/stream');
      await prefs.setBool('hls_auto_reconnect', true);

      // Load the configuration
      final config = await repository.loadConfig();

      expect(config.mqtt.host, 'saved.mqtt.com');
      expect(config.mqtt.port, 8883);
      expect(config.mqtt.username, 'saveduser');
      expect(config.mqtt.password, 'saved_password');
      expect(config.influx.url, 'http://saved.influx.com:8086');
      expect(config.influx.token, 'saved_token');
      expect(config.influx.org, 'savedorg');
      expect(config.influx.bucket, 'savedbucket');
      expect(config.hls.url, 'http://saved.stream.com:8080/stream');
      expect(config.hls.autoReconnect, true);
    });

    test('clearConfig removes all saved configuration', () async {
      // Save some configuration
      await prefs.setString('mqtt_host', 'test.mqtt.com');
      await prefs.setInt('mqtt_port', 1883);
      await prefs.setString('mqtt_username', 'testuser');

      await repository.clearConfig();

      // Verify SharedPreferences are cleared
      expect(prefs.getString('mqtt_host'), isNull);
      expect(prefs.getInt('mqtt_port'), isNull);
      expect(prefs.getString('mqtt_username'), isNull);

      // Verify secure storage is cleared
      verify(() => mockSecureStorage.delete(key: 'mqtt_password')).called(1);
      verify(() => mockSecureStorage.delete(key: 'influx_token')).called(1);
    });

    test('loadConfig returns defaults on error', () async {
      // Simulate an error in secure storage
      when(
        () => mockSecureStorage.read(key: any(named: 'key')),
      ).thenThrow(Exception('Storage error'));

      final config = await repository.loadConfig();

      // Should return default config without throwing
      expect(config, isA<AppConfig>());
    });

    test('saveConfig throws on error', () async {
      // Simulate an error in secure storage
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(Exception('Storage error'));

      const config = AppConfig(
        mqtt: MqttConfig(
          host: 'test.mqtt.com',
          port: 1883,
          username: 'testuser',
          password: 'testpass',
        ),
        influx: InfluxConfig(
          url: 'http://test.influx.com:8086',
          token: 'testtoken',
          org: 'testorg',
          bucket: 'testbucket',
        ),
        hls: HlsConfig(
          url: 'http://test.stream.com:8080/stream',
          autoReconnect: false,
        ),
      );

      expect(() => repository.saveConfig(config), throwsA(isA<Exception>()));
    });

    test('clearConfig throws on error', () async {
      // Simulate an error in secure storage
      when(
        () => mockSecureStorage.delete(key: any(named: 'key')),
      ).thenThrow(Exception('Storage error'));

      expect(() => repository.clearConfig(), throwsA(isA<Exception>()));
    });
  });
}
