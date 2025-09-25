// Clean test suite after refactor. Legacy duplicated tests removed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/presentation/pages/video_page.dart';
import 'package:hydroponic_monitor/presentation/widgets/status_badge.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';

void main() {
  Future<void> _connect(WidgetTester tester) async {
    await tester.tap(find.text('Connect'));
    await tester.pump();
    // Allow for the possibility that 'Connecting...' appears in more than one Text widget (e.g., button label + heading).
    expect(find.text('Connecting...'), findsAtLeastNWidgets(1));
    // Allow simulated stream to transition to playing state.
    await tester.pump(const Duration(seconds: 3));
  }

  group('VideoPage: basic lifecycle', () {
    testWidgets('idle/disconnected initial state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: VideoPage())),
      );
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
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: VideoPage())),
      );
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
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: VideoPage())),
      );
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
        const ProviderScope(child: MaterialApp(home: VideoPage())),
      );
      await tester.pump();
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(find.text('Connecting...'), findsAtLeastNWidgets(1));
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('video_connect_button')),
      );
      expect(button.onPressed, isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Disconnect'), findsOneWidget);
    });
  });

  group('VideoPage: metrics & layout', () {
    testWidgets('shows metrics in playing state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: VideoPage())),
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
        const ProviderScope(child: MaterialApp(home: VideoPage())),
      );
      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byKey(const Key('video_connect_button')), findsOneWidget);
    });

    testWidgets('URL field focusable', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: VideoPage())),
      );
      await tester.pump();
      final urlField = find.byType(TextFormField);
      await tester.tap(urlField);
      await tester.pump();
      expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);
    });
  });
}
