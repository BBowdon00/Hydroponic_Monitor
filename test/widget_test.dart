// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'package:hydroponic_monitor/core/errors.dart';
import 'package:hydroponic_monitor/data/connection_recovery_service.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/data/mqtt/mqtt_service.dart';
import 'package:hydroponic_monitor/data/repos/sensor_repository.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/domain/entities/reconnect_result.dart';
import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/presentation/app.dart';
import 'package:hydroponic_monitor/presentation/providers/connection_status_provider.dart';
import 'package:hydroponic_monitor/presentation/providers/data_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/device_control_providers.dart';
import 'package:hydroponic_monitor/presentation/providers/manual_reconnect_provider.dart';

ProviderScope _buildTestApp() {
  final mqttService = _TestMqttService();
  final influxService = _TestInfluxDbService();
  final sensorRepository = SensorRepository(
    mqttService: mqttService,
    influxService: influxService,
  );

  return ProviderScope(
    overrides: [
      mqttServiceProvider.overrideWithValue(mqttService),
      influxServiceProvider.overrideWithValue(influxService),
      sensorRepositoryProvider.overrideWithValue(sensorRepository),
      sensorRepositoryInitProvider.overrideWith((ref) async {
        await sensorRepository.initialize();
        return sensorRepository;
      }),
      connectionStatusProvider.overrideWith(
        (ref) => Stream.value(
          ConnectionStatus(
            mqttConnected: true,
            influxConnected: true,
          ),
        ),
      ),
      manualReconnectProvider.overrideWith(
        (ref) => _TestManualReconnectNotifier(),
      ),
    ],
    child: const HydroponicMonitorApp(),
  );
}

void main() {
  setUpAll(() {
    DeviceControlsNotifier.useCommandTimeouts = false;
    DeviceControlsNotifier.enforceNodeOnlineForCommands = false;
  });

  tearDownAll(() {
    DeviceControlsNotifier.useCommandTimeouts = true;
    DeviceControlsNotifier.enforceNodeOnlineForCommands = true;
  });

  testWidgets('App starts and loads dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify that the app starts with the dashboard.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Water Level'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
  });

  testWidgets('Bottom navigation works', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap the devices tab
    await tester.tap(find.text('Devices'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify that we navigate to devices page
    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Water Pump'), findsOneWidget);
  });
}

class _TestMqttService extends MqttService {
  _TestMqttService()
      : _sensorController = StreamController<SensorData>.broadcast(),
        _deviceController = StreamController<Device>.broadcast(),
        _connectionController = StreamController<String>.broadcast(),
        super(
          host: 'localhost',
          port: 1883,
          clientId: 'test-client',
          autoReconnect: false,
        );

  final StreamController<SensorData> _sensorController;
  final StreamController<Device> _deviceController;
  final StreamController<String> _connectionController;

  @override
  Stream<SensorData> get sensorDataStream => _sensorController.stream;

  @override
  Stream<Device> get deviceStatusStream => _deviceController.stream;

  @override
  Stream<String> get connectionStream => _connectionController.stream;

  @override
  Future<Result<void>> connect() async {
    _connectionController.add('connected');
    return const Success(null);
  }

  @override
  Future<void> disconnect() async {
    _connectionController.add('disconnected');
  }

  @override
  Future<void> ensureInitialized({Duration timeout = const Duration(seconds: 5)}) async {
    _connectionController.add('connected');
  }

  @override
  bool get isConnected => true;

  @override
  MqttConnectionState? get connectionStatus => MqttConnectionState.connected;

  @override
  Future<Result<void>> publishDeviceCommand(
    String deviceId,
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    return const Success(null);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _sensorController.close();
    await _deviceController.close();
    await _connectionController.close();
  }
}

class _TestInfluxDbService extends InfluxDbService {
  _TestInfluxDbService()
      : _connectionController = StreamController<String>.broadcast(),
        super(
          url: 'http://localhost:8086',
          token: '',
          organization: 'test-org',
          bucket: 'test-bucket',
        );

  final StreamController<String> _connectionController;

  @override
  Stream<String> get connectionStream => _connectionController.stream;

  @override
  Future<Result<void>> initialize() async {
    _connectionController.add('connected');
    return const Success(null);
  }

  @override
  Future<Result<List<SensorData>>> queryLatestSensorData() async {
    return const Success(<SensorData>[]);
  }

  @override
  Future<void> close() async {
    _connectionController.add('disconnected');
    await _connectionController.close();
  }
}

class _TestManualReconnectNotifier extends ManualReconnectNotifier {
  _TestManualReconnectNotifier()
      : super(
          ConnectionRecoveryService(
            mqttService: _TestMqttService(),
            influxService: _TestInfluxDbService(),
          ),
        );

  @override
  Future<ReconnectResult> attemptReconnect({bool force = false}) async {
    final result = ReconnectResult(
      mqttOk: true,
      influxOk: true,
      elapsed: const Duration(milliseconds: 10),
    );

    state = state.copyWith(
      inProgress: false,
      lastAttempt: DateTime.now(),
      lastResult: result,
    );

    return result;
  }
}
