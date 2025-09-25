import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/presentation/pages/devices_page.dart';
import 'package:hydroponic_monitor/presentation/providers/device_control_providers.dart';
import 'package:hydroponic_monitor/presentation/widgets/status_badge.dart';

void main() {
  group('DevicesPage Widget Tests', () {
    testWidgets('displays app bar and emergency stop section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DevicesPage(),
          ),
        ),
      );

      // Wait for the UI to settle
      await tester.pumpAndSettle();

      // Verify app bar
      expect(find.text('Devices'), findsOneWidget);
      expect(find.byType(StatusBadge), findsWidgets);

      // Verify emergency stop section always exists
      expect(find.text('Emergency Stop'), findsOneWidget);
      expect(find.text('EMERGENCY STOP'), findsOneWidget);
      expect(find.text('Immediately stops all devices'), findsOneWidget);
    });

    testWidgets('emergency stop button shows dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DevicesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap emergency stop button
      await tester.tap(find.text('EMERGENCY STOP'));
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('This will immediately stop all devices. Are you sure you want to continue?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('STOP ALL'), findsOneWidget);

      // Test cancel button closes dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('This will immediately stop all devices. Are you sure you want to continue?'), findsNothing);
    });

    testWidgets('page layout includes cards and sections', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DevicesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify basic structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Card), findsWidgets);

      // Verify emergency section exists
      expect(find.byIcon(Icons.emergency), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('displays system status badge in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DevicesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify system status badge exists
      final systemStatusBadges = find.byType(StatusBadge);
      expect(systemStatusBadges, findsWidgets);
      
      // Should have at least the system status badge
      expect(systemStatusBadges, findsAtLeastNWidgets(1));
    });

    testWidgets('page is scrollable with ListView', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: DevicesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify ListView for scrolling
      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);

      // Verify padding is applied
      expect(find.byType(Padding), findsWidgets);
    });
  });
}