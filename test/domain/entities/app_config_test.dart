import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';

void main() {
  group('AppConfig', () {
    test('creates config with default values', () {
      const mqtt = MqttConfig(
        host: 'localhost',
        port: 1883,
        username: 'user',
        password: 'pass',
      );
      const influx = InfluxConfig(
        url: 'http://localhost:8086',
        token: 'token',
        org: 'org',
        bucket: 'bucket',
      );
      const hls = HlsConfig(
        url: 'http://localhost:8080/hls/stream.m3u8',
        autoReconnect: true,
      );

      const config = AppConfig(mqtt: mqtt, influx: influx, hls: hls);

      expect(config.mqtt, mqtt);
      expect(config.influx, influx);
      expect(config.hls, hls);
    });

    test('copyWith creates a new instance with updated values', () {
      const mqtt = MqttConfig(
        host: 'localhost',
        port: 1883,
        username: 'user',
        password: 'pass',
      );
      const influx = InfluxConfig(
        url: 'http://localhost:8086',
        token: 'token',
        org: 'org',
        bucket: 'bucket',
      );
      const hls = HlsConfig(
        url: 'http://localhost:8080/hls/stream.m3u8',
        autoReconnect: true,
      );

      const config = AppConfig(mqtt: mqtt, influx: influx, hls: hls);

      final newMqtt = mqtt.copyWith(host: 'newhost');
      final updatedConfig = config.copyWith(mqtt: newMqtt);

      expect(updatedConfig.mqtt.host, 'newhost');
      expect(updatedConfig.mqtt.port, 1883);
      expect(updatedConfig.influx, influx);
      expect(updatedConfig.hls, hls);
    });

    test('equality works correctly', () {
      const mqtt = MqttConfig(
        host: 'localhost',
        port: 1883,
        username: 'user',
        password: 'pass',
      );
      const influx = InfluxConfig(
        url: 'http://localhost:8086',
        token: 'token',
        org: 'org',
        bucket: 'bucket',
      );
      const hls = HlsConfig(
        url: 'http://localhost:8080/hls/stream.m3u8',
        autoReconnect: true,
      );

      const config1 = AppConfig(mqtt: mqtt, influx: influx, hls: hls);
      const config2 = AppConfig(mqtt: mqtt, influx: influx, hls: hls);

      expect(config1, config2);
      expect(config1.hashCode, config2.hashCode);
    });

    test('toString works correctly', () {
      const mqtt = MqttConfig(
        host: 'localhost',
        port: 1883,
        username: 'user',
        password: 'pass',
      );
      const influx = InfluxConfig(
        url: 'http://localhost:8086',
        token: 'token',
        org: 'org',
        bucket: 'bucket',
      );
      const hls = HlsConfig(
        url: 'http://localhost:8080/hls/stream.m3u8',
        autoReconnect: true,
      );

      const config = AppConfig(mqtt: mqtt, influx: influx, hls: hls);

      expect(config.toString(), contains('AppConfig'));
      expect(config.toString(), contains('mqtt:'));
      expect(config.toString(), contains('influx:'));
      expect(config.toString(), contains('hls:'));
    });
  });

  group('MqttConfig', () {
    test('copyWith updates only specified fields', () {
      const config = MqttConfig(
        host: 'localhost',
        port: 1883,
        username: 'user',
        password: 'pass',
      );

      final updated = config.copyWith(host: 'newhost', port: 8883);

      expect(updated.host, 'newhost');
      expect(updated.port, 8883);
      expect(updated.username, 'user');
      expect(updated.password, 'pass');
    });

    test('toString masks password', () {
      const config = MqttConfig(
        host: 'localhost',
        port: 1883,
        username: 'user',
        password: 'secret',
      );

      expect(config.toString(), contains('***'));
      expect(config.toString(), isNot(contains('secret')));
    });
  });

  group('InfluxConfig', () {
    test('copyWith updates only specified fields', () {
      const config = InfluxConfig(
        url: 'http://localhost:8086',
        token: 'token',
        org: 'org',
        bucket: 'bucket',
      );

      final updated = config.copyWith(url: 'http://newhost:8086');

      expect(updated.url, 'http://newhost:8086');
      expect(updated.token, 'token');
      expect(updated.org, 'org');
      expect(updated.bucket, 'bucket');
    });

    test('toString masks token', () {
      const config = InfluxConfig(
        url: 'http://localhost:8086',
        token: 'secret-token',
        org: 'org',
        bucket: 'bucket',
      );

      expect(config.toString(), contains('***'));
      expect(config.toString(), isNot(contains('secret-token')));
    });
  });

  group('HlsConfig', () {
    test('copyWith updates only specified fields', () {
      const config = HlsConfig(
        url: 'http://localhost:8080/hls/stream.m3u8',
        autoReconnect: true,
      );

      final updated = config.copyWith(autoReconnect: false);

      expect(updated.url, 'http://localhost:8080/hls/stream.m3u8');
      expect(updated.autoReconnect, false);
    });

    test('equality works correctly', () {
      const config1 = HlsConfig(
        url: 'http://localhost:8080/hls/stream.m3u8',
        autoReconnect: true,
      );
      const config2 = HlsConfig(
        url: 'http://localhost:8080/hls/stream.m3u8',
        autoReconnect: true,
      );

      expect(config1, config2);
      expect(config1.hashCode, config2.hashCode);
    });
  });
}
