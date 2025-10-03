import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';

void main() {
  group('InfluxDbService.normalizeUrl', () {
    test('adds http scheme when missing with port and path', () {
      final raw = 'my-host:8080/influxdb';
      final normalized = InfluxDbService.normalizeUrl(raw);
      expect(normalized.startsWith('http://'), isTrue);
      expect(normalized.contains('my-host'), isTrue);
      expect(normalized.contains(':8080'), isTrue);
    });

    test('preserves https scheme when present', () {
      final raw = 'https://example.com:8443/influxdb';
      final normalized = InfluxDbService.normalizeUrl(raw);
      expect(normalized.startsWith('https://'), isTrue);
      expect(normalized.contains(':8443'), isTrue);
    });

    test('trims whitespace', () {
      final raw = '  http://example.com:8086  ';
      final normalized = InfluxDbService.normalizeUrl(raw);
      expect(normalized, 'http://example.com:8086');
    });

    test('returns empty string unchanged', () {
      expect(InfluxDbService.normalizeUrl(''), '');
    });
  });
}
