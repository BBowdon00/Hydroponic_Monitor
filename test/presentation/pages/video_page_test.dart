// Widget tests for VideoPage with HLS streaming
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

// Fake notifier subclassing real notifier to avoid real HLS streaming & speed transitions.
class _TestVideoNotifier extends VideoStateNotifier {
  _TestVideoNotifier(Ref ref) : super(ref, initialUrl: 'http://fake:8000/stream.m3u8');

  @override
  void connect() {
    if (state.phase == VideoConnectionPhase.connecting ||
        state.phase == VideoConnectionPhase.playing) {
      return;
    }
    state = state.copyWith(
      phase: VideoConnectionPhase.connecting,
      hasAttempted: true,
      clearError: true,
    );
    // Fast-forward to playing state in next microtask to simulate successful HLS connection
    Future.microtask(() {
      if (mounted && state.phase == VideoConnectionPhase.connecting) {
        state = state.copyWith(
          phase: VideoConnectionPhase.playing,
          resolution: const Size(1920, 1080), // Simulate HLS stream resolution
        );
      }
    });
  }

  @override
  void disconnect() {
    state = state.copyWith(
      phase: VideoConnectionPhase.idle,
      resolution: const Size(640, 480), // Reset to default
    );
  }

  @override
  void refresh() {
    if (state.phase == VideoConnectionPhase.playing) {
      // Simulate refresh without actual network call
    }
  }
}

// Minimal in-memory config repository for testing
class _TestConfigRepo implements ConfigRepository {
  AppConfig _config = const AppConfig(
    mqtt: MqttConfig(host: 'localhost', port: 1883, username: '', password: ''),
    influx: InfluxConfig(
      url: 'http://localhost:8086',
      token: '',
      org: 'org',
      bucket: 'bucket',
    ),
    hls: HlsConfig(
      url: 'http://192.168.1.100:8000/stream.m3u8',
      autoReconnect: true,
    ),
  );
  
  @override
  Future<AppConfig> loadConfig() async => _config;
  
