import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device.dart';

/// MQTT client for communicating with hydroponic system devices.
class MqttService {
  MqttService({
    required this.host,
    required this.port,
    required this.clientId,
    this.username,
    this.password,
  });

  final String host;
  final int port;
  final String clientId;
  final String? username;
  final String? password;

  MqttServerClient? _client;
  final StreamController<SensorData> _sensorDataController = StreamController<SensorData>.broadcast();
  final StreamController<Device> _deviceStatusController = StreamController<Device>.broadcast();
  final StreamController<String> _connectionController = StreamController<String>.broadcast();

  /// Stream of sensor data received via MQTT.
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  /// Stream of device status updates received via MQTT.
  Stream<Device> get deviceStatusStream => _deviceStatusController.stream;

  /// Stream of connection status changes.
  Stream<String> get connectionStream => _connectionController.stream;

  /// Current connection status.
  Object? get connectionStatus => _client?.connectionStatus;

  /// Initialize and connect to MQTT broker.
  Future<Result<void>> connect() async {
    try {
      Logger.info('Connecting to MQTT broker at $host:$port', tag: 'MQTT');
      
      _client = MqttServerClient.withPort(host, clientId, port);
      _client!.logging(on: true);
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 30000;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onUnsubscribed = _onUnsubscribed;

      // Set up message handling
      _client!.updates!.listen(_onMessageReceived);

      // Set credentials if provided
      if (username != null && password != null) {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .authenticateAs(username!, password!)
            .withWillTopic('hydroponic/status/$clientId')
            .withWillMessage('offline')
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
      } else {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .withWillTopic('hydroponic/status/$clientId')
            .withWillMessage('offline')
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
      }

      final status = await _client!.connect();
      
      if (status?.toString() == 'connected') {
        Logger.info('Successfully connected to MQTT broker', tag: 'MQTT');
        await _subscribeToTopics();
        return const Success(null);
      } else {
        final error = 'Failed to connect to MQTT broker: ${status?.toString()}';
        Logger.error(error, tag: 'MQTT');
        return Failure(MqttError(error));
      }
    } catch (e) {
      final error = 'Error connecting to MQTT broker: $e';
      Logger.error(error, tag: 'MQTT', error: e);
      return Failure(MqttError(error));
    }
  }

  /// Disconnect from MQTT broker.
  Future<void> disconnect() async {
    try {
      Logger.info('Disconnecting from MQTT broker', tag: 'MQTT');
      _client?.disconnect();
      await _sensorDataController.close();
      await _deviceStatusController.close();
      await _connectionController.close();
    } catch (e) {
      Logger.error('Error disconnecting from MQTT broker: $e', tag: 'MQTT', error: e);
    }
  }

  /// Publish device control command.
  Future<Result<void>> publishDeviceCommand(String deviceId, String command, {Map<String, dynamic>? parameters}) async {
    try {
      if (_client?.connectionStatus?.toString() != 'connected') {
        return const Failure(MqttError('Not connected to MQTT broker'));
      }

      final topic = 'hydroponic/devices/$deviceId/command';
      final payload = {
        'command': command,
        'timestamp': DateTime.now().toIso8601String(),
        'client_id': clientId,
        if (parameters != null) 'parameters': parameters,
      };

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      Logger.info('Published command to device $deviceId: $command', tag: 'MQTT');
      
      return const Success(null);
    } catch (e) {
      final error = 'Error publishing device command: $e';
      Logger.error(error, tag: 'MQTT', error: e);
      return Failure(MqttError(error));
    }
  }

