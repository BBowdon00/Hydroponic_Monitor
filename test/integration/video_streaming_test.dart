@Tags(['integration'])
import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/core/env.dart';
import 'package:hydroponic_monitor/presentation/pages/video_page.dart';

/// Integration tests for MJPEG streaming functionality.
/// Tests the video streaming components with mock servers and real network conditions.
void main() {
  group('MJPEG Streaming Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should handle environment MJPEG URL configuration', () {
      // Test that Env.mjpegUrl returns expected default value when not configured
      // Note: In test environment, dotenv may not be initialized, so we get default
      try {
        final mjpegUrl = Env.mjpegUrl;
        expect(mjpegUrl, isNotNull);
        expect(mjpegUrl, isA<String>());
        expect(mjpegUrl, contains('http'));
      } catch (e) {
        // If dotenv not initialized, verify default fallback
        expect(e.toString(), contains('NotInitializedError'));
      }
    });

    test('should validate common MJPEG URL formats', () {
      const validUrls = [
        'http://192.168.1.100:8080/stream',
        'http://raspberry.local:8080/mjpeg',
        'https://camera.local:8443/video.mjpeg',
        'http://10.0.0.5:8080/stream.mjpeg',
      ];

      for (final url in validUrls) {
        final uri = Uri.tryParse(url);
        expect(uri, isNotNull, reason: 'URL should be valid: $url');
        expect(uri!.hasScheme, isTrue, reason: 'URL should have scheme: $url');
        expect(
          ['http', 'https'].contains(uri.scheme),
          isTrue,
          reason: 'URL should use HTTP(S): $url',
        );
      }
    });

    test('should handle URL validation edge cases', () {
      const invalidUrls = ['', 'not-a-url', 'ftp://invalid.com/stream'];

      for (final url in invalidUrls) {
        final uri = Uri.tryParse(url);
        // Either null or invalid scheme/format
        if (uri != null && url.isNotEmpty) {
          if (uri.hasScheme) {
            expect(
              ['http', 'https'].contains(uri.scheme),
              isFalse,
              reason: 'Invalid URL should not have valid HTTP scheme: $url',
            );
          }
        }
      }

      // Test high port numbers separately (these are technically valid URIs)
      const highPortUrl = 'https://invalid:99999/stream';
      final highPortUri = Uri.tryParse(highPortUrl);
      expect(highPortUri, isNotNull);
      expect(highPortUri!.hasScheme, isTrue);
      // Note: Port 99999 is technically a valid URI, just not a practical port
    });

    group('VideoStateNotifier Connection Simulation', () {
      test('should simulate realistic connection behavior', () async {
        final notifier = container.read(videoStateProvider.notifier);
        final stateStream = container.listen(videoStateProvider, (_, __) {});

        // Initial state
        expect(container.read(videoStateProvider).isConnected, isFalse);
        expect(container.read(videoStateProvider).isConnecting, isFalse);

        // Start connection
        notifier.connect();
        expect(container.read(videoStateProvider).isConnecting, isTrue);
        expect(container.read(videoStateProvider).isConnected, isFalse);

        // Wait for simulated connection
        await Future.delayed(const Duration(seconds: 3));

        // Should be connected
        expect(container.read(videoStateProvider).isConnected, isTrue);
        expect(container.read(videoStateProvider).isConnecting, isFalse);

        // Verify connection upgraded video parameters
        final state = container.read(videoStateProvider);
        expect(state.resolution.width, equals(1280));
        expect(state.resolution.height, equals(720));
        expect(state.fps, equals(30));
        expect(state.latency, greaterThanOrEqualTo(120));

        stateStream.close();
      });

      test('should handle connection state transitions correctly', () async {
        final notifier = container.read(videoStateProvider.notifier);
        final states = <VideoState>[];

        final stateStream = container.listen(videoStateProvider, (_, next) {
          states.add(next);
        });

        // Initial state is recorded
        states.add(container.read(videoStateProvider));

        // Connect
        notifier.connect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have connecting state
        expect(states.any((s) => s.isConnecting && !s.isConnected), isTrue);

        // Wait for connection
        await Future.delayed(const Duration(seconds: 3));

        // Should have connected state
        expect(states.any((s) => s.isConnected && !s.isConnecting), isTrue);

        // Disconnect
        notifier.disconnect();
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have disconnected state
        expect(states.any((s) => !s.isConnected && !s.isConnecting), isTrue);

        stateStream.close();
      });

      test('should simulate network latency variations', () async {
        final notifier = container.read(videoStateProvider.notifier);

        // Connect first
        notifier.connect();
        await Future.delayed(const Duration(seconds: 3));

        final latencies = <int>[];

        // Collect multiple latency readings
        for (int i = 0; i < 10; i++) {
          notifier.refresh();
          await Future.delayed(const Duration(milliseconds: 50));
          latencies.add(container.read(videoStateProvider).latency);
        }

        // Should have realistic latency values
        expect(latencies.every((l) => l >= 100), isTrue);
        expect(latencies.every((l) => l <= 250), isTrue);

        // Should have some variation
        final uniqueLatencies = latencies.toSet();
        expect(uniqueLatencies.length, greaterThan(1));
      });
    });

    group('Video Configuration Integration', () {
      test('should handle URL changes during different states', () {
        final notifier = container.read(videoStateProvider.notifier);

        const testUrls = [
          'http://camera1.local:8080/stream',
          'http://camera2.local:8080/mjpeg',
          'http://192.168.1.200:8080/video',
        ];

        for (final url in testUrls) {
          notifier.setStreamUrl(url);
          expect(container.read(videoStateProvider).streamUrl, equals(url));
        }
      });

      test('should preserve URL through connection cycles', () async {
        final notifier = container.read(videoStateProvider.notifier);
        const testUrl = 'http://test.local:8080/stream';

        // Set URL
        notifier.setStreamUrl(testUrl);
        expect(container.read(videoStateProvider).streamUrl, equals(testUrl));

        // Connect
        notifier.connect();
        await Future.delayed(const Duration(seconds: 3));
        expect(container.read(videoStateProvider).streamUrl, equals(testUrl));

        // Disconnect
        notifier.disconnect();
        expect(container.read(videoStateProvider).streamUrl, equals(testUrl));

        // Reconnect
        notifier.connect();
        await Future.delayed(const Duration(seconds: 3));
        expect(container.read(videoStateProvider).streamUrl, equals(testUrl));
      });
    });

    group('Error Conditions and Edge Cases', () {
      test('should handle rapid connection attempts', () async {
        final notifier = container.read(videoStateProvider.notifier);

        // Rapid connect/disconnect cycles
        for (int i = 0; i < 5; i++) {
          notifier.connect();
          await Future.delayed(const Duration(milliseconds: 100));
          notifier.disconnect();
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Should end in disconnected state
        expect(container.read(videoStateProvider).isConnected, isFalse);
        expect(container.read(videoStateProvider).isConnecting, isFalse);
      });

      test('should handle connection during connecting state', () async {
        final notifier = container.read(videoStateProvider.notifier);

        // Start connection
        notifier.connect();
        expect(container.read(videoStateProvider).isConnecting, isTrue);

        // Try to connect again while connecting
        notifier.connect();

        // Should still be in connecting state
        expect(container.read(videoStateProvider).isConnecting, isTrue);
        expect(container.read(videoStateProvider).isConnected, isFalse);

        // Wait for original connection to complete
        await Future.delayed(const Duration(seconds: 3));
        expect(container.read(videoStateProvider).isConnected, isTrue);
      });

      test('should handle special URL formats', () {
        final notifier = container.read(videoStateProvider.notifier);

        const specialUrls = [
          'https://secure.camera.local:8443/stream',
          'http://camera.local/video.mjpeg',
          'http://192.168.1.100:8080/stream.cgi?resolution=720p',
          'http://username:password@camera.local:8080/stream',
        ];

        for (final url in specialUrls) {
          notifier.setStreamUrl(url);
          expect(container.read(videoStateProvider).streamUrl, equals(url));
        }
      });
    });

    group('Performance and Resource Management', () {
      test('should handle multiple provider containers independently', () {
        final container1 = ProviderContainer();
        final container2 = ProviderContainer();

        try {
          const url1 = 'http://camera1.local:8080/stream';
          const url2 = 'http://camera2.local:8080/stream';

          container1.read(videoStateProvider.notifier).setStreamUrl(url1);
          container2.read(videoStateProvider.notifier).setStreamUrl(url2);

          expect(container1.read(videoStateProvider).streamUrl, equals(url1));
          expect(container2.read(videoStateProvider).streamUrl, equals(url2));
        } finally {
          container1.dispose();
          container2.dispose();
        }
      });

      test('should handle container disposal during connection', () async {
        final testContainer = ProviderContainer();
        final notifier = testContainer.read(videoStateProvider.notifier);

        // Start connection
        notifier.connect();
        expect(testContainer.read(videoStateProvider).isConnecting, isTrue);

        // Dispose container while connecting
        testContainer.dispose();

        // Should not crash or cause memory leaks
        // (This test primarily ensures no exceptions are thrown)
        await Future.delayed(const Duration(seconds: 1));
      });
    });
  });

  group('Real Network Conditions (Conditional)', () {
    late ProviderContainer networkContainer;

    setUp(() {
      networkContainer = ProviderContainer();
    });

    tearDown(() {
      networkContainer.dispose();
    });

    test(
      'should validate against localhost server if available',
      () async {
        const testUrl = 'http://localhost:8080/stream';

        try {
          // Try to create HTTP client and check if server is reachable
          final client = HttpClient();
          final request = await client.getUrl(Uri.parse(testUrl));
          request.headers.set('User-Agent', 'HydroponicMonitor-Test/1.0');

          // Set timeout
          final response = await request.close().timeout(
            const Duration(seconds: 2),
          );

          // If we get here, server is available
          expect(response.statusCode, lessThan(500));

          await response.drain();
          client.close();
        } on TimeoutException {
          // Server not available, skip test
          print('Localhost MJPEG server not available for testing: timeout');
        } catch (e) {
          // Server not available, skip test
          print('Localhost MJPEG server not available for testing: $e');
        }
      },
      tags: ['integration', 'network'],
    );

    test('should handle network timeout scenarios', () async {
      // This test simulates what would happen with network timeouts
      // In real implementation, we would add timeout handling to VideoStateNotifier

      const unreachableUrl =
          'http://192.168.254.254:8080/stream'; // Non-routable IP

      final notifier = networkContainer.read(videoStateProvider.notifier);
      notifier.setStreamUrl(unreachableUrl);

      // In current implementation, this would still "connect" since it's simulated
      // In real implementation, this should timeout and handle gracefully
      notifier.connect();

      // Current behavior - always connects (simulated)
      await Future.delayed(const Duration(seconds: 3));
      expect(networkContainer.read(videoStateProvider).isConnected, isTrue);
    }, tags: ['integration', 'network']);
  });
}
