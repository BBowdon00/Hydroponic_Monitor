import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/core/logger.dart';
import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/data/connection_recovery_service.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/domain/entities/reconnect_result.dart';

// Mock classes
class MockMqttService extends Mock implements MqttService {}

class MockInfluxDbService extends Mock implements InfluxDbService {}

void main() {
  group('ConnectionRecoveryService', () {
    late ConnectionRecoveryService service;
    late MockMqttService mockMqttService;
    late MockInfluxDbService mockInfluxService;

    setUpAll(() {
      Logger.init(isTest: true);
    });

    setUp(() {
      mockMqttService = MockMqttService();
      mockInfluxService = MockInfluxDbService();
      service = ConnectionRecoveryService(
        mqttService: mockMqttService,
        influxService: mockInfluxService,
      );
    });

    test('should reconnect both services successfully', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {});
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(() => mockMqttService.ensureInitialized()).thenAnswer((_) async {});
      // In new implementation we only perform a health check instead of initialize()+queryLatestSensorData()
      when(() => mockInfluxService.checkHealth()).thenAnswer((_) async => true);

      // Act
      final result = await service.manualReconnect();

      // Assert
      expect(result.mqttOk, isTrue);
      expect(result.influxOk, isTrue);
      expect(result.allOk, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.elapsed.inMilliseconds, greaterThan(0));

      verify(() => mockMqttService.reset()).called(1);
      verify(() => mockMqttService.connect()).called(1);
      verify(() => mockMqttService.ensureInitialized()).called(1);
      verify(() => mockInfluxService.checkHealth()).called(1);
    });

    test('should handle MQTT failure gracefully', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {});
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Failure(MqttError('Connection failed')));
      when(() => mockInfluxService.checkHealth()).thenAnswer((_) async => true);

      // Act
      final result = await service.manualReconnect();

      // Assert
      expect(result.mqttOk, isFalse);
      expect(result.influxOk, isTrue);
      expect(result.partialSuccess, isTrue);
      expect(result.errorMessage, contains('MQTT reconnection failed'));
      expect(result.errorMessage, contains('Connection failed'));
    });

    test('should handle InfluxDB failure gracefully', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {});
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(() => mockMqttService.ensureInitialized()).thenAnswer((_) async {});
      // Simulate an exception during health check to mirror old failure surface
      when(
        () => mockInfluxService.checkHealth(),
      ).thenThrow(Exception('DB unavailable'));

      // Act
      final result = await service.manualReconnect();

      // Assert
      expect(result.mqttOk, isTrue);
      expect(result.influxOk, isFalse);
      expect(result.partialSuccess, isTrue);
      expect(result.errorMessage, contains('InfluxDB health check failed'));
      expect(result.errorMessage, contains('DB unavailable'));
    });

    test('should handle both services failing', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {});
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Failure(MqttError('MQTT down')));
      when(
        () => mockInfluxService.checkHealth(),
      ).thenThrow(Exception('Influx down'));

      // Act
      final result = await service.manualReconnect();

      // Assert
      expect(result.mqttOk, isFalse);
      expect(result.influxOk, isFalse);
      expect(result.allFailed, isTrue);
      expect(result.errorMessage, contains('MQTT reconnection failed'));
      expect(result.errorMessage, contains('InfluxDB health check failed'));
    });

    test('should throttle consecutive attempts', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {});
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(() => mockMqttService.ensureInitialized()).thenAnswer((_) async {});
      when(() => mockInfluxService.checkHealth()).thenAnswer((_) async => true);

      // Act - first attempt
      final result1 = await service.manualReconnect();
      expect(result1.allOk, isTrue);

      // Act - immediate second attempt (should be throttled)
      final result2 = await service.manualReconnect();

      // Assert
      expect(result2.allFailed, isTrue);
      expect(result2.errorMessage, contains('Please wait 5s'));
      expect(result2.elapsed, equals(Duration.zero));

      // Verify reset was only called once (for the first attempt)
      verify(() => mockMqttService.reset()).called(1);
    });

    test('should allow forced reconnection even when throttled', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {});
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(() => mockMqttService.ensureInitialized()).thenAnswer((_) async {});
      when(() => mockInfluxService.checkHealth()).thenAnswer((_) async => true);

      // Act - first attempt
      final result1 = await service.manualReconnect();
      expect(result1.allOk, isTrue);

      // Act - immediate forced second attempt
      final result2 = await service.manualReconnect(force: true);

      // Assert
      expect(result2.allOk, isTrue);

      // Verify reset was called twice (for both attempts)
      verify(() => mockMqttService.reset()).called(2);
    });

    test('should prevent concurrent attempts', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(() => mockMqttService.ensureInitialized()).thenAnswer((_) async {});
      when(() => mockInfluxService.checkHealth()).thenAnswer((_) async => true);

      // Act - start first attempt (will be slow due to delay)
      final future1 = service.manualReconnect();

      // Small delay to ensure first attempt has started
      await Future.delayed(const Duration(milliseconds: 10));

      // Act - start second attempt immediately (should be rejected)
      final result2 = await service.manualReconnect();

      // Assert second attempt was rejected due to throttling or in-progress
      expect(result2.allFailed, isTrue);
      expect(
        result2.errorMessage,
        anyOf([contains('already in progress'), contains('Please wait 5s')]),
      );

      // Wait for first attempt to complete
      final result1 = await future1;
      expect(result1.allOk, isTrue);

      // Verify reset was only called once
      verify(() => mockMqttService.reset()).called(1);
    });

    test('should provide progress information via properties', () async {
      // Arrange
      when(() => mockMqttService.reset()).thenAnswer((_) async {});
      when(
        () => mockMqttService.connect(),
      ).thenAnswer((_) async => const Success(null));
      when(() => mockMqttService.ensureInitialized()).thenAnswer((_) async {});
      when(() => mockInfluxService.checkHealth()).thenAnswer((_) async => true);

      // Assert initial state
      expect(service.isInProgress, isFalse);
      expect(service.lastAttempt, isNull);
      expect(service.canAttemptReconnect, isTrue);

      // Act
      await service.manualReconnect();

      // Assert after attempt
      expect(service.isInProgress, isFalse);
      expect(service.lastAttempt, isNotNull);
      expect(service.canAttemptReconnect, isFalse); // Should be throttled
    });
  });

  group('ReconnectResult', () {
    test('should correctly identify all success state', () {
      const result = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 500),
      );

      expect(result.allOk, isTrue);
      expect(result.allFailed, isFalse);
      expect(result.partialSuccess, isFalse);
    });

    test('should correctly identify all failed state', () {
      const result = ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration(milliseconds: 500),
        errorMessage: 'Both services failed',
      );

      expect(result.allOk, isFalse);
      expect(result.allFailed, isTrue);
      expect(result.partialSuccess, isFalse);
    });

    test('should correctly identify partial success states', () {
      const result1 = ReconnectResult(
        mqttOk: true,
        influxOk: false,
        elapsed: Duration(milliseconds: 500),
        errorMessage: 'InfluxDB failed',
      );

      const result2 = ReconnectResult(
        mqttOk: false,
        influxOk: true,
        elapsed: Duration(milliseconds: 500),
        errorMessage: 'MQTT failed',
      );

      expect(result1.allOk, isFalse);
      expect(result1.allFailed, isFalse);
      expect(result1.partialSuccess, isTrue);

      expect(result2.allOk, isFalse);
      expect(result2.allFailed, isFalse);
      expect(result2.partialSuccess, isTrue);
    });

    test('should provide meaningful toString representation', () {
      const result1 = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 250),
      );

      const result2 = ReconnectResult(
        mqttOk: true,
        influxOk: false,
        elapsed: Duration(milliseconds: 750),
        errorMessage: 'InfluxDB connection failed',
      );

      expect(
        result1.toString(),
        contains('All services reconnected successfully'),
      );
      expect(result1.toString(), contains('250ms'));

      expect(result2.toString(), contains('Partial reconnection'));
      expect(result2.toString(), contains('MQTT OK'));
      expect(result2.toString(), contains('InfluxDB Failed'));
      expect(result2.toString(), contains('750ms'));
      expect(result2.toString(), contains('InfluxDB connection failed'));
    });

    test('should support equality comparison', () {
      const result1 = ReconnectResult(
        mqttOk: true,
        influxOk: false,
        elapsed: Duration(milliseconds: 500),
        errorMessage: 'Test error',
      );

      const result2 = ReconnectResult(
        mqttOk: true,
        influxOk: false,
        elapsed: Duration(milliseconds: 500),
        errorMessage: 'Test error',
      );

      const result3 = ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration(milliseconds: 500),
        errorMessage: 'Test error',
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });
}
