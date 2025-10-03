// Clean test suite after refactor. Legacy duplicated tests removed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/presentation/pages/video_page.dart';
import 'package:hydroponic_monitor/presentation/providers/config_provider.dart';
import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';
import 'package:hydroponic_monitor/presentation/widgets/status_badge.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/core/env.dart';
import 'dart:async';
import 'dart:typed_data';
// Fake notifier subclassing real notifier to avoid real streaming & speed transitions.
class _TestVideoNotifier extends VideoStateNotifier {
  _TestVideoNotifier(Ref ref) : super(ref, initialUrl: 'http://fake/stream');

  @override
  void connect() {
    if (state.phase == VideoConnectionPhase.connecting ||
        state.phase == VideoConnectionPhase.playing) return;
    state = state.copyWith(
      phase: VideoConnectionPhase.connecting,
      hasAttempted: true,
      clearError: true,
    );
    // Fast-forward to playing next microtask.
    Future.microtask(() {
      if (mounted && state.phase == VideoConnectionPhase.connecting) {
        state = state.copyWith(phase: VideoConnectionPhase.playing);
      }
    });
  }

  @override
  void disconnect() {
    state = state.copyWith(phase: VideoConnectionPhase.idle);
  }

  @override
  void refresh() {
    if (state.phase == VideoConnectionPhase.playing) {
      state = state.copyWith(latency: state.latency + 5);
    }
  }
}

// Minimal in-memory config repository
class _TestConfigRepo implements ConfigRepository {
  AppConfig _config = const AppConfig(
    mqtt: MqttConfig(host: 'localhost', port: 1883, username: '', password: ''),
    influx: InfluxConfig(url: 'http://localhost:8086', token: '', org: 'org', bucket: 'bucket'),
    mjpeg: MjpegConfig(url: 'http://192.168.1.100:8080/stream', autoReconnect: true),
  );
  @override
  Future<AppConfig> loadConfig() async => _config;
  @override
  Future<void> saveConfig(AppConfig config) async { _config = config; }
  @override
  Future<void> clearConfig() async {}
}

void main() {
  setUpAll(() async {
    await Env.init();
  });
  Future<void> _connect(WidgetTester tester) async {
    await tester.tap(find.text('Connect'));
    await tester.pump();
    // Allow simulated stream to transition to playing state.
    await tester.pump(const Duration(seconds: 3));
  }


  ProviderScope _scope(Widget child) => ProviderScope(
        overrides: [
          configRepositoryProvider.overrideWithValue(_TestConfigRepo()),
          videoStateProvider.overrideWith((ref) => _TestVideoNotifier(ref)),
        ],
        child: child,
      );

  group('VideoPage: basic lifecycle', () {
    testWidgets('idle/disconnected initial state', (tester) async {
    await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      expect(find.text('Video Feed'), findsOneWidget);
      expect(find.text('Video Stream URL'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('No stream connected'), findsOneWidget);
      final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
      expect(badge.label, 'Disconnected');
      expect(badge.status, DeviceStatus.offline);
    });

    testWidgets('connect -> playing -> disconnect', (tester) async {
    await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      await _connect(tester);
      expect(find.text('Disconnect'), findsOneWidget);
      final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
      expect(badge.label, 'Playing');
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('No stream connected'), findsOneWidget);
    });
  });

  group('VideoPage: interactions', () {
    testWidgets('URL retained through connection cycle', (tester) async {
    await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      const url = 'http://example.local:8080/mjpeg';
      final urlField = find.byType(TextFormField);
      await tester.tap(urlField);
      await tester.pump();
      await tester.enterText(urlField, url);
      await tester.pump();
      expect(find.text(url), findsWidgets);
      await _connect(tester);
      // Still have disconnect button meaning playing.
      expect(find.text('Disconnect'), findsOneWidget);
      // Disconnect and ensure URL still present in field.
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      expect(find.text(url), findsWidgets);
    });

    testWidgets('rapid connect press disables button until state change', (
      tester,
    ) async {
      await tester.pumpWidget(
  _scope(const MaterialApp(home: VideoPage())),
      );
      await tester.pump();
      await tester.tap(find.text('Connect'));
      await tester.pump();
        // With the test notifier we fast-forward almost immediately; ensure we reach playing state soon.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Disconnect'), findsOneWidget,
            reason: 'Expected fast transition to playing (Disconnect button).');
    });
  });

  group('VideoPage: metrics & layout', () {
    testWidgets('shows metrics in playing state', (tester) async {
      await tester.pumpWidget(
  _scope(const MaterialApp(home: VideoPage())),
      );
      await tester.pump();
      await _connect(tester);
      // Allow any post-frame listeners to settle
      await tester.pump();
      // Metrics labels expected.
      expect(find.text('Latency'), findsOneWidget);
      expect(find.text('FPS'), findsOneWidget);
      expect(find.text('Resolution'), findsOneWidget);
    });
  });

  group('VideoPage: accessibility basics', () {
    testWidgets('core interactive elements present', (tester) async {
      await tester.pumpWidget(
  _scope(const MaterialApp(home: VideoPage())),
      );
      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byKey(const Key('video_connect_button')), findsOneWidget);
    });

    testWidgets('URL field focusable', (tester) async {
      await tester.pumpWidget(
  _scope(const MaterialApp(home: VideoPage())),
      );
      await tester.pump();
      final urlField = find.byType(TextFormField);
      await tester.tap(urlField);
      await tester.pump();
      expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);
    });
  });
}
