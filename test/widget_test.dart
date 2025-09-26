// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/presentation/app.dart';

void main() {
  testWidgets('App starts and loads sensor page', (WidgetTester tester) async {
    // Build our app and trigger a frame, then wait for async init to complete.
    await tester.pumpWidget(const ProviderScope(child: HydroponicMonitorApp()));
    // Avoid pumpAndSettle which can hang on ongoing animations; do short pumps
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify that the app starts with the sensor page.
    expect(find.text('Sensor'), findsWidgets);
    expect(find.text('Water Level'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
  });

  testWidgets('Bottom navigation works', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HydroponicMonitorApp()));
    // Avoid pumpAndSettle which can hang on ongoing animations; do short pumps
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap the devices tab
    await tester.tap(find.text('Devices'));
    // Advance the frame and allow brief async work without waiting indefinitely
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify that we navigate to devices page
    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Water Pump'), findsOneWidget);
  });
}
