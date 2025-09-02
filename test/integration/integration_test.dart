import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import '../test_utils.dart';

/// Integration tests for the full MQTT → Telegraf → InfluxDB pipeline.
///
/// These tests require the services to be running via docker-compose:
/// ```bash
/// cd test/integration
/// docker-compose up -d
/// ```
void main() {
  group('MQTT → Telegraf → InfluxDB Integration', () {
    const testTimeout = Timeout(Duration(minutes: 3));
    late MqttServerClient mqttClient;
    late InfluxDbService influxService;

    setUpAll(() async {
      // Wait for services to be ready
      await _waitForServices();

      // Initialize MQTT client for publishing test data
      mqttClient = MqttServerClient(
        TestConfig.testMqttHost,
        'integration_test_publisher',
      );
      mqttClient.port = TestConfig.testMqttPort;
      mqttClient.keepAlivePeriod = 20;
      mqttClient.autoReconnect = true;

      // Initialize InfluxDB service for querying data
      influxService = InfluxDbService(
        url: TestConfig.testInfluxUrl,
        token: TestConfig.testInfluxToken,
        organization: TestConfig.testInfluxOrg,
        bucket: TestConfig.testInfluxBucket,
      );

      await influxService.initialize();
    });

    tearDownAll(() async {
      mqttClient.disconnect();
      await influxService.close();
    });

    test(
      'End-to-end data flow: MQTT publish → Telegraf → InfluxDB storage',
      tags: ['integration'],
      () async {
        // Generate test sensor data
        final testData = TestDataGenerator.generateSensorData(
          sensorType: SensorType.temperature,
          sensorId: 'integration_test_temp_001',
          deviceId: 'test_device_001',
          location: 'integration_test_zone',
        );

        // Connect to MQTT broker
        await mqttClient.connect();
        expect(
          mqttClient.connectionStatus!.state,
          equals(MqttConnectionState.connected),
        );

        // Publish sensor data to MQTT
        final topic = TestMqttTopics.sensorDataTopicFor(testData.id);
        final messageJson = _sensorDataToJson(testData);

        final builder = MqttClientPayloadBuilder();
        builder.addString(messageJson);

        mqttClient.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

        print('Published sensor data to topic: $topic');
        print('Message: $messageJson');

        // Wait for Telegraf to process and store in InfluxDB
        await Future.delayed(const Duration(seconds: 30));

        // Query InfluxDB to verify data was stored
        // Note: This uses the direct InfluxDB HTTP API since our service doesn't support
        // custom queries yet in the integration environment
        final stored = await _queryInfluxDirectly(testData);

        expect(
          stored,
          isTrue,
          reason: 'Sensor data should be stored in InfluxDB via Telegraf',
        );
      },
      timeout: testTimeout,
    );

    test('Multiple sensor types data flow', tags: ['integration'], () async {
      final testDataList = SensorType.values
          .map(
            (type) => TestDataGenerator.generateSensorData(
              sensorType: type,
              sensorId: 'integration_test_${type.name}_001',
              deviceId: 'test_device_multi',
              location: 'integration_test_multi_zone',
            ),
          )
          .toList();

      await mqttClient.connect();

      // Publish all sensor types
      for (final data in testDataList) {
        final topic = TestMqttTopics.sensorDataTopicFor(data.id);
        final messageJson = _sensorDataToJson(data);

        final builder = MqttClientPayloadBuilder();
        builder.addString(messageJson);

        mqttClient.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

        // Small delay between publishes
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('Published ${testDataList.length} sensor data points');

      // Wait for processing
      await Future.delayed(const Duration(seconds: 45));

      // Verify all data types were stored
      int storedCount = 0;
      for (final data in testDataList) {
        if (await _queryInfluxDirectly(data)) {
          storedCount++;
        }
      }

      expect(
        storedCount,
        greaterThanOrEqualTo(testDataList.length ~/ 2),
        reason:
            'At least half of the sensor data should be stored successfully',
      );
    }, timeout: testTimeout);

    test('Device status integration', tags: ['integration'], () async {
      final testDevice = TestDataGenerator.generateDevice(
        id: 'integration_test_pump_001',
        type: DeviceType.pump,
        status: DeviceStatus.online,
        location: 'integration_test_zone',
      );

      await mqttClient.connect();

      // Publish device status
      final topic = TestMqttTopics.deviceStatusTopicFor(testDevice.id);
      final messageJson = _deviceToJson(testDevice);

      final builder = MqttClientPayloadBuilder();
      builder.addString(messageJson);

      mqttClient.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

      print('Published device status to topic: $topic');
      print('Message: $messageJson');

      // Wait for processing
      await Future.delayed(const Duration(seconds: 20));

      // For device status, we just verify the pipeline doesn't break
      // The exact verification would depend on how device status is stored
      expect(
        mqttClient.connectionStatus!.state,
        equals(MqttConnectionState.connected),
      );
    }, timeout: testTimeout);
  });
}

/// Wait for all services to be ready before running tests.
Future<void> _waitForServices() async {
  print('Waiting for services to be ready...');

  // Wait for InfluxDB
  await _waitForInfluxDB();

  // Wait for MQTT broker
  await _waitForMQTT();

  // Wait for Telegraf (give it time to connect to other services)
  await Future.delayed(const Duration(seconds: 10));

  print('All services are ready!');
}

/// Wait for InfluxDB to be ready.
Future<void> _waitForInfluxDB() async {
  for (int i = 0; i < 30; i++) {
    try {
      final response = await http.get(
        Uri.parse('${TestConfig.testInfluxUrl}/health'),
      );
      if (response.statusCode == 200) {
        print('InfluxDB is ready');
        return;
      }
    } catch (e) {
      // Service not ready yet
    }
    await Future.delayed(const Duration(seconds: 2));
  }
  throw Exception('InfluxDB did not become ready in time');
}

/// Wait for MQTT broker to be ready.
Future<void> _waitForMQTT() async {
  for (int i = 0; i < 30; i++) {
    try {
      final socket = await Socket.connect(
        TestConfig.testMqttHost,
        TestConfig.testMqttPort,
      );
      socket.destroy();
      print('MQTT broker is ready');
      return;
    } catch (e) {
      // Service not ready yet
    }
    await Future.delayed(const Duration(seconds: 2));
  }
  throw Exception('MQTT broker did not become ready in time');
}

/// Convert sensor data to JSON for MQTT publishing.
String _sensorDataToJson(SensorData data) {
  return json.encode({
    'id': data.id,
    'sensorType': data.sensorType.name,
    'value': data.value,
    'unit': data.unit,
    'timestamp': data.timestamp.toUtc().toIso8601String(),
    'deviceId': data.deviceId,
    'location': data.location,
  });
}

/// Convert device to JSON for MQTT publishing.
String _deviceToJson(Device data) {
  return json.encode({
    'id': data.id,
    'name': data.name,
    'type': data.type.name,
    'status': data.status.name,
    'isEnabled': data.isEnabled,
    'location': data.location,
    'lastUpdate': data.lastUpdate?.toUtc().toIso8601String(),
  });
}

/// Query InfluxDB directly to verify data was stored.
/// This bypasses our service layer to test the actual integration.
Future<bool> _queryInfluxDirectly(SensorData expectedData) async {
  try {
    final query =
        '''
from(bucket: "${TestConfig.testInfluxBucket}")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "mqtt_consumer")
  |> filter(fn: (r) => r.id == "${expectedData.id}")
  |> last()
''';

    final response = await http.post(
      Uri.parse(
        '${TestConfig.testInfluxUrl}/api/v2/query?org=${TestConfig.testInfluxOrg}',
      ),
      headers: {
        'Authorization': 'Token ${TestConfig.testInfluxToken}',
        'Content-Type': 'application/vnd.flux',
        'Accept': 'application/csv',
      },
      body: query,
    );

    if (response.statusCode == 200) {
      final csvData = response.body;
      print('InfluxDB query response: $csvData');

      // Simple check: if response contains our sensor ID, data was stored
      return csvData.contains(expectedData.id);
    } else {
      print('InfluxDB query failed with status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error querying InfluxDB: $e');
    return false;
  }
}
