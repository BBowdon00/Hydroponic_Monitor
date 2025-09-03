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
/// These tests require the services to be running via Docker Compose:
/// ```bash
/// cd test/integration
/// docker compose up -d
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
        final topic = TestMqttTopics.sensorDataTopicFor(
          'rpi',
          'temperature',
          '01',
        );
        final messageJson = _sensorDataToJson(testData);

        final builder = MqttClientPayloadBuilder();
        builder.addString(messageJson);

        mqttClient.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

        print('Published sensor data to topic: $topic');
        print('Message: $messageJson');

        // Wait for Telegraf to process and store in InfluxDB
        await Future.delayed(const Duration(seconds: 3));

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
      for (int i = 0; i < testDataList.length; i++) {
        final data = testDataList[i];
        final topic = TestMqttTopics.sensorDataTopicFor(
          'rpi',
          data.sensorType.name,
          '${(i + 1).toString().padLeft(2, '0')}',
        );
        final messageJson = _sensorDataToJson(data);

        final builder = MqttClientPayloadBuilder();
        builder.addString(messageJson);

        mqttClient.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

        // Small delay between publishes
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('Published ${testDataList.length} sensor data points');

      // Wait for processing
      await Future.delayed(const Duration(seconds: 3));

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

    test(
      'Device control commands via /set topics',
      tags: ['integration'],
      () async {
        final testDevice = TestDataGenerator.generateDevice(
          id: 'integration_test_pump_001',
          type: DeviceType.pump,
          status: DeviceStatus.online,
          location: 'integration_test_zone',
        );

        await mqttClient.connect();

        // Test multiple command types to different devices
        final commands = [
          {
            'topic': TestMqttTopics.deviceCommandTopicFor('rpi', 'pump', '01'),
            'command': {
              'command': 'turn_on',
              'deviceId': testDevice.id,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'level': 'high',
            },
          },
          {
            'topic': TestMqttTopics.deviceCommandTopicFor('rpi', 'light', '01'),
            'command': {
              'command': 'set_brightness',
              'deviceId': 'integration_test_light_001',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'brightness': 75,
            },
          },
          {
            'topic': TestMqttTopics.deviceCommandTopicFor('rpi', 'fan', '01'),
            'command': {
              'command': 'set_speed',
              'deviceId': 'integration_test_fan_001',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'speed': 'medium',
            },
          },
        ];

        // Publish all commands
        for (final cmd in commands) {
          final commandJson = json.encode(cmd['command']);
          final builder = MqttClientPayloadBuilder();
          builder.addString(commandJson);

          mqttClient.publishMessage(
            cmd['topic'] as String,
            MqttQos.atLeastOnce,
            builder.payload!,
          );

          print('Published command to topic: ${cmd['topic']}');
          print('Command: $commandJson');

          // Small delay between commands
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Wait for processing
        await Future.delayed(const Duration(seconds: 3));

        // Device commands don't go through Telegraf to InfluxDB - they go directly to devices
        // So we just verify MQTT connectivity remains stable after publishing multiple commands
        expect(
          mqttClient.connectionStatus!.state,
          equals(MqttConnectionState.connected),
        );
      },
      timeout: testTimeout,
    );

    test('Actuator state reporting', tags: ['integration'], () async {
      await mqttClient.connect();

      // Test actuator state messages for different device types
      final actuatorStates = [
        {
          'topic': TestMqttTopics.deviceStatusTopicFor('rpi', 'pump', '01'),
          'state': {
            'ts': DateTime.now().toUtc().toIso8601String(),
            'state': 1, // On
            'power_W': 45.5,
            'request_id': 'test_request_001',
          },
        },
        {
          'topic': TestMqttTopics.deviceStatusTopicFor('rpi', 'light', '01'),
          'state': {
            'ts': DateTime.now().toUtc().toIso8601String(),
            'state': 1, // On
            'level': 'bright',
            'power_W': 120.0,
          },
        },
        {
          'topic': TestMqttTopics.deviceStatusTopicFor('rpi', 'fan', '01'),
          'state': {
            'ts': DateTime.now().toUtc().toIso8601String(),
            'state': 0, // Off
            'level': 'stopped',
            'power_W': 0.0,
          },
        },
      ];

      // Publish all actuator states
      for (final state in actuatorStates) {
        final stateJson = json.encode(state['state']);
        final builder = MqttClientPayloadBuilder();
        builder.addString(stateJson);

        mqttClient.publishMessage(
          state['topic'] as String,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        print('Published actuator state to topic: ${state['topic']}');
        print('State: $stateJson');

        // Small delay between publishes
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Wait for Telegraf to process and store in InfluxDB
      await Future.delayed(const Duration(seconds: 3));

      // Verify at least some actuator state data was stored
      // This checks that the actuator input pipeline is working
      final stored = await _queryInfluxForActuatorStates();
      expect(
        stored,
        isTrue,
        reason: 'Actuator state data should be stored in InfluxDB via Telegraf',
      );
    }, timeout: testTimeout);

    test('Node status reporting', tags: ['integration'], () async {
      await mqttClient.connect();

      // Test node status messages
      final statusMessages = ['ONLINE', 'OFFLINE', 'ONLINE'];

      for (final status in statusMessages) {
        final topic = TestMqttTopics.nodeStatusTopicFor('rpi');
        final builder = MqttClientPayloadBuilder();
        builder.addString(status);

        mqttClient.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

        print('Published node status to topic: $topic');
        print('Status: $status');

        // Delay between status updates
        await Future.delayed(const Duration(seconds: 2));
      }

      // Wait for Telegraf to process
      await Future.delayed(const Duration(seconds: 3));

      // Verify node status data was stored
      final stored = await _queryInfluxForNodeStatus();
      expect(
        stored,
        isTrue,
        reason: 'Node status data should be stored in InfluxDB via Telegraf',
      );
    }, timeout: testTimeout);

    test(
      'Comprehensive sensor type coverage',
      tags: ['integration'],
      () async {
        await mqttClient.connect();

        // Test all available sensor types with realistic data
        final comprehensiveTestData = <SensorData>[];

        for (final sensorType in SensorType.values) {
          // Generate multiple readings per sensor type
          for (int i = 1; i <= 3; i++) {
            comprehensiveTestData.add(
              TestDataGenerator.generateSensorData(
                sensorType: sensorType,
                sensorId:
                    'comprehensive_${sensorType.name}_${i.toString().padLeft(2, '0')}',
                deviceId:
                    'comprehensive_device_${i.toString().padLeft(2, '0')}',
                location: 'comprehensive_test_zone',
              ),
            );
          }
        }

        print(
          'Publishing ${comprehensiveTestData.length} comprehensive sensor readings...',
        );

        // Publish all sensor data
        for (int i = 0; i < comprehensiveTestData.length; i++) {
          final data = comprehensiveTestData[i];
          final topic = TestMqttTopics.sensorDataTopicFor(
            'rpi',
            data.sensorType.name,
            (i + 1).toString().padLeft(2, '0'),
          );
          final messageJson = _sensorDataToJson(data);

          final builder = MqttClientPayloadBuilder();
          builder.addString(messageJson);

          mqttClient.publishMessage(
            topic,
            MqttQos.atLeastOnce,
            builder.payload!,
          );

          // Small delay between publishes to avoid overwhelming the system
          await Future.delayed(const Duration(milliseconds: 100));
        }

        print('All comprehensive sensor data published');

        // Wait for processing
        await Future.delayed(const Duration(seconds: 5));

        // Verify a significant portion of the data was stored
        int storedCount = 0;
        for (final data in comprehensiveTestData) {
          if (await _queryInfluxDirectly(data)) {
            storedCount++;
          }
          // Small delay between queries to avoid overwhelming InfluxDB
          await Future.delayed(const Duration(milliseconds: 100));
        }

        final successRate = storedCount / comprehensiveTestData.length;
        print(
          'Stored $storedCount/${comprehensiveTestData.length} sensor readings (${(successRate * 100).toStringAsFixed(1)}%)',
        );

        expect(
          successRate,
          greaterThanOrEqualTo(0.7), // At least 70% success rate
          reason:
              'At least 70% of comprehensive sensor data should be stored successfully',
        );
      },
      timeout: Timeout(
        Duration(minutes: 5),
      ), // Longer timeout for comprehensive test
    );
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
  // await Future.delayed(const Duration(seconds: 1));

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
    'ts': data.timestamp.toUtc().toIso8601String(),
    'value': data.value,
    'unit': data.unit,
    'id': data.id, // Include sensor ID for InfluxDB query matching
    'accuracy': 0.1, // Optional field for testing
  });
}

/// Query InfluxDB directly to verify data was stored.
/// This bypasses our service layer to test the actual integration.
Future<bool> _queryInfluxDirectly(SensorData expectedData) async {
  try {
    // Generate the expected topic for this sensor data
    final expectedTopic = TestMqttTopics.sensorDataTopicFor(
      'rpi',
      expectedData.sensorType.name,
      '01',
    );

    final query =
        '''
        from(bucket: "${TestConfig.testInfluxBucket}")
          |> range(start: -30m)
          |> filter(fn: (r) => r._measurement == "env")
          |> filter(fn: (r) => r._field == "value")
          |> filter(fn: (r) => r.topic == "$expectedTopic")
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
      print('InfluxDB sensor query response: $csvData');

      // Check if response contains the expected topic and value data
      return csvData.contains(expectedTopic) && csvData.contains('_value');
    } else {
      print('InfluxDB sensor query failed with status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error querying InfluxDB for sensor data: $e');
    return false;
  }
}

/// Query InfluxDB for actuator state data.
Future<bool> _queryInfluxForActuatorStates() async {
  try {
    final query =
        '''
        from(bucket: "${TestConfig.testInfluxBucket}")
          |> range(start: -1h)
          |> filter(fn: (r) => r._measurement == "actuator_state")
          |> filter(fn: (r) => r._field == "state")
          |> count()
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
      print('InfluxDB actuator query response: $csvData');

      // Check if we have any actuator state records
      return csvData.contains('_value') && !csvData.contains(',0,');
    } else {
      print(
        'InfluxDB actuator query failed with status: ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error querying InfluxDB for actuator states: $e');
    return false;
  }
}

/// Query InfluxDB for node status data.
Future<bool> _queryInfluxForNodeStatus() async {
  try {
    final query =
        '''
from(bucket: "${TestConfig.testInfluxBucket}")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "node_status")
  |> filter(fn: (r) => r._field == "online")
  |> count()
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
      print('InfluxDB node status query response: $csvData');

      // Check if we have any node status records
      return csvData.contains('_value') && !csvData.contains(',0,');
    } else {
      print(
        'InfluxDB node status query failed with status: ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error querying InfluxDB for node status: $e');
    return false;
  }
}
