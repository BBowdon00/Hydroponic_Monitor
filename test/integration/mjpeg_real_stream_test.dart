@Tags(['integration'])
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/core/env.dart';
import 'package:hydroponic_monitor/presentation/pages/video_page.dart';

import '../test_utils/fake_mjpeg_server.dart';

void main() {
  group('Real MJPEG Stream Integration (feature-flagged)', () {
    test(
      'streams frames and updates state',
      () async {
        if (!Env.enableRealMjpeg) {
          print('Skipping real stream test: feature flag disabled');
          return;
        }
        final server = await FakeMjpegServer.start([
          FakeMjpegFrameSpec(
            buildStubJpeg(1),
            delay: const Duration(milliseconds: 50),
          ),
          FakeMjpegFrameSpec(
            buildStubJpeg(2),
            delay: const Duration(milliseconds: 50),
          ),
          FakeMjpegFrameSpec(
            buildStubJpeg(3),
            delay: const Duration(milliseconds: 50),
          ),
        ]);
        addTearDown(() => server.stop());

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(videoStateProvider.notifier);
        notifier.setStreamUrl(server.uri.toString());
        notifier.connect();

        await Future.delayed(const Duration(seconds: 1));
        final state = container.read(videoStateProvider);
        expect(state.isConnected, isTrue);
        expect(state.framesReceived, greaterThanOrEqualTo(2));
        expect(state.lastFrame, isNotNull);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test('handles invalid server boundary', () async {
      if (!Env.enableRealMjpeg) {
        return; // skip when flag disabled
      }
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        req.response.statusCode = 200;
        req.response.headers.set(
          'Content-Type',
          'multipart/x-mixed-replace',
        ); // missing boundary
        await req.response.close();
      });
      addTearDown(() => server.close());

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(videoStateProvider.notifier);
      notifier.setStreamUrl('http://localhost:${server.port}/stream');
      notifier.connect();
      await Future.delayed(const Duration(milliseconds: 300));
      final state = container.read(videoStateProvider);
      expect(state.errorMessage, isNotNull);
      expect(state.isConnected, isFalse);
    });
  });
}
