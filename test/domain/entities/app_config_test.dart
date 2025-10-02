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
      const mjpeg = MjpegConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      );

      const config = AppConfig(mqtt: mqtt, influx: influx, mjpeg: mjpeg);

      expect(config.mqtt, mqtt);
      expect(config.influx, influx);
      expect(config.mjpeg, mjpeg);
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
      const mjpeg = MjpegConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      );

      const config = AppConfig(mqtt: mqtt, influx: influx, mjpeg: mjpeg);

      final newMqtt = mqtt.copyWith(host: 'newhost');
      final updatedConfig = config.copyWith(mqtt: newMqtt);

      expect(updatedConfig.mqtt.host, 'newhost');
      expect(updatedConfig.mqtt.port, 1883);
      expect(updatedConfig.influx, influx);
      expect(updatedConfig.mjpeg, mjpeg);
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
      const mjpeg = MjpegConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      );

      const config1 = AppConfig(mqtt: mqtt, influx: influx, mjpeg: mjpeg);
      const config2 = AppConfig(mqtt: mqtt, influx: influx, mjpeg: mjpeg);

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
      const mjpeg = MjpegConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      );

      const config = AppConfig(mqtt: mqtt, influx: influx, mjpeg: mjpeg);

      expect(config.toString(), contains('AppConfig'));
      expect(config.toString(), contains('mqtt:'));
      expect(config.toString(), contains('influx:'));
      expect(config.toString(), contains('mjpeg:'));
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

  group('MjpegConfig', () {
    test('copyWith updates only specified fields', () {
      const config = MjpegConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      );

      final updated = config.copyWith(autoReconnect: false);

      expect(updated.url, 'http://localhost:8080/stream');
      expect(updated.autoReconnect, false);
    });

    test('equality works correctly', () {
      const config1 = MjpegConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      );
      const config2 = MjpegConfig(
        url: 'http://localhost:8080/stream',
        autoReconnect: true,
      );

      expect(config1, config2);
      expect(config1.hashCode, config2.hashCode);
    });
  });
}
