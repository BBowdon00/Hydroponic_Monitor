import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import '../test_utils.dart';

class MockMqttService extends Mock implements MqttService {}

class MockInfluxDbService extends Mock implements InfluxDbService {}

/// Tests for error handling scenarios that can occur during network operations.
void main() {
  setUpAll(() {
    registerFallbackValue(TestDataGenerator.createFallbackSensorData());
  });

  group('Network Error Handling', () {
    late SensorRepository repository;
    late MockMqttService mockMqttService;
    late MockInfluxDbService mockInfluxService;

    setUp(() {
      mockMqttService = MockMqttService();
      mockInfluxService = MockInfluxDbService();
      repository = SensorRepository(
        mqttService: mockMqttService,
        influxService: mockInfluxService,
      );
    });

    test('handles MQTT connection timeout gracefully', () async {
      // Simulate connection timeout
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Failure(MqttError('Connection timeout')));

      final result = await repository.initialize();

      expect(result, isA<Failure>());
      expect((result as Failure).error.message, contains('Connection timeout'));
    });

    test('handles InfluxDB service unavailable gracefully', () async {
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(() => mockInfluxService.initialize()).thenAnswer(
        (_) async => const Failure(InfluxError('Service unavailable')),
      );
      when(
        () => mockMqttService.sensorDataStream,
      ).thenAnswer((_) => const Stream.empty());

      final result = await repository.initialize();

      expect(result, isA<Failure>());
      expect(
        (result as Failure).error.message,
        contains('Service unavailable'),
      );
    });

    test('handles intermittent MQTT disconnections', () async {
      // Setup successful initial connection
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => mockInfluxService.initialize(),
      ).thenAnswer((_) async => const Success(null));

      // Simulate MQTT stream with errors
      when(
        () => mockMqttService.sensorDataStream,
      ).thenAnswer((_) => Stream.error('MQTT disconnection'));

      await repository.initialize();

      // Should handle stream errors gracefully without crashing
      expect(repository.realTimeSensorData, emitsError(isA<String>()));
    });

    test('handles InfluxDB query failures', () async {
      when(
        () => mockInfluxService.queryLatestSensorData(),
      ).thenAnswer((_) async => const Failure(InfluxError('Query failed')));

      final result = await repository.getLatestReadings();

      expect(result, isA<Failure>());
      expect((result as Failure).error, isA<InfluxError>());
    });
  });
}
