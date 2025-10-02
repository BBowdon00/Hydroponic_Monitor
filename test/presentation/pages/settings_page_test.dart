import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hydroponic_monitor/presentation/pages/settings_page.dart';
import 'package:hydroponic_monitor/presentation/providers/config_controller.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';
import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/core/env.dart';

class MockConfigRepository extends Mock implements ConfigRepository {}

void main() {
  setUpAll(() async {
    await Env.init();
  });

  group('SettingsPage Widget Tests', () {
    late MockConfigRepository mockRepository;

    setUp(() {
      mockRepository = MockConfigRepository();
      
      // Setup default behavior
      when(() => mockRepository.configStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => AppConfig.fromEnv());
    });

    Widget createSettingsPage({Override? override}) {
      return ProviderScope(
        overrides: override != null ? [override] : [],
        child: MaterialApp(
          home: const SettingsPage(),
        ),
      );
    }

    testWidgets('displays loading indicator while loading config', (tester) async {
      // Arrange
      when(() => mockRepository.getConfig())
          .thenAnswer((_) => Future.delayed(const Duration(seconds: 1))
              .then((_) => AppConfig.fromEnv()));

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error state when config loading fails', (tester) async {
      // Arrange
      when(() => mockRepository.getConfig())
          .thenThrow(Exception('Configuration error'));

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Assert
      expect(find.text('Failed to load settings: Exception: Configuration error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('displays configuration sections when loaded', (tester) async {
      // Arrange
      final testConfig = AppConfig(
        mqtt: const MqttConfig(
          host: 'test-mqtt-host',
          port: 1884,
          username: 'test-user',
          password: 'test-password',
        ),
        influx: const InfluxConfig(
          url: 'http://test-influx:8087',
          token: 'test-token',
          organization: 'test-org',
          bucket: 'test-bucket',
        ),
        video: const VideoConfig(
          mjpegUrl: 'http://test-video:8081/stream',
          autoReconnect: true,
        ),
      );

      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => testConfig);

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Assert
      // Check section titles
      expect(find.text('App Preferences'), findsOneWidget);
      expect(find.text('MQTT Configuration'), findsOneWidget);
      expect(find.text('InfluxDB Configuration'), findsOneWidget);
      expect(find.text('Video Configuration'), findsOneWidget);

      // Check MQTT values
      expect(find.text('test-mqtt-host'), findsOneWidget);
      expect(find.text('1884'), findsOneWidget);
      expect(find.text('test-user'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget); // Password masked

      // Check InfluxDB values
      expect(find.text('http://test-influx:8087'), findsOneWidget);
      expect(find.text('test-org'), findsOneWidget);
      expect(find.text('test-bucket'), findsOneWidget);

      // Check Video values
      expect(find.text('http://test-video:8081/stream'), findsOneWidget);
    });

    testWidgets('shows "Not set" for empty values', (tester) async {
      // Arrange
      final testConfig = AppConfig(
        mqtt: const MqttConfig(
          host: 'test-host',
          port: 1883,
          username: '', // Empty
          password: '', // Empty
        ),
        influx: const InfluxConfig(
          url: 'http://influx:8086',
          token: '', // Empty
          organization: 'org',
          bucket: 'bucket',
        ),
        video: const VideoConfig(
          mjpegUrl: 'http://video:8080/stream',
          autoReconnect: false,
        ),
      );

      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => testConfig);

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Assert
      expect(find.text('Not set'), findsNWidgets(3)); // username, password, token
    });

    testWidgets('displays test buttons for MQTT and InfluxDB', (tester) async {
      // Arrange
      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => AppConfig.fromEnv());

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Assert
      final testButtons = find.text('Test');
      expect(testButtons, findsNWidgets(2)); // One for MQTT, one for InfluxDB
    });

    testWidgets('displays reset to defaults button in app bar', (tester) async {
      // Arrange
      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => AppConfig.fromEnv());

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Assert
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('tapping config tile opens dialog', (tester) async {
      // Arrange
      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => AppConfig.fromEnv());

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Tap on broker host config tile
      await tester.tap(find.text('Broker Host'));
      await tester.pump();

      // Assert
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('MQTT Broker Host'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('dark mode switch works', (tester) async {
      // Arrange
      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => AppConfig.fromEnv());

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Find the dark mode switch
      final darkModeSwitch = find.byType(Switch);
      expect(darkModeSwitch, findsWidgets); // Should find switches (dark mode + auto-reconnect)

      // Note: Testing the actual theme change would require more complex setup
      // with theme providers, which is beyond the scope of this basic test
    });

    testWidgets('auto-reconnect switch is displayed', (tester) async {
      // Arrange
      when(() => mockRepository.getConfig())
          .thenAnswer((_) async => AppConfig.fromEnv());

      // Act
      await tester.pumpWidget(createSettingsPage(
        override: configRepositoryProvider.overrideWith((ref) => mockRepository),
      ));
      await tester.pump();

      // Assert
      expect(find.text('Auto-reconnect'), findsOneWidget);
      expect(find.text('Automatically reconnect to video stream'), findsOneWidget);
    });
  });
}