  /// Subscribe to relevant MQTT topics.
  Future<void> _subscribeToTopics() async {
    if (_client?.connectionStatus?.toString() != 'connected') return;

    final topics = [
      'hydroponic/sensors/+/data',
      'hydroponic/devices/+/status',
      'hydroponic/system/status',
    ];

    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      Logger.info('Subscribed to topic: $topic', tag: 'MQTT');
    }
  }

  /// Handle incoming MQTT messages.
  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );
      final topic = message.topic;

      Logger.debug('Received message on topic $topic: $payload', tag: 'MQTT');

      try {
        if (topic.startsWith('hydroponic/sensors/')) {
          _handleSensorData(topic, payload);
        } else if (topic.startsWith('hydroponic/devices/')) {
          _handleDeviceStatus(topic, payload);
        }
      } catch (e) {
        Logger.error('Error processing MQTT message: $e', tag: 'MQTT', error: e);
      }
    }
  }

  /// Handle sensor data messages.
  void _handleSensorData(String topic, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final sensorId = topic.split('/')[2]; // Extract sensor ID from topic
      
      // Generate dummy data for now since we're still using mock data
      final sensorData = _generateDummySensorData(sensorId, data);
      _sensorDataController.add(sensorData);
    } catch (e) {
      Logger.error('Error parsing sensor data: $e', tag: 'MQTT', error: e);
    }
  }

  /// Handle device status messages.
  void _handleDeviceStatus(String topic, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final deviceId = topic.split('/')[2]; // Extract device ID from topic
      
      // Generate dummy device data for now
      final device = _generateDummyDevice(deviceId, data);
      _deviceStatusController.add(device);
    } catch (e) {
      Logger.error('Error parsing device status: $e', tag: 'MQTT', error: e);
    }
  }

  /// Generate dummy sensor data for testing.
  SensorData _generateDummySensorData(String sensorId, Map<String, dynamic> mqttData) {
    final random = Random();
    final sensorTypes = SensorType.values;
    final sensorType = sensorTypes[random.nextInt(sensorTypes.length)];
    
    double value;
    switch (sensorType) {
      case SensorType.temperature:
        value = 20.0 + random.nextDouble() * 10; // 20-30°C
        break;
      case SensorType.humidity:
        value = 50.0 + random.nextDouble() * 30; // 50-80%
        break;
      case SensorType.pH:
        value = 5.5 + random.nextDouble() * 2; // 5.5-7.5 pH
        break;
      case SensorType.waterLevel:
        value = 10.0 + random.nextDouble() * 20; // 10-30 cm
        break;
      default:
        value = random.nextDouble() * 100;
    }

    return SensorData(
      id: sensorId,
      sensorType: sensorType,
      value: value,
      unit: sensorType.defaultUnit,
      timestamp: DateTime.now(),
      deviceId: mqttData['device_id'] as String?,
      location: mqttData['location'] as String?,
    );
  }

  /// Generate dummy device data for testing.
  Device _generateDummyDevice(String deviceId, Map<String, dynamic> mqttData) {
    final random = Random();
    final deviceTypes = DeviceType.values;
    final deviceType = deviceTypes[random.nextInt(deviceTypes.length)];
    final statuses = DeviceStatus.values;
    final status = statuses[random.nextInt(statuses.length)];

    return Device(
      id: deviceId,
      name: mqttData['name'] as String? ?? '${deviceType.displayName} $deviceId',
      type: deviceType,
      status: status,
      isEnabled: mqttData['enabled'] as bool? ?? random.nextBool(),
      description: mqttData['description'] as String?,
      location: mqttData['location'] as String?,
      lastUpdate: DateTime.now(),
    );
  }

  void _onConnected() {
    Logger.info('MQTT client connected', tag: 'MQTT');
    _connectionController.add('connected');
  }

  void _onDisconnected() {
    Logger.warning('MQTT client disconnected', tag: 'MQTT');
    _connectionController.add('disconnected');
  }

  void _onSubscribed(String topic) {
    Logger.info('Subscribed to topic: $topic', tag: 'MQTT');
  }

  void _onUnsubscribed(String? topic) {
    Logger.info('Unsubscribed from topic: $topic', tag: 'MQTT');
  }
}