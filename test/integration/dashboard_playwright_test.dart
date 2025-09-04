import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hydroponic_monitor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Playwright Integration Tests', () {
    testWidgets('app launches successfully and shows dashboard', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify app launches without crashing
      expect(find.byType(app.HydroponicMonitorApp), findsOneWidget);
      
      // Should show either loading state or dashboard content
      // The app should not crash with NotInitializedError
    });

    testWidgets('dashboard handles initialization gracefully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // Check that the app handles initialization errors gracefully
      // Either shows retry button or dashboard content
      final retryButton = find.text('Retry');
      final dashboardContent = find.text('Sensor Status');
      
      expect(
        retryButton.evaluate().isNotEmpty || dashboardContent.evaluate().isNotEmpty,
        true,
        reason: 'App should show either retry option or dashboard content',
      );
    });
  });
}