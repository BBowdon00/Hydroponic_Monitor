import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/presentation/pages/video_page.dart';
import '../test_utils.dart';

/// Unit tests for MJPEG streaming video state management.
/// Tests the core logic for connection handling, state transitions,
/// and stream parameter management without requiring actual network connections.
void main() {
  group('VideoState Model', () {
    test('should create VideoState with all required fields', () {
      const state = VideoState(
        streamUrl: 'http://test.local:8080/stream',
        isConnected: false,
        isConnecting: false,
        resolution: Size(640, 480),
        fps: 30,
        latency: 150,
      );

      expect(state.streamUrl, equals('http://test.local:8080/stream'));
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
      expect(state.resolution, equals(const Size(640, 480)));
      expect(state.fps, equals(30));
      expect(state.latency, equals(150));
    });

    test('should create copy with modified fields', () {
      const original = VideoState(
        streamUrl: 'http://original.local:8080/stream',
        isConnected: false,
        isConnecting: false,
        resolution: Size(640, 480),
        fps: 30,
        latency: 150,
      );

      final modified = original.copyWith(
        streamUrl: 'http://new.local:8080/stream',
        isConnected: true,
        resolution: const Size(1280, 720),
      );

      expect(modified.streamUrl, equals('http://new.local:8080/stream'));
      expect(modified.isConnected, isTrue);
      expect(modified.isConnecting, isFalse); // Unchanged
      expect(modified.resolution, equals(const Size(1280, 720)));
      expect(modified.fps, equals(30)); // Unchanged
      expect(modified.latency, equals(150)); // Unchanged
    });

    test('should create copy without changes when no parameters provided', () {
      const original = VideoState(
        streamUrl: 'http://test.local:8080/stream',
        isConnected: true,
        isConnecting: false,
        resolution: Size(1280, 720),
        fps: 60,
        latency: 100,
      );

      final copy = original.copyWith();

      expect(copy.streamUrl, equals(original.streamUrl));
      expect(copy.isConnected, equals(original.isConnected));
      expect(copy.isConnecting, equals(original.isConnecting));
      expect(copy.resolution, equals(original.resolution));
      expect(copy.fps, equals(original.fps));
      expect(copy.latency, equals(original.latency));
    });
  });

  group('VideoStateNotifier', () {
    late ProviderContainer container;
    late VideoStateNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(videoStateProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with default state', () {
      final state = container.read(videoStateProvider);

      expect(state.streamUrl, equals('http://192.168.1.100:8080/stream'));
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
      expect(state.resolution, equals(const Size(640, 480)));
      expect(state.fps, equals(30));
      expect(state.latency, equals(150));
    });

    test('should update stream URL', () {
      const newUrl = 'http://raspberry.local:8080/mjpeg';

      notifier.setStreamUrl(newUrl);

      final state = container.read(videoStateProvider);
      expect(state.streamUrl, equals(newUrl));
      expect(state.isConnected, isFalse); // Other fields unchanged
      expect(state.isConnecting, isFalse);
    });

    test('should handle empty URL', () {
      const emptyUrl = '';

      notifier.setStreamUrl(emptyUrl);

      final state = container.read(videoStateProvider);
      expect(state.streamUrl, equals(emptyUrl));
    });

    test('should start connection process', () {
      notifier.connect();

      final state = container.read(videoStateProvider);
      expect(state.isConnecting, isTrue);
      expect(state.isConnected, isFalse);
    });

    test('should complete connection after delay', () async {
      notifier.connect();

      // Verify connecting state
      expect(container.read(videoStateProvider).isConnecting, isTrue);
      expect(container.read(videoStateProvider).isConnected, isFalse);

      // Wait for simulated connection delay
      await Future.delayed(const Duration(seconds: 3));

      final state = container.read(videoStateProvider);
      expect(state.isConnecting, isFalse);
      expect(state.isConnected, isTrue);
      expect(state.resolution, equals(const Size(1280, 720))); // HD resolution
      expect(state.fps, equals(30));
      expect(state.latency, greaterThanOrEqualTo(120));
      expect(state.latency, lessThanOrEqualTo(220));
    });

    test('should disconnect immediately', () {
      // First connect
      notifier.connect();

      // Then disconnect
      notifier.disconnect();

      final state = container.read(videoStateProvider);
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
    });

    test('should handle disconnect when not connected', () {
      // Disconnect when already disconnected
      notifier.disconnect();

      final state = container.read(videoStateProvider);
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
    });

    test('should update latency on refresh', () {
      final originalLatency = container.read(videoStateProvider).latency;

      notifier.refresh();

      final newLatency = container.read(videoStateProvider).latency;
      expect(newLatency, isNot(equals(originalLatency)));
      expect(newLatency, greaterThanOrEqualTo(100));
      expect(newLatency, lessThanOrEqualTo(250));
    });

    test('should handle multiple refreshes', () async {
      final latencies = <int>{};

      // Multiple refreshes should generate different latencies
      for (int i = 0; i < 10; i++) {
        notifier.refresh();
        latencies.add(container.read(videoStateProvider).latency);
        // Small delay to ensure different millisecond values
        await Future.delayed(const Duration(milliseconds: 1));
      }

      // Should have some variation in latency values
      expect(latencies.length, greaterThan(1));
    });

    test('should handle connection during connecting state', () {
      notifier.connect();
      expect(container.read(videoStateProvider).isConnecting, isTrue);

      // Try to connect again while connecting
      notifier.connect();

      // Should still be in connecting state
      expect(container.read(videoStateProvider).isConnecting, isTrue);
      expect(container.read(videoStateProvider).isConnected, isFalse);
    });

    test('should handle multiple URL changes', () {
      const urls = [
        'http://camera1.local:8080/stream',
        'http://camera2.local:8080/mjpeg',
        'http://192.168.1.200:8080/stream',
        'http://pi.local:8080/stream',
      ];

      for (final url in urls) {
        notifier.setStreamUrl(url);
        expect(container.read(videoStateProvider).streamUrl, equals(url));
      }
    });
  });

  group('VideoStateNotifier State Transitions', () {
    late ProviderContainer container;
    late VideoStateNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(videoStateProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'should follow correct state transition: disconnected → connecting → connected',
      () async {
        // Initial state: disconnected
        var state = container.read(videoStateProvider);
        expect(state.isConnected, isFalse);
        expect(state.isConnecting, isFalse);

        // Start connection: connecting
        notifier.connect();
        state = container.read(videoStateProvider);
        expect(state.isConnected, isFalse);
        expect(state.isConnecting, isTrue);

        // Wait for connection: connected
        await Future.delayed(const Duration(seconds: 3));
        state = container.read(videoStateProvider);
        expect(state.isConnected, isTrue);
        expect(state.isConnecting, isFalse);
      },
    );

    test(
      'should follow correct state transition: connected → disconnected',
      () async {
        // First get to connected state
        notifier.connect();
        await Future.delayed(const Duration(seconds: 3));
        expect(container.read(videoStateProvider).isConnected, isTrue);

        // Then disconnect
        notifier.disconnect();
        final state = container.read(videoStateProvider);
        expect(state.isConnected, isFalse);
        expect(state.isConnecting, isFalse);
      },
    );

    test('should handle rapid connect/disconnect cycles', () async {
      for (int i = 0; i < 5; i++) {
        notifier.connect();
        expect(container.read(videoStateProvider).isConnecting, isTrue);

        notifier.disconnect();
        expect(container.read(videoStateProvider).isConnected, isFalse);
        expect(container.read(videoStateProvider).isConnecting, isFalse);
      }
    });
  });

  group('VideoStateNotifier Edge Cases', () {
    late ProviderContainer container;
    late VideoStateNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(videoStateProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('should handle special URL formats', () {
      const specialUrls = [
        'https://secure.camera.local:8443/stream',
        'http://camera.local/video.mjpeg',
        'rtsp://camera.local:554/stream1',
        'http://username:password@camera.local:8080/stream',
      ];

      for (final url in specialUrls) {
        notifier.setStreamUrl(url);
        expect(container.read(videoStateProvider).streamUrl, equals(url));
      }
    });

    test('should generate realistic latency values', () async {
      final latencies = <int>[];

      // Collect multiple latency values with small delays to ensure variety
      for (int i = 0; i < 20; i++) {
        notifier.refresh();
        latencies.add(container.read(videoStateProvider).latency);
        // Small delay to get different millisecond values
        await Future.delayed(const Duration(milliseconds: 5));
      }

      // Check latency distribution is within expected range
      expect(latencies.every((l) => l >= 100), isTrue);
      expect(latencies.every((l) => l <= 250), isTrue);

      // Should have some variation (at least 2 unique values due to time changes)
      final uniqueLatencies = latencies.toSet();
      expect(uniqueLatencies.length, greaterThanOrEqualTo(2));
    });

    test('should maintain state consistency during operations', () {
      // Test that unrelated state is preserved during operations
      const testUrl = 'http://test.local:8080/stream';
      notifier.setStreamUrl(testUrl);

      notifier.connect();
      expect(container.read(videoStateProvider).streamUrl, equals(testUrl));

      notifier.refresh();
      expect(container.read(videoStateProvider).streamUrl, equals(testUrl));
      expect(container.read(videoStateProvider).isConnecting, isTrue);

      notifier.disconnect();
      expect(container.read(videoStateProvider).streamUrl, equals(testUrl));
    });
  });

  group('VideoStateNotifier Provider Integration', () {
    test('should create new notifier instance from provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier1 = container.read(videoStateProvider.notifier);
      final notifier2 = container.read(videoStateProvider.notifier);

      // Should be the same instance within the same container
      expect(identical(notifier1, notifier2), isTrue);
    });

    test('should have independent state across different containers', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();
      addTearDown(() {
        container1.dispose();
        container2.dispose();
      });

      const url1 = 'http://camera1.local:8080/stream';
      const url2 = 'http://camera2.local:8080/stream';

      container1.read(videoStateProvider.notifier).setStreamUrl(url1);
      container2.read(videoStateProvider.notifier).setStreamUrl(url2);

      expect(container1.read(videoStateProvider).streamUrl, equals(url1));
      expect(container2.read(videoStateProvider).streamUrl, equals(url2));
    });
  });
}
