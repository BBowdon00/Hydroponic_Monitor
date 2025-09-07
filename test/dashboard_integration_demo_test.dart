import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/presentation/app.dart';
import 'package:hydroponic_monitor/presentation/pages/dashboard_page.dart';

void main() {
  group('Dashboard Real-time Integration Demo', () {
    testWidgets('Dashboard can be rendered without errors', (WidgetTester tester) async {
      // This test confirms that our changes don't break the app startup
      await tester.pumpWidget(const ProviderScope(child: HydroponicMonitorApp()));
      
      // Wait for the app to settle
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify that the dashboard is displayed
      expect(find.text('Dashboard'), findsWidgets);
      
      // Verify that sensor tiles are present
      expect(find.text('Water Level'), findsWidgets);
      expect(find.text('Temperature'), findsWidgets);
      expect(find.text('Humidity'), findsWidgets);
      
      // Verify initial sensor tile states (should show "Waiting..." or "No Data")
      expect(find.text('Waiting...'), findsWidgets);
    });

    testWidgets('Dashboard refresh button works', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: HydroponicMonitorApp()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find and tap the refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);
      
      await tester.tap(refreshButton);
      await tester.pump();
      
      // The tap should complete without errors
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('Dashboard connection status button works', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: HydroponicMonitorApp()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find the connection status button (WiFi icon)
      final connectionButton = find.byIcon(Icons.wifi_off);
      if (connectionButton.evaluate().isNotEmpty) {
        await tester.tap(connectionButton);
        await tester.pump();
        
        // Should show connection status dialog
        expect(find.text('Connection Status'), findsOneWidget);
        
        // Close the dialog
        await tester.tap(find.text('Close'));
        await tester.pump();
      }
      
      // The app should still be running
      expect(find.text('Dashboard'), findsWidgets);
    });
  });
}