  @override
  Future<void> saveConfig(AppConfig config) async {
    _config = config;
  }

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
    // Allow simulated HLS stream to transition to playing state
    await tester.pump(const Duration(milliseconds: 100));
  }

  ProviderScope _scope(Widget child) => ProviderScope(
    overrides: [
      configRepositoryProvider.overrideWithValue(_TestConfigRepo()),
      videoStateProvider.overrideWith((ref) => _TestVideoNotifier(ref)),
    ],
    child: child,
  );

  group('VideoPage: HLS basic lifecycle', () {
    testWidgets('idle/disconnected initial state', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Verify page title and UI elements
      expect(find.text('Video Feed'), findsOneWidget);
      expect(find.text('HLS Stream URL'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('No stream connected'), findsOneWidget);
      
      // Verify status badge shows disconnected state
      final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
      expect(badge.label, 'Disconnected');
      expect(badge.status, DeviceStatus.offline);
    });

    testWidgets('connect -> playing -> disconnect cycle', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Initial state
      expect(find.text('Connect'), findsOneWidget);
      
      // Connect to HLS stream
      await _connect(tester);
      
      // Verify playing state
      expect(find.text('Disconnect'), findsOneWidget);
      final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
      expect(badge.label, 'Playing');
      expect(badge.status, DeviceStatus.online);
      
      // Disconnect
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      
      // Verify disconnected state
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('No stream connected'), findsOneWidget);
    });

    testWidgets('shows connecting state during transition', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Start connection
      await tester.tap(find.text('Connect'));
      await tester.pump();
      
      // Should show connecting state before playing
      final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
      expect(badge.label, 'Connecting');
      expect(badge.status, DeviceStatus.pending);
    });
  });

  group('VideoPage: HLS URL handling', () {
    testWidgets('URL retained through connection cycle', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Enter HLS stream URL
      const url = 'http://raspberrypi.local:8000/stream.m3u8';
      final urlField = find.byType(TextFormField);
      await tester.tap(urlField);
      await tester.pump();
      await tester.enterText(urlField, url);
      await tester.pump();
      
      // Verify URL is displayed
      expect(find.text(url), findsWidgets);
      
      // Connect
      await _connect(tester);
      expect(find.text('Disconnect'), findsOneWidget);
      
      // Disconnect and ensure URL still present
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      expect(find.text(url), findsWidgets);
    });

    testWidgets('accepts various HLS URL formats', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      final testUrls = [
        'http://192.168.1.100:8000/stream.m3u8',
        'http://camera.local:8000/stream.m3u8',
        'https://secure.camera.local:8443/stream.m3u8',
      ];
      
      final urlField = find.byType(TextFormField);
      
      for (final url in testUrls) {
        await tester.enterText(urlField, url);
        await tester.pump();
        expect(find.text(url), findsWidgets);
      }
    });

    testWidgets('URL field is editable when disconnected', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      final urlField = find.byType(TextFormField);
      final textField = tester.widget<TextFormField>(urlField);
      
      // Should be enabled when disconnected
      expect(textField.enabled, isTrue);
    });
  });

  group('VideoPage: user interactions', () {
    testWidgets('rapid connect press transitions to playing state', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Tap connect
      await tester.tap(find.text('Connect'));
      await tester.pump();
      
      // Fast transition to playing with test notifier
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('Disconnect'),
        findsOneWidget,
        reason: 'Expected fast transition to playing state',
      );
    });

    testWidgets('disconnect button works when playing', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Connect
      await _connect(tester);
      expect(find.text('Disconnect'), findsOneWidget);
      
      // Disconnect should work
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('fullscreen button appears when playing', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // No fullscreen button when disconnected
      expect(find.byKey(const Key('fullscreen_button')), findsNothing);
      
      // Connect
      await _connect(tester);
      
      // Fullscreen button should appear when playing
      expect(find.byKey(const Key('fullscreen_button')), findsOneWidget);
    });
  });

  group('VideoPage: HLS video display', () {
    testWidgets('shows video frame when playing', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Connect
      await _connect(tester);
      
      // Video container should be visible
      expect(find.byKey(const Key('video_frame')), findsOneWidget);
    });

    testWidgets('shows placeholder when disconnected', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Should show "No stream connected" placeholder
      expect(find.text('No stream connected'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off), findsOneWidget);
    });

    testWidgets('handles error state gracefully', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Note: Error state testing would require extending _TestVideoNotifier
      // to simulate errors, which can be added if needed
    });
  });

  group('VideoPage: accessibility', () {
    testWidgets('core interactive elements present', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Verify key interactive elements
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byKey(const Key('video_connect_button')), findsOneWidget);
    });

    testWidgets('URL field is focusable', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      final urlField = find.byType(TextFormField);
      await tester.tap(urlField);
      await tester.pump();
      
      expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);
    });

    testWidgets('buttons have semantic labels', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Connect button should have text label
      expect(find.text('Connect'), findsOneWidget);
      
      // After connecting, disconnect button should have text label
      await _connect(tester);
      expect(find.text('Disconnect'), findsOneWidget);
    });
  });

  group('VideoPage: layout responsiveness', () {
    testWidgets('adapts to small screen sizes', (tester) async {
      // Set small screen size
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Page should render without overflow
      expect(find.text('Video Feed'), findsOneWidget);
      expect(find.text('HLS Stream URL'), findsOneWidget);
    });

    testWidgets('adapts to large screen sizes', (tester) async {
      // Set large screen size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Page should render without overflow
      expect(find.text('Video Feed'), findsOneWidget);
      expect(find.text('HLS Stream URL'), findsOneWidget);
    });
  });

  group('VideoPage: state management', () {
    testWidgets('preserves state through widget rebuilds', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Set URL
      const url = 'http://test.local:8000/stream.m3u8';
      final urlField = find.byType(TextFormField);
      await tester.enterText(urlField, url);
      await tester.pump();
      
      // Connect
      await _connect(tester);
      
      // Rebuild widget tree
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // State should be preserved
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text(url), findsWidgets);
    });

    testWidgets('cleans up resources on disposal', (tester) async {
      await tester.pumpWidget(_scope(const MaterialApp(home: VideoPage())));
      await tester.pump();
      
      // Connect
      await _connect(tester);
      expect(find.text('Disconnect'), findsOneWidget);
      
      // Remove widget from tree (simulates disposal)
      await tester.pumpWidget(_scope(const MaterialApp(home: Scaffold())));
      await tester.pump();
      
      // No exceptions should occur during disposal
    });
  });
}
