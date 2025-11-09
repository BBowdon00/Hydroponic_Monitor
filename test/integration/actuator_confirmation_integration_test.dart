import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/presentation/pages/devices_page.dart';
import 'package:hydroponic_monitor/presentation/providers/device_control_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/presentation/widgets/device_card.dart';
import '../mocks/mock_device_repository.dart';
import '../test_utils.dart';
import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/presentation/providers/config_provider.dart';
import 'package:hydroponic_monitor/data/repos/config_repository.dart';
import 'package:hydroponic_monitor/domain/entities/app_config.dart';

class _InMemoryConfigRepository implements ConfigRepository {
  AppConfig _config = const AppConfig(
    mqtt: MqttConfig(host: 'localhost', port: 1883, username: '', password: ''),
    influx: InfluxConfig(
      url: 'http://localhost:8086',
      token: '',
      org: 'org',
      bucket: 'bucket',
    ),
    hls: HlsConfig(url: 'http://localhost:8080/stream', autoReconnect: true),
  );
  @override
  Future<AppConfig> loadConfig() async => _config;
  @override
  Future<void> saveConfig(AppConfig config) async {
    _config = config;
  }

  @override
  Future<void> clearConfig() async {
    _config = const AppConfig(
      mqtt: MqttConfig(
        host: 'localhost',
        port: 1883,
        username: '',
        password: '',
      ),
      influx: InfluxConfig(
        url: 'http://localhost:8086',
        token: '',
        org: 'org',
        bucket: 'bucket',
      ),
      hls: HlsConfig(url: 'http://localhost:8080/stream', autoReconnect: true),
    );
  }
}

void main() {
  group('Actuator confirmation integration', () {
    late MockDeviceRepository mockRepo;

    setUp(() {
      // Disable timeouts and node-online enforcement for deterministic testing
      DeviceControlsNotifier.useCommandTimeouts = false;
      DeviceControlsNotifier.enforceNodeOnlineForCommands = false;
      mockRepo = MockDeviceRepository();
    });

    testWidgets(
      'Turning on pump -> receive MQTT confirmation -> UI shows Online and switch ON',
      (tester) async {
        // Build app with Provider overrides to inject our mock repository
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceRepositoryProvider.overrideWithValue(mockRepo),
              configRepositoryProvider.overrideWithValue(
                _InMemoryConfigRepository(),
              ),
              sensorRepositoryProvider.overrideWith((ref) {
                final mqtt = ref.read(mqttServiceProvider);
                final influx = ref.read(influxServiceProvider);
                return SensorRepository(
                  mqttService: mqtt,
                  influxService: influx,
                  strictInit: true,
                );
              }),
            ],
            child: const MaterialApp(home: DevicesPage()),
          ),
        );

        // Allow initial build
        await tester.pumpAndSettle();

        // Sanity: Water Pump card exists (rpi_pump_1)
        expect(find.text('Water Pump'), findsOneWidget);

        // Trigger a toggle ON command via the provider (simulating user intent)
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DevicesPage)),
        );
        final controls = container.read(deviceControlsProvider.notifier);
        await controls.toggleDevice('rpi_pump_1', true);

        // UI should reflect pending state initially
        await tester.pump();
        expect(find.text('Updating...'), findsWidgets);

        // Simulate receiving an MQTT actuator confirmation in the same format as systemPatterns.md
        final confirmationPayload = TestMqttPayloads.actuatorPayload(
          deviceType: 'pump',
          deviceID: '1',
          location: 'tent',
          running: true,
          description: 'Water Pump 1',
        );

        // Convert payload to Device entity (mimicking repository parsing logic)
        final node = 'rpi';
        final typeStr = confirmationPayload['deviceType'] as String;
        final deviceType = DeviceType.values.firstWhere(
          (t) => t.name == typeStr,
        );
        final device = Device(
          id: '${node}_${typeStr}_${confirmationPayload['deviceID']}',
          name: (confirmationPayload['description'] as String?) ?? 'Device',
          type: deviceType,
          status: (confirmationPayload['running'] as bool)
              ? DeviceStatus.online
              : DeviceStatus.offline,
          isEnabled: confirmationPayload['running'] as bool,
          location: confirmationPayload['location'] as String?,
        );

        mockRepo.emitDeviceStatus(device);

        // Pump to let provider process the stream and rebuild UI
        await tester.pump();

        // The specific DeviceCard should now show Online and a switch ON
        final pumpCard = find.widgetWithText(DeviceCard, 'Water Pump');
        expect(pumpCard, findsOneWidget);

        // No longer pending text within the card
        expect(
          find.descendant(of: pumpCard, matching: find.text('Updating...')),
          findsNothing,
        );

        // Switch reflects ON state
        final switchFinder = find.descendant(
          of: pumpCard,
          matching: find.byType(Switch),
        );
        expect(switchFinder, findsOneWidget);
        final sw = tester.widget<Switch>(switchFinder);
        expect(sw.value, isTrue);

        // Status label shows Online within the card
        expect(
          find.descendant(of: pumpCard, matching: find.text('Online')),
          findsWidgets,
        );
      },
    );
  });
}
