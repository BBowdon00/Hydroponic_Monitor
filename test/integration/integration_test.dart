import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:hydroponic_monitor/domain/entities/sensor_data.dart';
import 'package:hydroponic_monitor/data/influx/influx_service.dart';
import 'package:hydroponic_monitor/core/logger.dart';
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
    MqttServerClient? mqttClient;
    InfluxDbService? influxService;

    setUpAll(() async {
      // Initialize logger for tests
      Logger.init(isTest: true);

      // Wait for services to be ready
      await _waitForServices();

      // Initialize MQTT client for publishing test data
      mqttClient = MqttServerClient(
        TestConfig.testMqttHost,
        'integration_test_publisher',
      );
      mqttClient!.port = TestConfig.testMqttPort;
      mqttClient!.keepAlivePeriod = 20;
      mqttClient!.autoReconnect = true;

      // Initialize InfluxDB service for querying data
      influxService = InfluxDbService(
        url: TestConfig.testInfluxUrl,
        token: TestConfig.testInfluxToken,
        organization: TestConfig.testInfluxOrg,
        bucket: TestConfig.testInfluxBucket,
      );

      await influxService!.initialize();
    });

    tearDownAll(() async {
      mqttClient?.disconnect();
      await influxService?.close();
    });

    test(
      'End-to-end data flow: MQTT publish → Telegraf → InfluxDB storage',
      tags: ['integration'],
      () async {
        // Generate test sensor data using new format
        final testData = TestDataGenerator.generateSensorData(
          sensorType: SensorType.temperature,
          sensorId: 'integration_test_temp_001',
          deviceId: 'test_device_001',
          location: 'integration_test_zone',
        );

        // Connect to MQTT broker
        await mqttClient!.connect();
        expect(
          mqttClient!.connectionStatus!.state,
          equals(MqttConnectionState.connected),
        );

        // Publish sensor data using new topic format
        final topic = TestMqttTopics.sensorTopicFor('rpi');
        final messageJson = _sensorDataToNewJson(testData);

        final builder = MqttClientPayloadBuilder();
        builder.addString(messageJson);

        mqttClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        Logger.info(
          'Published sensor data to topic: $topic',
          tag: 'Integration',
        );
        Logger.debug('Message: $messageJson', tag: 'Integration');

        // Wait for Telegraf to process and store in InfluxDB
        await Future.delayed(const Duration(seconds: 3));

        // Query InfluxDB to verify data was stored with new measurement names
        final stored = await _queryInfluxForNewFormat(testData);

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

      await mqttClient!.connect();

      // Publish all sensor types using new format
      for (final data in testDataList) {
        final topic = TestMqttTopics.sensorTopicFor('rpi');
        final messageJson = _sensorDataToNewJson(data);

        final builder = MqttClientPayloadBuilder();
        builder.addString(messageJson);

        mqttClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        // Small delay between publishes
        await Future.delayed(const Duration(milliseconds: 100));
      }

      Logger.info(
        'Published ${testDataList.length} sensor data points',
        tag: 'Integration',
      );

      // Wait for processing
      await Future.delayed(const Duration(seconds: 3));

      // Verify all data types were stored
      int storedCount = 0;
      for (final data in testDataList) {
        if (await _queryInfluxForNewFormat(data)) {
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

    test('Actuator state reporting', tags: ['integration'], () async {
      await mqttClient!.connect();

      // Test actuator state messages using new format
      final actuatorPayloads = [
        TestMqttPayloads.actuatorPayload(
          deviceType: 'pump',
          deviceID: '1',
          location: 'tent',
          running: true,
          description: 'main circulation pump',
        ),
        TestMqttPayloads.actuatorPayload(
          deviceType: 'light',
          deviceID: '2',
          location: 'tent',
          running: true,
          description: 'led grow light',
        ),
        TestMqttPayloads.actuatorPayload(
          deviceType: 'fan',
          deviceID: '3',
          location: 'tent',
          running: false,
          description: 'circulation fan',
        ),
      ];

      // Publish all actuator states using new topic format
      for (final payload in actuatorPayloads) {
        final topic = TestMqttTopics.actuatorTopicFor('rpi');
        final payloadJson = json.encode(payload);
        final builder = MqttClientPayloadBuilder();
        builder.addString(payloadJson);

        mqttClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        Logger.info(
          'Published actuator state to topic: $topic',
          tag: 'Integration',
        );
        Logger.debug('Payload: $payloadJson', tag: 'Integration');

        // Small delay between publishes
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Wait for Telegraf to process and store in InfluxDB
      await Future.delayed(const Duration(seconds: 2));

      // Verify actuator state data was stored using new measurement name
      final stored = await _queryInfluxForActuatorStatesNew(
        actuatorPayloads.length,
      );
      expect(
        stored,
        isTrue,
        reason: 'Actuator state data should be stored in InfluxDB via Telegraf',
      );
    }, timeout: testTimeout);

    test('Device status reporting', tags: ['integration'], () async {
      await mqttClient!.connect();

      // Test device status messages using new format
      final devicePayloads = [
        TestMqttPayloads.devicePayload(
          deviceType: 'microcontroller',
          deviceID: '1',
          location: 'tent',
          running: true,
          description: 'esp32 board operational',
        ),
        TestMqttPayloads.devicePayload(
          deviceType: 'microcontroller',
          deviceID: '2',
          location: 'tent',
          running: false,
          description: 'backup controller offline',
        ),
      ];

      // Publish device status using new topic format
      for (final payload in devicePayloads) {
        final topic = TestMqttTopics.deviceTopicFor('esp32_1');
        final payloadJson = json.encode(payload);
        final builder = MqttClientPayloadBuilder();
        builder.addString(payloadJson);

        mqttClient!.publishMessage(
          topic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        Logger.info(
          'Published device status to topic: $topic',
          tag: 'Integration',
        );
        Logger.debug('Payload: $payloadJson', tag: 'Integration');

        // Small delay between publishes
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Wait for Telegraf to process and store in InfluxDB; poll to tolerate timing
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      bool deviceStored = false;
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(seconds: 1));
        if (await _queryInfluxForDeviceStatesNew(devicePayloads.length)) {
          deviceStored = true;
          break;
        }
      }

      expect(
        deviceStored,
        isTrue,
        reason: 'Device status data should be stored in InfluxDB via Telegraf',
      );
    }, timeout: testTimeout);

    test(
      'Comprehensive sensor type coverage',
      tags: ['integration'],
      () async {
        await mqttClient!.connect();

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

        Logger.info(
          'Publishing ${comprehensiveTestData.length} comprehensive sensor readings...',
          tag: 'Integration',
        );

        // Publish all sensor data using the correct topic format
        for (final data in comprehensiveTestData) {
          final topic = TestMqttTopics.sensorTopicFor('rpi');
          final messageJson = _sensorDataToNewJson(data);

          final builder = MqttClientPayloadBuilder();
          builder.addString(messageJson);

          mqttClient!.publishMessage(
            topic,
            MqttQos.atLeastOnce,
            builder.payload!,
          );

          // Small delay between publishes to avoid overwhelming the system
          await Future.delayed(const Duration(milliseconds: 100));
        }

        Logger.info(
          'All comprehensive sensor data published',
          tag: 'Integration',
        );

        // Wait for processing
        await Future.delayed(const Duration(seconds: 3));

        // Verify a significant portion of the data was stored
        int storedCount = 0;
        for (final data in comprehensiveTestData) {
          if (await _queryInfluxForNewFormat(data)) {
            storedCount++;
          }
          // Small delay between queries to avoid overwhelming InfluxDB
          await Future.delayed(const Duration(milliseconds: 100));
        }

        final successRate = storedCount / comprehensiveTestData.length;
        Logger.info(
          'Stored $storedCount/${comprehensiveTestData.length} sensor readings (${(successRate * 100).toStringAsFixed(1)}%)',
          tag: 'Integration',
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
  Logger.info('Waiting for services to be ready...', tag: 'Integration');

  try {
    // Wait for InfluxDB
    await _waitForInfluxDB();

    // Wait for MQTT broker
    await _waitForMQTT();

    // Wait for Telegraf (give it time to connect to other services)
    await Future.delayed(const Duration(seconds: 2));

    Logger.info('All services are ready!', tag: 'Integration');
  } catch (e) {
    // If services aren't available, we'll skip the tests
    throw Exception(
      'Integration test services not available: $e. Please run "./scripts/run-integration-tests.sh" to start services.',
    );
  }
}

/// Wait for InfluxDB to be ready.
Future<void> _waitForInfluxDB() async {
  Logger.info('Waiting for InfluxDB to become ready...', tag: 'Integration');
  for (int i = 0; i < 10; i++) {
    // Reduced from 60 to 10 attempts for faster failure
    try {
      final response = await http.get(
        Uri.parse('${TestConfig.testInfluxUrl}/health'),
      );
      if (response.statusCode == 200) {
        Logger.info('InfluxDB is ready', tag: 'Integration');
        return;
      }
      Logger.debug(
        'InfluxDB attempt ${i + 1}: status ${response.statusCode}',
        tag: 'Integration',
      );
    } catch (e) {
      Logger.debug('InfluxDB attempt ${i + 1}: $e', tag: 'Integration');
    }
    await Future.delayed(const Duration(seconds: 1)); // Reduced from 2s to 1s
  }
  throw Exception(
    'InfluxDB did not become ready in time (tried for ${10 * 1} seconds)',
  );
}

/// Wait for MQTT broker to be ready.
Future<void> _waitForMQTT() async {
  Logger.info('Waiting for MQTT broker to become ready...', tag: 'Integration');
  for (int i = 0; i < 10; i++) {
    // Reduced from 60 to 10 attempts for faster failure
    try {
      final socket = await Socket.connect(
        TestConfig.testMqttHost,
        TestConfig.testMqttPort,
      );
      socket.destroy();
      Logger.info('MQTT broker is ready', tag: 'Integration');
      return;
    } catch (e) {
      Logger.debug('MQTT attempt ${i + 1}: $e', tag: 'Integration');
    }
    await Future.delayed(const Duration(seconds: 1)); // Reduced from 2s to 1s
  }
  throw Exception(
    'MQTT broker did not become ready in time (tried for ${10 * 1} seconds)',
  );
}

/// Convert sensor data to new JSON format for MQTT publishing.
String _sensorDataToNewJson(SensorData data) {
  return json.encode(
    TestMqttPayloads.sensorPayload(
      deviceType: data.sensorType.name,
      deviceID: '1',
      location: data.location ?? 'tent',
      value: data.value,
      description: 'integration test ${data.sensorType.name} sensor',
    ),
  );
}

/// Query InfluxDB for data with new format and measurement names.
Future<bool> _queryInfluxForNewFormat(SensorData expectedData) async {
  try {
    // Query based on new measurement name "sensor" from telegraf config
    final query =
        '''
        from(bucket: "${TestConfig.testInfluxBucket}")
          |> range(start: -30m)
          |> filter(fn: (r) => r._measurement == "sensor")
          |> filter(fn: (r) => r._field == "value")
          |> filter(fn: (r) => r.deviceType == "${expectedData.sensorType.name}")
          |> filter(fn: (r) => r.project == "grow")
          |> filter(fn: (r) => r.deviceNode == "rpi")
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
      Logger.debug(
        'InfluxDB new format sensor query response: \n$csvData',
        tag: 'Integration',
      );

      // Check if response contains data with expected measurement and tags
      return csvData.contains('_value') &&
          csvData.contains('sensor') && // measurement name
          csvData.contains(expectedData.sensorType.name) && // deviceType tag
          csvData.contains('rpi') && // deviceNode tag
          csvData.contains('grow'); // project tag
    } else {
      Logger.warning(
        'InfluxDB new format sensor query failed with status: ${response.statusCode}',
        tag: 'Integration',
      );
      Logger.debug('Response body: ${response.body}', tag: 'Integration');
      return false;
    }
  } catch (e) {
    Logger.error(
      'Error querying InfluxDB for new format sensor data: $e',
      tag: 'Integration',
      error: e,
    );
    return false;
  }
}

/// Query InfluxDB for actuator state data with new measurement name.
Future<bool> _queryInfluxForActuatorStatesNew(int expectedResultNum) async {
  try {
    final query =
        '''
        from(bucket: "${TestConfig.testInfluxBucket}")
          |> range(start: -1m)
          |> filter(fn: (r) => r._measurement == "actuator")
          |> filter(fn: (r) => r._field == "running")
          |> filter(fn: (r) => r.project == "grow")
          |> group()        // removes tag grouping
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
      Logger.debug(
        'InfluxDB new format actuator query response: \n$csvData',
        tag: 'Integration',
      );

      // Check if we have any device state records
      // query response will return csv like: ,result,table,_start,_stop,_value\n,_result,0,2024-10-05T12:00:00Z,2024-10-05T12:01:00Z,returnCount
      // check to see if count is equal to records published
      // parse out the returnCount value from the table
      final returnCount =
          int.tryParse(csvData.split('\n')[1].split(',')[5]) ?? 0;
      Logger.debug("Return Count: $returnCount", tag: 'Integration');
      // Accept >= expected to be tolerant of duplicate/retained messages
      return csvData.contains('_value') && returnCount >= expectedResultNum;
    } else {
      Logger.warning(
        'InfluxDB new format actuator query failed with status: ${response.statusCode}',
        tag: 'Integration',
      );
      return false;
    }
  } catch (e) {
    Logger.error(
      'Error querying InfluxDB for new format actuator states: $e',
      tag: 'Integration',
      error: e,
    );
    return false;
  }
}

/// Query InfluxDB for device state data with new measurement name.
Future<bool> _queryInfluxForDeviceStatesNew(int expectedResultNum) async {
  try {
    final query =
        '''
        from(bucket: "${TestConfig.testInfluxBucket}")
          |> range(start: -1m)
          |> filter(fn: (r) => r._measurement == "device")
          |> filter(fn: (r) => r._field == "running")
          |> filter(fn: (r) => r.project == "grow")
          |> group()        // removes tag grouping
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
      Logger.debug(
        'InfluxDB device status query response: \n$csvData',
        tag: 'Integration',
      );

      // Check if we have any device state records
      // query response will return csv like: ,result,table,_start,_stop,_value\n,_result,0,2024-10-05T12:00:00Z,2024-10-05T12:01:00Z,returnCount
      // check to see if count is equal to records published
      // parse out the returnCount value from the table
      final returnCount =
          int.tryParse(csvData.split('\n')[1].split(',')[5]) ?? 0;
      Logger.debug("Return Count: $returnCount", tag: 'Integration');
      // Accept >= expected to be tolerant of duplicate/retained messages
      return csvData.contains('_value') && returnCount >= expectedResultNum;
    } else {
      Logger.warning(
        'InfluxDB device state query failed with status: ${response.statusCode}',
        tag: 'Integration',
      );
      return false;
    }
  } catch (e) {
    Logger.error(
      'Error querying InfluxDB for device states: $e',
      tag: 'Integration',
      error: e,
    );
    return false;
  }
}
