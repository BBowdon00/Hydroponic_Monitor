import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/core/logger.dart';
import 'package:hydroponic_monitor/data/connection_recovery_service.dart';
import 'package:hydroponic_monitor/domain/entities/reconnect_result.dart';
import 'package:hydroponic_monitor/presentation/providers/manual_reconnect_provider.dart';

// Mock classes
class MockConnectionRecoveryService extends Mock implements ConnectionRecoveryService {}

void main() {
  group('ManualReconnectProvider', () {
    late ProviderContainer container;
    late MockConnectionRecoveryService mockService;

    setUpAll(() {
      Logger.init(isTest: true);
    });

    setUp(() {
      mockService = MockConnectionRecoveryService();
      container = ProviderContainer(
        overrides: [
          connectionRecoveryServiceProvider.overrideWithValue(mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should have initial idle state', () {
      final state = container.read(manualReconnectProvider);

      expect(state.inProgress, isFalse);
      expect(state.lastResult, isNull);
      expect(state.lastAttempt, isNull);
      expect(state.canAttempt, isTrue);
    });

    test('should update state during successful reconnect', () async {
      // Arrange
      const expectedResult = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 300),
      );

      when(() => mockService.manualReconnect(force: false))
          .thenAnswer((_) async => expectedResult);

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act
      final actualResult = await notifier.attemptReconnect();
      final finalState = container.read(manualReconnectProvider);

      // Assert
      expect(actualResult, equals(expectedResult));
      expect(finalState.inProgress, isFalse);
      expect(finalState.lastResult, equals(expectedResult));
      expect(finalState.lastAttempt, isNotNull);
      expect(finalState.canAttempt, isFalse); // Should be throttled
    });

    test('should update state during failed reconnect', () async {
      // Arrange
      const expectedResult = ReconnectResult(
        mqttOk: false,
        influxOk: false,
        elapsed: Duration(milliseconds: 150),
        errorMessage: 'Both services failed',
      );

      when(() => mockService.manualReconnect(force: false))
          .thenAnswer((_) async => expectedResult);

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act
      final actualResult = await notifier.attemptReconnect();
      final finalState = container.read(manualReconnectProvider);

      // Assert
      expect(actualResult, equals(expectedResult));
      expect(finalState.inProgress, isFalse);
      expect(finalState.lastResult, equals(expectedResult));
      expect(finalState.lastAttempt, isNotNull);
    });

    test('should set in-progress state during reconnect attempt', () async {
      // Arrange
      const expectedResult = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 300),
      );

      when(() => mockService.manualReconnect(force: false))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return expectedResult;
      });

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act - start the reconnect (don't await yet)
      final futureResult = notifier.attemptReconnect();
      
      // Check state immediately (should be in progress)
      var currentState = container.read(manualReconnectProvider);
      expect(currentState.inProgress, isTrue);

      // Wait for completion
      await futureResult;

      // Check final state
      currentState = container.read(manualReconnectProvider);
      expect(currentState.inProgress, isFalse);
    });

    test('should reject concurrent attempts when in progress', () async {
      // Arrange
      const result1 = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 300),
      );

      when(() => mockService.manualReconnect(force: false))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return result1;
      });

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act - start first attempt
      final future1 = notifier.attemptReconnect();
      
      // Act - try second attempt immediately
      final result2 = await notifier.attemptReconnect();

      // Assert second attempt was rejected
      expect(result2.allFailed, isTrue);
      expect(result2.errorMessage, contains('already in progress'));

      // Wait for first to complete
      final firstResult = await future1;
      expect(firstResult.allOk, isTrue);

      // Verify service was only called once
      verify(() => mockService.manualReconnect(force: false)).called(1);
    });

    test('should reject attempt when throttled', () async {
      // Arrange - set up a state with recent attempt
      const previousResult = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 200),
      );

      when(() => mockService.manualReconnect(force: false))
          .thenAnswer((_) async => previousResult);

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act - first attempt
      await notifier.attemptReconnect();

      // Act - immediate second attempt (should be throttled)
      final result2 = await notifier.attemptReconnect();

      // Assert
      expect(result2.allFailed, isTrue);
      expect(result2.errorMessage, contains('Please wait 5 seconds'));
      expect(result2.elapsed, equals(Duration.zero));

      // Verify service was only called once
      verify(() => mockService.manualReconnect(force: false)).called(1);
    });

    test('should allow forced reconnect even when throttled', () async {
      // Arrange
      const result1 = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 200),
      );

      const result2 = ReconnectResult(
        mqttOk: true,
        influxOk: false,
        elapsed: Duration(milliseconds: 350),
        errorMessage: 'InfluxDB failed on retry',
      );

      when(() => mockService.manualReconnect(force: false))
          .thenAnswer((_) async => result1);
      when(() => mockService.manualReconnect(force: true))
          .thenAnswer((_) async => result2);

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act - first attempt
      final actualResult1 = await notifier.attemptReconnect();
      expect(actualResult1, equals(result1));

      // Act - immediate forced second attempt
      final actualResult2 = await notifier.attemptReconnect(force: true);
      expect(actualResult2, equals(result2));

      // Verify both calls were made
      verify(() => mockService.manualReconnect(force: false)).called(1);
      verify(() => mockService.manualReconnect(force: true)).called(1);
    });

    test('should handle service exceptions gracefully', () async {
      // Arrange
      when(() => mockService.manualReconnect(force: false))
          .thenThrow(Exception('Service crashed'));

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act
      final result = await notifier.attemptReconnect();

      // Assert
      expect(result.allFailed, isTrue);
      expect(result.errorMessage, contains('Unexpected error during reconnection'));
      expect(result.errorMessage, contains('Service crashed'));
      
      final finalState = container.read(manualReconnectProvider);
      expect(finalState.inProgress, isFalse);
      expect(finalState.lastResult, equals(result));
    });

    test('should track state history correctly', () async {
      // Arrange
      const result1 = ReconnectResult(
        mqttOk: true,
        influxOk: false,
        elapsed: Duration(milliseconds: 200),
        errorMessage: 'InfluxDB down',
      );

      const result2 = ReconnectResult(
        mqttOk: true,
        influxOk: true,
        elapsed: Duration(milliseconds: 300),
      );

      when(() => mockService.manualReconnect(force: false))
          .thenAnswer((_) async => result1);
      when(() => mockService.manualReconnect(force: true))
          .thenAnswer((_) async => result2);

      final notifier = container.read(manualReconnectProvider.notifier);

      // Act - first attempt (partial success)
      await notifier.attemptReconnect();
      var state = container.read(manualReconnectProvider);
      expect(state.lastResult, equals(result1));

      // Act - second attempt (full success, forced)
      await notifier.attemptReconnect(force: true);
      state = container.read(manualReconnectProvider);
      expect(state.lastResult, equals(result2));
    });
  });

  group('ManualReconnectState', () {
    test('should correctly determine canAttempt based on timing', () {
      final now = DateTime.now();

      // No previous attempt - should be able to attempt
      const state1 = ManualReconnectState();
      expect(state1.canAttempt, isTrue);

      // Recent attempt - should be throttled
      final state2 = ManualReconnectState(
        lastAttempt: now.subtract(const Duration(seconds: 3)),
      );
      expect(state2.canAttempt, isFalse);

      // Old attempt - should be able to attempt
      final state3 = ManualReconnectState(
        lastAttempt: now.subtract(const Duration(seconds: 6)),
      );
      expect(state3.canAttempt, isTrue);
    });

    test('should support copyWith for immutable updates', () {
      const originalState = ManualReconnectState(
        inProgress: false,
        lastResult: ReconnectResult(
          mqttOk: true,
          influxOk: false,
          elapsed: Duration(milliseconds: 200),
        ),
      );

      final updatedState = originalState.copyWith(inProgress: true);

      expect(originalState.inProgress, isFalse);
      expect(updatedState.inProgress, isTrue);
      expect(updatedState.lastResult, equals(originalState.lastResult));
      expect(updatedState.lastAttempt, equals(originalState.lastAttempt));
    });

    test('should provide meaningful toString representation', () {
      const state = ManualReconnectState(
        inProgress: true,
        lastResult: ReconnectResult(
          mqttOk: true,
          influxOk: false,
          elapsed: Duration(milliseconds: 150),
          errorMessage: 'InfluxDB failed',
        ),
      );

      final str = state.toString();
      expect(str, contains('ManualReconnectState'));
      expect(str, contains('inProgress: true'));
      expect(str, contains('canAttempt:'));
    });

    test('should support equality comparison', () {
      const state1 = ManualReconnectState(
        inProgress: true,
        lastResult: ReconnectResult(
          mqttOk: true,
          influxOk: false,
          elapsed: Duration(milliseconds: 200),
        ),
      );

      const state2 = ManualReconnectState(
        inProgress: true,
        lastResult: ReconnectResult(
          mqttOk: true,
          influxOk: false,
          elapsed: Duration(milliseconds: 200),
        ),
      );

      const state3 = ManualReconnectState(
        inProgress: false,
        lastResult: ReconnectResult(
          mqttOk: true,
          influxOk: false,
          elapsed: Duration(milliseconds: 200),
        ),
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}